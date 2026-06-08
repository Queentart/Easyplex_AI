from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.auth import User
from app.services.scoping import get_instructor_cohort_ids
from app.models.class_ import (
    CareerPosting,
    Class,
    ClassEvaluation,
    ClassRecording,
    CurriculumItem,
    MentoringLog,
    TrainingLog,
)
from app.schemas.class_ import (
    CareerPostingCreate,
    CareerPostingOut,
    ClassCreate,
    ClassOut,
    ClassUpdate,
    CurriculumItemCreate,
    CurriculumItemOut,
    CurriculumItemUpdate,
    EvaluationCreate,
    EvaluationSummary,
    MentoringLogCreate,
    MentoringLogOut,
    RecordingCreate,
    TrainingLogCreate,
    TrainingLogOut,
    TrainingLogUpdate,
)


async def list_classes(
    db: AsyncSession,
    current_user: User,
    cohort_id: Optional[int] = None,
    from_date=None,
    to_date=None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[ClassOut], int]:
    query = select(Class)

    if current_user.role == "student":
        query = query.where(Class.cohort_id == current_user.cohort_id)
    elif current_user.role == "instructor":
        taught = await get_instructor_cohort_ids(db, current_user.id)
        if taught:
            query = query.where(
                or_(
                    Class.cohort_id.in_(taught),
                    Class.instructor_id == current_user.id,
                )
            )
        else:
            query = query.where(Class.instructor_id == current_user.id)

    if cohort_id:
        query = query.where(Class.cohort_id == cohort_id)
    if from_date:
        query = query.where(Class.date >= from_date)
    if to_date:
        query = query.where(Class.date <= to_date)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(Class.date.desc())
    )
    return [ClassOut.model_validate(c) for c in result.scalars().all()], total


async def create_class(
    db: AsyncSession, data: ClassCreate, current_user: User
) -> ClassOut:
    class_ = Class(**data.model_dump(), status="scheduled")
    db.add(class_)
    await db.commit()
    await db.refresh(class_)
    return ClassOut.model_validate(class_)


async def get_class(db: AsyncSession, class_id: int, current_user: User) -> ClassOut:
    result = await db.execute(select(Class).where(Class.id == class_id))
    class_ = result.scalar_one_or_none()
    if class_ is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "수업을 찾을 수 없습니다."})

    if current_user.role == "student" and class_.cohort_id != current_user.cohort_id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    return ClassOut.model_validate(class_)


async def update_class(
    db: AsyncSession, class_id: int, data: ClassUpdate, current_user: User
) -> ClassOut:
    result = await db.execute(select(Class).where(Class.id == class_id))
    class_ = result.scalar_one_or_none()
    if class_ is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "수업을 찾을 수 없습니다."})

    if current_user.role not in ("admin_ops",) and class_.instructor_id != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(class_, field, value)
    await db.commit()
    await db.refresh(class_)
    return ClassOut.model_validate(class_)


async def add_recording(
    db: AsyncSession, class_id: int, data: RecordingCreate, current_user: User
) -> ClassOut:
    class_result = await db.execute(select(Class).where(Class.id == class_id))
    class_ = class_result.scalar_one_or_none()
    if class_ is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "수업을 찾을 수 없습니다."})

    recording = ClassRecording(
        class_id=class_id,
        cohort_id=class_.cohort_id,
        title=data.title,
        recording_url=data.file_key,
        duration_seconds=data.duration_seconds,
        created_by=current_user.id,
        created_at=datetime.now(timezone.utc),
    )
    db.add(recording)
    await db.commit()
    return ClassOut.model_validate(class_)


async def create_training_log(
    db: AsyncSession, class_id: int, data: TrainingLogCreate, current_user: User
) -> TrainingLogOut:
    existing = await db.execute(
        select(TrainingLog).where(TrainingLog.class_id == class_id)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409,
                            detail={"code": "LOG_ALREADY_EXISTS", "message": "이미 훈련일지가 작성된 수업입니다."})

    log = TrainingLog(
        class_id=class_id,
        instructor_id=current_user.id,
        **data.model_dump(),
        submitted_at=datetime.now(timezone.utc),
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return TrainingLogOut.model_validate(log)


async def get_training_log(db: AsyncSession, class_id: int) -> TrainingLogOut:
    result = await db.execute(
        select(TrainingLog).where(TrainingLog.class_id == class_id)
    )
    log = result.scalar_one_or_none()
    if log is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "훈련일지를 찾을 수 없습니다."})
    return TrainingLogOut.model_validate(log)


async def update_training_log(
    db: AsyncSession, class_id: int, data: TrainingLogUpdate, current_user: User
) -> TrainingLogOut:
    result = await db.execute(
        select(TrainingLog).where(TrainingLog.class_id == class_id)
    )
    log = result.scalar_one_or_none()
    if log is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "훈련일지를 찾을 수 없습니다."})

    deadline = log.submitted_at + timedelta(hours=24)
    if current_user.role != "admin_ops" and datetime.now(timezone.utc) > deadline:
        raise HTTPException(status_code=422,
                            detail={"code": "EDIT_WINDOW_CLOSED", "message": "작성 후 24시간이 지나 수정할 수 없습니다."})

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(log, field, value)
    await db.commit()
    await db.refresh(log)
    return TrainingLogOut.model_validate(log)


