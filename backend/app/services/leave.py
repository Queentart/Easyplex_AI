from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attendance import AttendanceRecord
from app.models.auth import User
from app.models.leave import LeaveRequest, LeaveRequestAttachment
from app.models.organization import Cohort, InstructorCohort
from app.schemas.leave import (
    LeaveBalanceOut,
    LeaveRequestCreate,
    LeaveRequestOut,
    ReviewRequest,
)


async def _instructor_cohort_ids(db: AsyncSession, instructor_id: int) -> list[int]:
    """Cohort ids an instructor teaches, via the instructor_cohorts join table.

    Instructors link to cohorts through the many-to-many join table, not via
    ``users.cohort_id`` (NULL for instructors), so leave requests must be scoped
    by this set.
    """
    result = await db.execute(
        select(InstructorCohort.cohort_id).where(
            InstructorCohort.instructor_id == instructor_id
        )
    )
    return [row[0] for row in result.all()]


async def list_requests(
    db: AsyncSession,
    current_user: User,
    status: Optional[str] = None,
    type_filter: Optional[str] = None,
    cohort_id: Optional[int] = None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[LeaveRequestOut], int]:
    query = select(LeaveRequest)

    if current_user.role == "student":
        query = query.where(LeaveRequest.student_id == current_user.id)
    elif current_user.role == "instructor":
        taught = await _instructor_cohort_ids(db, current_user.id)
        if not taught:
            return [], 0
        if cohort_id is not None and cohort_id in taught:
            # Honor an explicit, in-scope cohort filter.
            query = query.where(LeaveRequest.cohort_id == cohort_id)
        else:
            # Otherwise restrict to the cohorts they teach.
            query = query.where(LeaveRequest.cohort_id.in_(taught))
        cohort_id = None  # already applied; skip the generic filter below

    if status:
        query = query.where(LeaveRequest.status == status)
    if type_filter:
        query = query.where(LeaveRequest.type == type_filter)
    if cohort_id:
        query = query.where(LeaveRequest.cohort_id == cohort_id)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(LeaveRequest.created_at.desc())
    )
    requests = result.scalars().all()
    return [LeaveRequestOut.model_validate(r) for r in requests], total


async def get_student_leave_balance(
    db: AsyncSession, user: User
) -> LeaveBalanceOut:
    """Per-cohort excused-leave balance for a user.

    allowance = the user's cohort's ``leave_allowance_days`` (NULL = not configured).
    used = count of this user's leave_requests with status == "approved".

    Assumption: every approved leave request counts as 1 day regardless of type
    (early_leave / medical / official) — the allowance is a single per-cohort day
    count, not a per-type budget. Kept intentionally simple per product decision.
    """
    # Count approved requests for this user. Done even when the user has no cohort
    # (e.g. non-students) so the number is still meaningful.
    used_result = await db.execute(
        select(func.count()).where(
            LeaveRequest.student_id == user.id,
            LeaveRequest.status == "approved",
        )
    )
    used_days = used_result.scalar_one()

    # Allowance is a student concept. Non-students (instructor/admin) may carry a
    # cohort_id for a cohort they teach, not attend — never surface an allowance
    # for them (would be a wrong number).
    allowance_days: Optional[int] = None
    if user.role == "student" and user.cohort_id is not None:
        cohort_result = await db.execute(
            select(Cohort.leave_allowance_days).where(Cohort.id == user.cohort_id)
        )
        allowance_days = cohort_result.scalar_one_or_none()

    has_allowance = allowance_days is not None
    remaining_days = max(0, allowance_days - used_days) if has_allowance else None

    return LeaveBalanceOut(
        allowance_days=allowance_days,
        used_days=used_days,
        remaining_days=remaining_days,
        has_allowance=has_allowance,
    )


