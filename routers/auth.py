import hashlib
import logging
from datetime import UTC, datetime

from fastapi import APIRouter, HTTPException, Request, status
from pymongo.errors import DuplicateKeyError

from core.jwt_auth import create_access_token, generate_refresh_token
from core.rate_limiter import limiter
from core.security import hash_password, verify_password
from models.schemas import LoginRequest, LogoutRequest, RefreshRequest, RegisterRequest, TokenResponse, UserPublic
from repositories.refresh_token_repository import refresh_token_repo
from repositories.user_repository import user_repo

logger = logging.getLogger(__name__)

# Purely about token lifecycle (register/login/refresh/logout) - "who is the
# currently authenticated user" lives at GET/PATCH /users/me
# (routers/users.py) instead, a more RESTful home for profile access than an
# auth/token router.
router = APIRouter(prefix="/auth", tags=["Authentication"])


def _hash_refresh_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode()).hexdigest()


async def _issue_token_pair(user_id: str) -> TokenResponse:
    access_token, expires_in = create_access_token(user_id)
    refresh_token, refresh_expires_at = generate_refresh_token()
    await refresh_token_repo.store(
        user_id=user_id,
        token_hash=_hash_refresh_token(refresh_token),
        expires_at=refresh_expires_at,
    )
    return TokenResponse(access_token=access_token, refresh_token=refresh_token, expires_in=expires_in)


@router.post("/register", response_model=UserPublic, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def register(request: Request, payload: RegisterRequest):
    """Creates a new user account. Gated behind the same X-Vela-API-Key
    dependency as every other router (app.py) - the API key authenticates the
    calling application; a JWT for the new user doesn't exist yet at this
    point, since the account doesn't exist yet either."""
    existing = await user_repo.get_by_email(payload.email)
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email is already registered")

    hashed = hash_password(payload.password)
    try:
        user = await user_repo.create_user(email=payload.email, hashed_password=hashed)
    except DuplicateKeyError as e:
        # The pre-check above is the fast common-case path; the unique index
        # on users.email is what actually closes the race between two
        # concurrent registrations for the same address.
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email is already registered") from e

    logger.info("New user account registered.")
    return user.to_public()


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(request: Request, payload: LoginRequest):
    user = await user_repo.get_by_email(payload.email)

    # Verify against a real hash even when no user was found, so response
    # timing doesn't reveal whether the email is registered (a hasher call
    # takes measurably longer than skipping straight to the 401).
    password_ok = verify_password(payload.password, user.hashed_password if user else hash_password(""))

    if user is None or not password_ok:
        logger.warning("Rejected login attempt with invalid credentials.")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is disabled")

    return await _issue_token_pair(user.id)


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit("20/minute")
async def refresh(request: Request, payload: RefreshRequest):
    token_hash = _hash_refresh_token(payload.refresh_token)
    stored = await refresh_token_repo.get_by_hash(token_hash)

    if stored is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    if stored.get("revoked_at") is not None:
        # Reuse of an already-rotated (or already-logged-out) refresh token
        # is a strong signal of token theft - burn every session this user
        # currently has, not just the one being replayed.
        logger.warning("Rejected reused/revoked refresh token; revoking all sessions for the associated user.")
        await refresh_token_repo.revoke_all_for_user(stored["user_id"])
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    expires_at = stored["expires_at"]
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)
    if expires_at < datetime.now(UTC):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token has expired")

    user = await user_repo.get_by_id(stored["user_id"])
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    # Rotation: the presented token is single-use. Revoke it before issuing
    # its replacement so it can never be redeemed a second time.
    await refresh_token_repo.revoke(token_hash)
    return await _issue_token_pair(user.id)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("20/minute")
async def logout(request: Request, payload: LogoutRequest):
    """Revokes the presented refresh token, ending that session. Idempotent
    (revoking an unknown or already-revoked token is a silent no-op) and
    deliberately doesn't require a still-valid access token - a client whose
    access token already expired must still be able to log out."""
    await refresh_token_repo.revoke(_hash_refresh_token(payload.refresh_token))
