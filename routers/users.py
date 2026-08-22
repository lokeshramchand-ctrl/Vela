from fastapi import APIRouter, Depends

from core.jwt_auth import get_current_user
from models.schemas import UpdateUserRequest, User, UserPublic
from repositories.user_repository import user_repo

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserPublic)
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user.to_public()


@router.patch("/me", response_model=UserPublic)
async def update_me(payload: UpdateUserRequest, current_user: User = Depends(get_current_user)):
    """Email is intentionally not editable here - see models.schemas.UpdateUserRequest."""
    if payload.full_name is not None:
        updated = await user_repo.update_full_name(current_user.id, payload.full_name)
        if updated is not None:
            return updated.to_public()
    return current_user.to_public()