async def list_mentoring_logs(
    db: AsyncSession,
    current_user: User,
    student_id: Optional[int] = None,
    instructor_id: Optional[int] = None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[MentoringLogOut], int]:
    query = select(MentoringLog)

    if current_user.role == "instructor":
        query = query.where(MentoringLog.instructor_id == current_user.id)
    elif current_user.role == "student":
        query = query.where(MentoringLog.student_id == current_user.id)

    if student_id:
        query = query.where(MentoringLog.student_id == student_id)
    if instructor_id:
        query = query.where(MentoringLog.instructor_id == instructor_id)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(MentoringLog.session_date.desc())
    )
    return [MentoringLogOut.model_validate(m) for m in result.scalars().all()], total


async def create_mentoring_log(
    db: AsyncSession, data: MentoringLogCreate, current_user: User
) -> MentoringLogOut:
    cohort_id = data.cohort_id or current_user.cohort_id
    if not cohort_id:
        raise HTTPException(status_code=422, detail={"code": "NO_COHORT", "message": "기수 정보가 필요합니다."})

    log = MentoringLog(
        cohort_id=cohort_id,
        instructor_id=current_user.id,
        student_id=data.student_id,
        session_date=data.session_date,
        content=data.content,
        follow_up=data.follow_up,
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return MentoringLogOut.model_validate(log)


async def submit_evaluation(
    db: AsyncSession, class_id: int, data: EvaluationCreate, current_user: User
) -> dict:
    existing = await db.execute(
        select(ClassEvaluation).where(
            ClassEvaluation.class_id == class_id,
            ClassEvaluation.student_id == current_user.id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409,
                            detail={"code": "ALREADY_EVALUATED", "message": "이미 평가를 제출했습니다."})

    evaluation = ClassEvaluation(
        class_id=class_id,
        student_id=current_user.id,
        **data.model_dump(),
        created_at=datetime.now(timezone.utc),
    )
    db.add(evaluation)
    await db.commit()
    return {"ok": True}


async def get_evaluation_summary(
    db: AsyncSession, class_id: int, current_user: User
) -> EvaluationSummary:
    result = await db.execute(
        select(ClassEvaluation).where(ClassEvaluation.class_id == class_id)
    )
    evaluations = result.scalars().all()
    if not evaluations:
        return EvaluationSummary(average=0.0, count=0, distribution={}, comments=[])

    ratings = [e.rating for e in evaluations]
    average = sum(ratings) / len(ratings)
    distribution = {str(r): ratings.count(r) for r in range(1, 6)}
    comments = [e.comment for e in evaluations if e.comment]

    if current_user.role == "instructor":
        comments = [c for c in comments]
    return EvaluationSummary(
        average=round(average, 2),
        count=len(evaluations),
        distribution=distribution,
        comments=comments,
    )


async def list_curriculum(
    db: AsyncSession, cohort_id: int
) -> list[CurriculumItemOut]:
    result = await db.execute(
        select(CurriculumItem).where(CurriculumItem.cohort_id == cohort_id)
        .order_by(CurriculumItem.week, CurriculumItem.day, CurriculumItem.sort_order)
    )
    return [CurriculumItemOut.model_validate(i) for i in result.scalars().all()]


async def create_curriculum_item(
    db: AsyncSession, cohort_id: int, data: CurriculumItemCreate, current_user: User
) -> CurriculumItemOut:
    item = CurriculumItem(cohort_id=cohort_id, **data.model_dump())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return CurriculumItemOut.model_validate(item)


async def update_curriculum_item(
    db: AsyncSession, item_id: int, data: CurriculumItemUpdate
) -> CurriculumItemOut:
    result = await db.execute(select(CurriculumItem).where(CurriculumItem.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "항목을 찾을 수 없습니다."})

    if data.is_completed and not item.is_completed:
        item.completed_at = datetime.now(timezone.utc)

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(item, field, value)
    await db.commit()
    await db.refresh(item)
    return CurriculumItemOut.model_validate(item)


async def list_career_postings(
    db: AsyncSession, current_user: User, page: int = 1, size: int = 20
) -> tuple[list[CareerPostingOut], int]:
    query = select(CareerPosting).where(
        CareerPosting.institution_id == current_user.institution_id
    )

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(CareerPosting.created_at.desc())
    )
    return [CareerPostingOut.model_validate(p) for p in result.scalars().all()], total


async def create_career_posting(
    db: AsyncSession, data: CareerPostingCreate, current_user: User
) -> CareerPostingOut:
    posting = CareerPosting(
        institution_id=current_user.institution_id,
        **data.model_dump(),
        created_by=current_user.id,
    )
    db.add(posting)
    await db.commit()
    await db.refresh(posting)
    return CareerPostingOut.model_validate(posting)
