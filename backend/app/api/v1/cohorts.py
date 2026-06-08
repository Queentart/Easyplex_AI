from typing import Annotated, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_roles
from app.models.auth import User
from app.schemas.cohort import CohortCreate, CohortUpdate, MembersAddRequest
from app.schemas.common import ok, paginated
from app.services import cohort as cohort_service

router = APIRouter(prefix="/cohorts", tags=["cohorts"])


@router.get("/", response_model=dict)
async def list_cohorts(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    status: Optional[str] = None,
    page: int = 1,
    size: int = 20,
):
    cohorts, total = await cohort_service.list_cohorts(
        db, current_user, status=status, page=page, size=size
    )
    return paginated([c.model_dump() for c in cohorts], page, size, total)


@router.post("/", response_model=dict)
async def create_cohort(
    body: CohortCreate,
    current_user: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    cohort = await cohort_service.create_cohort(db, body, current_user)
    return ok(cohort.model_dump())


@router.get("/{cohort_id}", response_model=dict)
async def get_cohort(
    cohort_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    cohort = await cohort_service.get_cohort(db, cohort_id, current_user)
    return ok(cohort.model_dump())


@router.patch("/{cohort_id}", response_model=dict)
async def update_cohort(
    cohort_id: int,
    body: CohortUpdate,
    _: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    cohort = await cohort_service.update_cohort(db, cohort_id, body)
    return ok(cohort.model_dump())


@router.delete("/{cohort_id}", response_model=dict)
async def archive_cohort(
    cohort_id: int,
    _: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await cohort_service.archive_cohort(db, cohort_id)
    return ok({"ok": True})


@router.get("/{cohort_id}/members", response_model=dict)
async def list_members(
    cohort_id: int,
    _: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    role: Optional[str] = None,
):
    members = await cohort_service.get_cohort_members(db, cohort_id, role=role)
    return ok([m.model_dump() for m in members])


@router.post("/{cohort_id}/members", response_model=dict)
async def add_members(
    cohort_id: int,
    body: MembersAddRequest,
    current_user: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await cohort_service.add_members(
        db, cohort_id, body.user_ids, body.role, current_user
    )
    return ok(result.model_dump())


@router.delete("/{cohort_id}/members/{user_id}", response_model=dict)
async def remove_member(
    cohort_id: int,
    user_id: int,
    _: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await cohort_service.remove_member(db, cohort_id, user_id)
    return ok({"ok": True})
