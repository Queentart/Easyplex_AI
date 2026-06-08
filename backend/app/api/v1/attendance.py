from datetime import date
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_roles
from app.models.auth import User
from app.schemas.attendance import AttendanceUpdate, NotifyRequest
from app.schemas.common import ok, paginated
from app.services import attendance as attendance_service

router = APIRouter(prefix="/attendance", tags=["attendance"])


@router.get("/", response_model=dict)
async def list_records(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    cohort_id: Optional[int] = None,
    user_id: Optional[int] = None,
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
    type: Optional[str] = None,
    page: int = 1,
    size: int = 20,
):
    records, total = await attendance_service.list_records(
        db, current_user, cohort_id=cohort_id, user_id=user_id,
        from_date=from_date, to_date=to_date, type_filter=type,
        page=page, size=size,
    )
    return paginated([r.model_dump() for r in records], page, size, total)


@router.get("/summary", response_model=dict)
async def get_summary(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    cohort_id: Optional[int] = None,
    user_id: Optional[int] = None,
):
    summary = await attendance_service.get_summary(db, current_user, cohort_id, user_id)
    return ok(summary.model_dump())


@router.patch("/{record_id}", response_model=dict)
async def update_record(
    record_id: int,
    body: AttendanceUpdate,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    record = await attendance_service.update_record(db, record_id, body.type, body.note, current_user)
    return ok(record.model_dump())


@router.post("/import", response_model=dict)
async def import_csv(
    file: UploadFile,
    cohort_id: int,
    dry_run: bool = False,
    current_user: Annotated[User, Depends(require_roles("admin_ops"))] = None,
    db: Annotated[AsyncSession, Depends(get_db)] = None,
):
    content = await file.read()
    result = await attendance_service.import_csv_from_key(
        db,
        file_key=f"attendance/{cohort_id}/{file.filename}",
        file_name=file.filename or "upload.csv",
        cohort_id=cohort_id,
        dry_run=dry_run,
        uploader=current_user,
    )
    return ok(result.model_dump())


@router.get("/imports", response_model=dict)
async def list_imports(
    _: Annotated[User, Depends(require_roles("admin_ops", "tech_support"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    cohort_id: Optional[int] = None,
    status: Optional[str] = None,
    page: int = 1,
    size: int = 20,
):
    logs, total = await attendance_service.list_import_logs(
        db, cohort_id=cohort_id, status=status, page=page, size=size
    )
    return paginated([l.model_dump() for l in logs], page, size, total)


@router.post("/imports/{batch_id}/rollback", response_model=dict)
async def rollback_import(
    batch_id: str,
    _: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await attendance_service.rollback_batch(db, batch_id)
    return ok(result)


@router.post("/notify", response_model=dict)
async def notify_absences(
    body: NotifyRequest,
    _: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    return ok({"sent": len(body.user_ids)})
