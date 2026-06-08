from typing import Annotated, Optional

from fastapi import APIRouter, Depends, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_roles
from app.models.auth import User
from app.schemas.common import ok, paginated
from app.schemas.user import UserCreate, UserRoleUpdate, UserUpdate
from app.services import user as user_service

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/", response_model=dict)
async def list_users(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    role: Optional[str] = None,
    cohort_id: Optional[int] = None,
    search: Optional[str] = None,
    page: int = 1,
    size: int = 20,
):
    users, total = await user_service.list_users(
        db, current_user, role=role, cohort_id=cohort_id, search=search, page=page, size=size
    )
    return paginated([u.model_dump() for u in users], page, size, total)


@router.post("/", response_model=dict)
async def create_user(
    body: UserCreate,
    current_user: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    user = await user_service.create_user(db, body, current_user)
    return ok(user.model_dump())


@router.post("/bulk-import", response_model=dict)
async def bulk_import(
    file: UploadFile,
    current_user: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    content = await file.read()
    result = await user_service.bulk_import(db, content.decode("utf-8"), current_user)
    return ok(result.model_dump())


@router.get("/{user_id}", response_model=dict)
async def get_user(
    user_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    user = await user_service.get_user(db, user_id, current_user)
    return ok(user.model_dump())


@router.patch("/{user_id}", response_model=dict)
async def update_user(
    user_id: int,
    body: UserUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    user = await user_service.update_user(db, user_id, body, current_user)
    return ok(user.model_dump())


@router.patch("/{user_id}/role", response_model=dict)
async def update_role(
    user_id: int,
    body: UserRoleUpdate,
    _: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    user = await user_service.update_user_role(db, user_id, body)
    return ok(user.model_dump())


@router.delete("/{user_id}", response_model=dict)
async def deactivate_user(
    user_id: int,
    _: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await user_service.deactivate_user(db, user_id)
    return ok(result)


@router.post("/{user_id}/password-reset", response_model=dict)
async def reset_password(
    user_id: int,
    _: Annotated[User, Depends(require_roles("admin_ops", "tech_support"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await user_service.reset_password(db, user_id)
    return ok(result.model_dump())
