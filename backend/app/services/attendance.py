from __future__ import annotations

import csv
import io
import uuid
from datetime import date, datetime, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attendance import AttendanceImportLog, AttendanceRecord
from app.models.auth import User
from app.models.organization import InstructorCohort
from app.schemas.attendance import (
    AttendanceOut,
    AttendanceSummary,
    ImportLogOut,
    ImportResult,
)

ATTENDANCE_TYPES = {"present", "late", "absent", "early_leave", "medical", "official"}


async def _instructor_cohort_ids(db: AsyncSession, instructor_id: int) -> list[int]:
    """Cohort ids an instructor teaches, via the instructor_cohorts join table.

    Instructors are linked to cohorts through the many-to-many join table, not
    via ``users.cohort_id`` (which is NULL for instructors), so attendance must
    be scoped by this set rather than the single column.
    """
    result = await db.execute(
        select(InstructorCohort.cohort_id).where(
            InstructorCohort.instructor_id == instructor_id
        )
    )
    return [row[0] for row in result.all()]


async def list_records(
    db: AsyncSession,
    current_user: User,
    cohort_id: Optional[int] = None,
    user_id: Optional[int] = None,
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
    type_filter: Optional[str] = None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[AttendanceOut], int]:
    query = select(AttendanceRecord)

    if current_user.role == "student":
        query = query.where(AttendanceRecord.user_id == current_user.id)
    elif current_user.role == "instructor":
        taught = await _instructor_cohort_ids(db, current_user.id)
        if not taught:
            return [], 0
        if cohort_id is not None and cohort_id in taught:
            # Honor an explicit, in-scope cohort filter.
            query = query.where(AttendanceRecord.cohort_id == cohort_id)
        else:
            # Otherwise restrict to the cohorts they teach.
            query = query.where(AttendanceRecord.cohort_id.in_(taught))
        cohort_id = None  # already applied; skip the generic filter below

    if cohort_id:
        query = query.where(AttendanceRecord.cohort_id == cohort_id)
    if user_id:
        query = query.where(AttendanceRecord.user_id == user_id)
    if from_date:
        query = query.where(AttendanceRecord.date >= from_date)
    if to_date:
        query = query.where(AttendanceRecord.date <= to_date)
    if type_filter:
        query = query.where(AttendanceRecord.type == type_filter)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(AttendanceRecord.date.desc())
    )
    records = result.scalars().all()
    return [AttendanceOut.model_validate(r) for r in records], total


