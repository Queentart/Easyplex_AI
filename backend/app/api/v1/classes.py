from datetime import date
from typing import Annotated, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_roles
from app.models.auth import User
from app.schemas.class_ import (
    CareerPostingCreate,
    ClassCreate,
    ClassUpdate,
    CurriculumItemCreate,
    CurriculumItemUpdate,
    EvaluationCreate,
    MentoringLogCreate,
    RecordingCreate,
    TrainingLogCreate,
    TrainingLogUpdate,
)
from app.schemas.common import ok, paginated
from app.services import class_ as class_service

router = APIRouter(tags=["classes"])


@router.get("/classes", response_model=dict)
async def list_classes(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    cohort_id: Optional[int] = None,
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
    page: int = 1,
    size: int = 20,
):
    classes, total = await class_service.list_classes(
        db, current_user, cohort_id=cohort_id, from_date=from_date,
        to_date=to_date, page=page, size=size,
    )
    return paginated([c.model_dump() for c in classes], page, size, total)


@router.post("/classes", response_model=dict)
async def create_class(
    body: ClassCreate,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    class_ = await class_service.create_class(db, body, current_user)
    return ok(class_.model_dump())


@router.get("/classes/{class_id}", response_model=dict)
async def get_class(
    class_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    class_ = await class_service.get_class(db, class_id, current_user)
    return ok(class_.model_dump())


@router.patch("/classes/{class_id}", response_model=dict)
async def update_class(
    class_id: int,
    body: ClassUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    class_ = await class_service.update_class(db, class_id, body, current_user)
    return ok(class_.model_dump())


@router.post("/classes/{class_id}/recording", response_model=dict)
async def add_recording(
    class_id: int,
    body: RecordingCreate,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    class_ = await class_service.add_recording(db, class_id, body, current_user)
    return ok(class_.model_dump())


@router.post("/classes/{class_id}/training-log", response_model=dict)
async def create_training_log(
    class_id: int,
    body: TrainingLogCreate,
    current_user: Annotated[User, Depends(require_roles("instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    log = await class_service.create_training_log(db, class_id, body, current_user)
    return ok(log.model_dump())


@router.get("/classes/{class_id}/training-log", response_model=dict)
async def get_training_log(
    class_id: int,
    _: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    log = await class_service.get_training_log(db, class_id)
    return ok(log.model_dump())


@router.patch("/classes/{class_id}/training-log", response_model=dict)
async def update_training_log(
    class_id: int,
    body: TrainingLogUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    log = await class_service.update_training_log(db, class_id, body, current_user)
    return ok(log.model_dump())


@router.post("/classes/{class_id}/evaluations", response_model=dict)
async def submit_evaluation(
    class_id: int,
    body: EvaluationCreate,
    current_user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await class_service.submit_evaluation(db, class_id, body, current_user)
    return ok(result)


@router.get("/classes/{class_id}/evaluations", response_model=dict)
async def get_evaluations(
    class_id: int,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    summary = await class_service.get_evaluation_summary(db, class_id, current_user)
    return ok(summary.model_dump())


@router.get("/cohorts/{cohort_id}/curriculum", response_model=dict)
async def list_curriculum(
    cohort_id: int,
    _: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    items = await class_service.list_curriculum(db, cohort_id)
    return ok([i.model_dump() for i in items])


@router.post("/cohorts/{cohort_id}/curriculum", response_model=dict)
async def create_curriculum_item(
    cohort_id: int,
    body: CurriculumItemCreate,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    item = await class_service.create_curriculum_item(db, cohort_id, body, current_user)
    return ok(item.model_dump())


@router.patch("/curriculum/{item_id}", response_model=dict)
async def update_curriculum_item(
    item_id: int,
    body: CurriculumItemUpdate,
    _: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    item = await class_service.update_curriculum_item(db, item_id, body)
    return ok(item.model_dump())


@router.get("/mentoring-logs", response_model=dict)
async def list_mentoring_logs(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    student_id: Optional[int] = None,
    instructor_id: Optional[int] = None,
    page: int = 1,
    size: int = 20,
):
    logs, total = await class_service.list_mentoring_logs(
        db, current_user, student_id=student_id, instructor_id=instructor_id,
        page=page, size=size,
    )
    return paginated([l.model_dump() for l in logs], page, size, total)


@router.post("/mentoring-logs", response_model=dict)
async def create_mentoring_log(
    body: MentoringLogCreate,
    current_user: Annotated[User, Depends(require_roles("instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    log = await class_service.create_mentoring_log(db, body, current_user)
    return ok(log.model_dump())


@router.get("/career-postings", response_model=dict)
async def list_career_postings(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    page: int = 1,
    size: int = 20,
):
    postings, total = await class_service.list_career_postings(db, current_user, page, size)
    return paginated([p.model_dump() for p in postings], page, size, total)


@router.post("/career-postings", response_model=dict)
async def create_career_posting(
    body: CareerPostingCreate,
    current_user: Annotated[User, Depends(require_roles("admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    posting = await class_service.create_career_posting(db, body, current_user)
    return ok(posting.model_dump())