async def create_request(
    db: AsyncSession, data: LeaveRequestCreate, current_user: User
) -> LeaveRequestOut:
    student_id = data.student_id or current_user.id
    cohort_id = current_user.cohort_id
    if not cohort_id:
        raise HTTPException(status_code=422,
                            detail={"code": "NO_COHORT", "message": "기수에 소속되어야 합니다."})

    existing = await db.execute(
        select(LeaveRequest).where(
            LeaveRequest.student_id == student_id,
            LeaveRequest.target_date == data.target_date,
            LeaveRequest.type == data.type,
            LeaveRequest.status.in_(["pending", "approved"]),
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=422,
                            detail={"code": "DUPLICATE_REQUEST", "message": "동일 날짜에 같은 유형의 신청이 이미 존재합니다."})

    request = LeaveRequest(
        cohort_id=cohort_id,
        student_id=student_id,
        type=data.type,
        target_date=data.target_date,
        start_time=data.start_time,
        reason=data.reason,
    )
    db.add(request)
    await db.flush()

    if data.evidence_key:
        db.add(LeaveRequestAttachment(
            leave_request_id=request.id,
            file_key=data.evidence_key,
            file_name=data.evidence_name or "evidence",
            file_size=data.evidence_size or 0,
            uploaded_by=current_user.id,
            created_at=datetime.now(timezone.utc),
        ))

    await db.commit()
    await db.refresh(request)
    return LeaveRequestOut.model_validate(request)


async def get_request(
    db: AsyncSession, request_id: int, current_user: User
) -> LeaveRequestOut:
    result = await db.execute(select(LeaveRequest).where(LeaveRequest.id == request_id))
    req = result.scalar_one_or_none()
    if req is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "신청을 찾을 수 없습니다."})

    if current_user.role == "student" and req.student_id != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    return LeaveRequestOut.model_validate(req)


async def approve(
    db: AsyncSession, request_id: int, data: ReviewRequest, reviewer: User
) -> LeaveRequestOut:
    result = await db.execute(select(LeaveRequest).where(LeaveRequest.id == request_id))
    req = result.scalar_one_or_none()
    if req is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "신청을 찾을 수 없습니다."})

    if req.status != "pending":
        raise HTTPException(status_code=422,
                            detail={"code": "ALREADY_PROCESSED", "message": "이미 처리된 신청입니다."})

    now = datetime.now(timezone.utc)
    req.status = "approved"
    req.reviewed_by = reviewer.id
    req.reviewed_at = now
    req.review_comment = data.review_comment

    attendance_result = await db.execute(
        select(AttendanceRecord).where(
            AttendanceRecord.user_id == req.student_id,
            AttendanceRecord.date == req.target_date,
        )
    )
    attendance = attendance_result.scalar_one_or_none()
    if attendance:
        attendance.type = req.type
        attendance.linked_leave_request_id = req.id
    else:
        db.add(AttendanceRecord(
            cohort_id=req.cohort_id,
            user_id=req.student_id,
            date=req.target_date,
            type=req.type,
            linked_leave_request_id=req.id,
            import_source="manual",
        ))

    await db.commit()
    await db.refresh(req)
    return LeaveRequestOut.model_validate(req)


async def reject(
    db: AsyncSession, request_id: int, data: ReviewRequest, reviewer: User
) -> LeaveRequestOut:
    result = await db.execute(select(LeaveRequest).where(LeaveRequest.id == request_id))
    req = result.scalar_one_or_none()
    if req is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "신청을 찾을 수 없습니다."})

    if req.status != "pending":
        raise HTTPException(status_code=422,
                            detail={"code": "ALREADY_PROCESSED", "message": "이미 처리된 신청입니다."})

    req.status = "rejected"
    req.reviewed_by = reviewer.id
    req.reviewed_at = datetime.now(timezone.utc)
    req.review_comment = data.review_comment
    await db.commit()
    await db.refresh(req)
    return LeaveRequestOut.model_validate(req)


async def cancel(
    db: AsyncSession, request_id: int, current_user: User
) -> None:
    result = await db.execute(select(LeaveRequest).where(LeaveRequest.id == request_id))
    req = result.scalar_one_or_none()
    if req is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "신청을 찾을 수 없습니다."})

    if current_user.role == "student" and req.student_id != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    if req.status != "pending":
        raise HTTPException(status_code=422,
                            detail={"code": "CANNOT_CANCEL_PROCESSED", "message": "이미 처리된 신청은 취소할 수 없습니다."})

    req.status = "canceled"
    await db.commit()
