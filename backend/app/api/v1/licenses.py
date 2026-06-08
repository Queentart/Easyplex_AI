from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_roles
from app.models.auth import User
from app.schemas.inquiry import LicenseCreate
from app.schemas.common import ok, paginated
from app.services import inquiry as inquiry_service

router = APIRouter(prefix="/licenses", tags=["licenses"])


@router.get("/", response_model=dict)
async def list_licenses(
    current_user: Annotated[User, Depends(require_roles("admin_ops", "tech_support"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    page: int = 1,
    size: int = 20,
):
    licenses, total = await inquiry_service.list_licenses(db, current_user, page, size)
    return paginated([l.model_dump() for l in licenses], page, size, total)


@router.post("/", response_model=dict)
async def create_license(
    body: LicenseCreate,
    current_user: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    license_ = await inquiry_service.create_license(db, body, current_user)
    return ok(license_.model_dump())


@router.get("/{license_id}/key", response_model=dict)
async def get_license_key(
    license_id: int,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "tech_support"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    license_ = await inquiry_service.get_license_with_key(db, license_id, current_user)
    return ok(license_.model_dump())
