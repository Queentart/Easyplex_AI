from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.assignment import Assignment, AssignmentAttachment, Submission, SubmissionFile
from app.models.auth import User
from app.services.scoping import get_instructor_cohort_ids
from app.schemas.assignment import (
    AssignmentCreate,
    AssignmentOut,
    AssignmentUpdate,
    FeedbackRequest,
    SubmissionCreate,
    SubmissionListItem,
    SubmissionOut,
)


async def list_assignments(
    db: AsyncSession,
    current_user: User,
    cohort_id: Optional[int] = None,
    status: Optional[str] = None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[AssignmentOut], int]:
    query = select(Assignment)

    if current_user.role == "student":
        query = query.where(Assignment.cohort_id == current_user.cohort_id)
    elif current_user.role == "instructor":
        taught = await get_instructor_cohort_ids(db, current_user.id)
        if taught:
            query = query.where(
                (Assignment.cohort_id.in_(taught)) |
                (Assignment.created_by == current_user.id)
            )
        else:
            query = query.where(Assignment.created_by == current_user.id)

    if cohort_id:
        query = query.where(Assignment.cohort_id == cohort_id)
    if status:
        query = query.where(Assignment.status == status)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(Assignment.due_date.desc())
    )
    return [AssignmentOut.model_validate(a) for a in result.scalars().all()], total


async def create_assignment(
    db: AsyncSession, data: AssignmentCreate, current_user: User
) -> AssignmentOut:
    attachment_data = data.model_dump(exclude={"attachments"})
    assignment = Assignment(**attachment_data, created_by=current_user.id)
    db.add(assignment)
    await db.flush()

    for att in data.attachments:
        db.add(AssignmentAttachment(
            assignment_id=assignment.id,
            file_key=att.get("file_key", ""),
            file_name=att.get("file_name", ""),
            file_size=att.get("file_size", 0),
            mime_type=att.get("mime_type"),
            uploaded_by=current_user.id,
            created_at=datetime.now(timezone.utc),
        ))

    await db.commit()
    await db.refresh(assignment)
    return AssignmentOut.model_validate(assignment)


async def get_assignment(
    db: AsyncSession, assignment_id: int, current_user: User
) -> AssignmentOut:
    result = await db.execute(select(Assignment).where(Assignment.id == assignment_id))
    assignment = result.scalar_one_or_none()
    if assignment is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "과제를 찾을 수 없습니다."})

    if current_user.role == "student" and assignment.cohort_id != current_user.cohort_id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    return AssignmentOut.model_validate(assignment)


async def update_assignment(
    db: AsyncSession, assignment_id: int, data: AssignmentUpdate, current_user: User
) -> AssignmentOut:
    result = await db.execute(select(Assignment).where(Assignment.id == assignment_id))
    assignment = result.scalar_one_or_none()
    if assignment is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "과제를 찾을 수 없습니다."})

    if current_user.role != "admin_ops" and assignment.created_by != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    if data.due_date and data.due_date < assignment.due_date:
        sub_count = await db.execute(
            select(func.count()).where(Submission.assignment_id == assignment_id)
        )
        if sub_count.scalar_one() > 0:
            raise HTTPException(status_code=422,
                                detail={"code": "CANNOT_EDIT_AFTER_SUBMISSION",
                                        "message": "제출자가 있으면 마감일을 단축할 수 없습니다."})

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(assignment, field, value)
    await db.commit()
    await db.refresh(assignment)
    return AssignmentOut.model_validate(assignment)


async def delete_assignment(
    db: AsyncSession, assignment_id: int, current_user: User
) -> None:
    result = await db.execute(select(Assignment).where(Assignment.id == assignment_id))
    assignment = result.scalar_one_or_none()
    if assignment is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "과제를 찾을 수 없습니다."})

    if current_user.role != "admin_ops" and assignment.created_by != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    sub_count = await db.execute(
        select(func.count()).where(Submission.assignment_id == assignment_id)
    )
    if sub_count.scalar_one() > 0:
        raise HTTPException(status_code=422,
                            detail={"code": "ASSIGNMENT_HAS_SUBMISSIONS",
                                    "message": "제출이 있는 과제는 삭제할 수 없습니다."})

    await db.delete(assignment)
    await db.commit()


async def submit(
    db: AsyncSession, assignment_id: int, data: SubmissionCreate, current_user: User
) -> SubmissionOut:
    result = await db.execute(select(Assignment).where(Assignment.id == assignment_id))
    assignment = result.scalar_one_or_none()
    if assignment is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "과제를 찾을 수 없습니다."})

    now = datetime.now(timezone.utc)
    if now > assignment.due_date and not assignment.allow_late_submission:
        raise HTTPException(status_code=422,
                            detail={"code": "LATE_NOT_ALLOWED", "message": "지각 제출이 허용되지 않습니다."})

    is_late = now > assignment.due_date

    existing_result = await db.execute(
        select(Submission).where(
            Submission.assignment_id == assignment_id,
            Submission.student_id == current_user.id,
        )
    )
    existing = existing_result.scalar_one_or_none()

    if existing:
        existing.content = data.content
        existing.submitted_at = now
        existing.is_late = is_late
        existing.status = "submitted"
        submission = existing
    else:
        submission = Submission(
            assignment_id=assignment_id,
            student_id=current_user.id,
            content=data.content,
            submitted_at=now,
            is_late=is_late,
        )
        db.add(submission)
        await db.flush()

    if data.file_key and data.file_name:
        db.add(SubmissionFile(
            submission_id=submission.id,
            file_key=data.file_key,
            file_name=data.file_name,
            file_size=data.file_size or 0,
            mime_type=data.mime_type,
            created_at=now,
        ))

    await db.commit()
    await db.refresh(submission)
    return SubmissionOut.model_validate(submission)


async def list_submissions(
    db: AsyncSession, assignment_id: int, current_user: User, page: int = 1, size: int = 20
) -> tuple[list[SubmissionListItem], int]:
    query = select(Submission, User.name.label("student_name")).join(
        User, User.id == Submission.student_id
    ).where(Submission.assignment_id == assignment_id)

    total_result = await db.execute(select(func.count()).select_from(
        select(Submission).where(Submission.assignment_id == assignment_id).subquery()
    ))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(Submission.submitted_at.desc())
    )
    rows = result.all()

    items = []
    for sub, name in rows:
        item = SubmissionListItem(
            id=sub.id,
            student_id=sub.student_id,
            student_name=name,
            submitted_at=sub.submitted_at,
            is_late=sub.is_late,
            score=sub.score,
            status=sub.status,
        )
        items.append(item)
    return items, total


async def get_submission(
    db: AsyncSession, submission_id: int, current_user: User
) -> SubmissionOut:
    result = await db.execute(select(Submission).where(Submission.id == submission_id))
    submission = result.scalar_one_or_none()
    if submission is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "제출을 찾을 수 없습니다."})

    if (current_user.role == "student" and submission.student_id != current_user.id):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    return SubmissionOut.model_validate(submission)


async def give_feedback(
    db: AsyncSession, submission_id: int, data: FeedbackRequest, current_user: User
) -> SubmissionOut:
    result = await db.execute(select(Submission).where(Submission.id == submission_id))
    submission = result.scalar_one_or_none()
    if submission is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "제출을 찾을 수 없습니다."})

    if data.score is not None:
        submission.score = data.score
    submission.status = data.status
    await db.commit()
    await db.refresh(submission)
    return SubmissionOut.model_validate(submission)
