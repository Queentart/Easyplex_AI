from typing import Annotated, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_roles
from app.models.auth import User
from app.schemas.leave import LeaveRequestCreate, ReviewRequest
from app.schemas.common import ok, paginated
from app.services import leave as leave_service

router = APIRouter(prefix="/leave-requests", tags=["leave-requests"])


@router.get("/", response_model=dict)
async def list_requests(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    status: Optional[str] = None,
    type: Optional[str] = None,
    cohort_id: Optional[int] = None,
    page: int = 1,
    size: int = 20,
):
    requests, total = await leave_service.list_requests(
        db, current_user, status=status, type_filter=type, cohort_id=cohort_id,
        page=page, size=size,
    )
    return paginated([r.model_dump() for r in requests], page, size, total)


@router.post("/", response_model=dict)
async def create_request(
    body: LeaveRequestCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await leave_service.create_request(db, body, current_user)
    return ok(result.model_dump())


# NOTE: must be declared BEFORE "/{request_id}" so "balance" is not captured
# as a request_id path param (which would 422/404).
@router.get("/balance", response_model=dict)
async def get_leave_balance(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await leave_service.get_student_leave_balance(db, current_user)
    return ok(result.model_dump())


@router.get("/{request_id}", response_model=dict)
async def get_request(
    request_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await leave_service.get_request(db, request_id, current_user)
    return ok(result.model_dump())


@router.post("/{request_id}/approve", response_model=dict)
async def approve_request(
    request_id: int,
    body: ReviewRequest,
    current_user: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await leave_service.approve(db, request_id, body, current_user)
    return ok(result.model_dump())


@router.post("/{request_id}/reject", response_model=dict)
async def reject_request(
    request_id: int,
    body: ReviewRequest,
    current_user: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await leave_service.reject(db, request_id, body, current_user)
    return ok(result.model_dump())


@router.delete("/{request_id}", response_model=dict)
async def cancel_request(
    request_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await leave_service.cancel(db, request_id, current_user)
    return ok({"ok": True})