async def get_summary(
    db: AsyncSession,
    current_user: User,
    cohort_id: Optional[int] = None,
    user_id: Optional[int] = None,
) -> AttendanceSummary:
    if current_user.role == "instructor":
        taught = await _instructor_cohort_ids(db, current_user.id)
        if not taught:
            raise HTTPException(status_code=400, detail={"code": "BAD_REQUEST", "message": "담당 기수가 없습니다."})
        if cohort_id is not None and cohort_id in taught:
            target_cohort = cohort_id
        else:
            # No explicit (or out-of-scope) cohort: default to the first taught cohort.
            target_cohort = taught[0]
    else:
        target_cohort = cohort_id or current_user.cohort_id

    if not target_cohort:
        raise HTTPException(status_code=400, detail={"code": "BAD_REQUEST", "message": "cohort_id가 필요합니다."})

    query = select(AttendanceRecord).where(AttendanceRecord.cohort_id == target_cohort)

    if current_user.role == "student":
        query = query.where(AttendanceRecord.user_id == current_user.id)
        target_user_id = current_user.id
    else:
        target_user_id = user_id
        if user_id:
            query = query.where(AttendanceRecord.user_id == user_id)

    result = await db.execute(query)
    records = result.scalars().all()

    counts: dict[str, int] = {t: 0 for t in ATTENDANCE_TYPES}
    for r in records:
        counts[r.type] = counts.get(r.type, 0) + 1

    total_days = len(records)
    late_to_absent_ratio = 3
    computed_absent = counts["absent"] + (counts["late"] // late_to_absent_ratio)
    attendance_rate = (counts["present"] + counts["late"]) / total_days if total_days > 0 else 0.0

    return AttendanceSummary(
        user_id=target_user_id,
        cohort_id=target_cohort,
        total_days=total_days,
        present=counts["present"],
        late=counts["late"],
        absent=counts["absent"],
        early_leave=counts["early_leave"],
        medical=counts["medical"],
        official=counts["official"],
        computed_absent=computed_absent,
        attendance_rate=round(attendance_rate, 4),
    )


async def update_record(
    db: AsyncSession, record_id: int, attendance_type: str, note: str, current_user: User
) -> AttendanceOut:
    if attendance_type not in ATTENDANCE_TYPES:
        raise HTTPException(status_code=422,
                            detail={"code": "INVALID_TYPE", "message": "유효하지 않은 출결 유형입니다."})

    result = await db.execute(select(AttendanceRecord).where(AttendanceRecord.id == record_id))
    record = result.scalar_one_or_none()
    if record is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "기록을 찾을 수 없습니다."})

    if current_user.role == "instructor":
        if not note:
            raise HTTPException(status_code=422,
                                detail={"code": "REASON_REQUIRED", "message": "강사는 수정 사유를 입력해야 합니다."})
        taught = await _instructor_cohort_ids(db, current_user.id)
        if record.cohort_id not in taught:
            raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    record.type = attendance_type
    record.note = note
    record.import_source = "manual"
    await db.commit()
    await db.refresh(record)
    return AttendanceOut.model_validate(record)


async def import_csv_from_key(
    db: AsyncSession,
    file_key: str,
    file_name: str,
    cohort_id: int,
    dry_run: bool,
    uploader: User,
) -> ImportResult:
    batch_id = str(uuid.uuid4())
    imported = 0
    updated = 0
    skipped = 0
    preview: list[dict] = []

    if not dry_run:
        # NOTE: CSV parsing is not yet implemented. Status is "pending" until
        # the Celery task processes the file and updates this record.
        log = AttendanceImportLog(
            institution_id=uploader.institution_id,
            cohort_id=cohort_id,
            uploader_id=uploader.id,
            file_name=file_name,
            file_path=file_key,
            batch_id=batch_id,
            row_count=0,
            success_count=0,
            fail_count=0,
            status="pending",
        )
        db.add(log)
        await db.commit()

    return ImportResult(
        batch_id=batch_id,
        imported=imported,
        updated=updated,
        skipped=skipped,
        preview=preview,
    )


async def rollback_batch(db: AsyncSession, batch_id: str) -> dict:
    log_result = await db.execute(
        select(AttendanceImportLog).where(AttendanceImportLog.batch_id == batch_id)
    )
    log = log_result.scalar_one_or_none()
    if log is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "배치를 찾을 수 없습니다."})
    if log.status == "rolled_back":
        raise HTTPException(status_code=422, detail={"code": "ALREADY_ROLLED_BACK", "message": "이미 롤백된 배치입니다."})

    await db.execute(
        delete(AttendanceRecord).where(AttendanceRecord.import_batch_id == batch_id)
    )
    log.status = "rolled_back"
    log.rolled_back_at = datetime.now(timezone.utc)
    await db.commit()

    return {"batch_id": batch_id, "status": "rolled_back"}


async def list_import_logs(
    db: AsyncSession,
    cohort_id: Optional[int] = None,
    status: Optional[str] = None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[ImportLogOut], int]:
    query = select(AttendanceImportLog)
    if cohort_id:
        query = query.where(AttendanceImportLog.cohort_id == cohort_id)
    if status:
        query = query.where(AttendanceImportLog.status == status)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size)
        .limit(size)
        .order_by(AttendanceImportLog.created_at.desc())
    )
    logs = result.scalars().all()
    return [ImportLogOut.model_validate(l) for l in logs], total
