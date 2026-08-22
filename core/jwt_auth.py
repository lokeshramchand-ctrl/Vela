import logging
import secrets
from datetime import UTC, datetime, timedelta

import jwt
from fastapi import HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from core.config import settings
from models.schemas import User
from repositories.user_repository import user_repo

logger = logging.getLogger(__name__)

# auto_error=False mirrors core/security.py::api_key_header - lets this
# function distinguish "no token at all" from "token present but invalid"
# with its own specific detail message instead of a generic framework 403.
bearer_scheme = HTTPBearer(
    scheme_name="JWT",
    description="Access token obtained from POST /auth/login or POST /auth/refresh.",
    auto_error=False,
)

ACCESS_TOKEN_TYPE = "access"  # noqa: S105 - a JWT "type" claim value, not a credential


def create_access_token(user_id: str) -> tuple[str, int]:
    """Returns (token, expires_in_seconds)."""
    now = datetime.now(UTC)
    lifetime = timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": user_id,
        "type": ACCESS_TOKEN_TYPE,
        "iat": now,
        "exp": now + lifetime,
        "jti": secrets.token_hex(16),
    }
    token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return token, int(lifetime.total_seconds())


def generate_refresh_token() -> tuple[str, datetime]:
    """Opaque, high-entropy token - deliberately NOT a JWT. A self-contained
    JWT refresh token can't be individually revoked before its own expiry
    without maintaining a separate blocklist anyway, so there's no benefit
    over an opaque token that's already stored (hashed) server-side for
    lookup - see repositories/refresh_token_repository.py. Returns
    (raw_token, expires_at); only the raw token is ever returned to the
    client, never persisted in plaintext."""
    raw_token = secrets.token_urlsafe(48)
    expires_at = datetime.now(UTC) + timedelta(days=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS)
    return raw_token, expires_at


def decode_access_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
    except jwt.ExpiredSignatureError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Access token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        ) from e
    except jwt.InvalidTokenError as e:
        # Covers bad signature, malformed token, wrong algorithm, etc. - PyJWT
        # collapses these into subclasses of InvalidTokenError; the client
        # doesn't need to know which one, and detailing it would be a minor
        # oracle for token-forgery attempts.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from e

    if payload.get("type") != ACCESS_TOKEN_TYPE:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return payload


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Security(bearer_scheme),
) -> User:
    """The JWT half of this app's two-layer auth (see core/security.py for
    the API-key half). Bind this via `Depends(get_current_user)` on a
    handler parameter - not `dependencies=[...]` - wherever the resolved
    identity is actually needed, e.g. to scope a query by user id."""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_access_token(credentials.credentials)
    user_id = payload.get("sub")
    user = await user_repo.get_by_id(user_id) if user_id else None

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        # 403, not 401: the token itself is genuine and correctly identifies
        # a real user (authentication succeeded) - the account is just
        # disabled (an authorization decision), matching this codebase's
        # 401-vs-403 convention in core/security.py.
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is disabled")

    return user
