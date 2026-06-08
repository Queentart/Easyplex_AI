from typing import Annotated, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_roles
from app.models.auth import User
from app.schemas.assignment import (
    AssignmentCreate,
    AssignmentUpdate,
    FeedbackRequest,
    SubmissionCreate,
)
from app.schemas.common import ok, paginated
from app.services import assignment as assignment_service

router = APIRouter(tags=["assignments"])


@router.get("/assignments", response_model=dict)
async def list_assignments(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    cohort_id: Optional[int] = None,
    status: Optional[str] = None,
    page: int = 1,
    size: int = 20,
):
    assignments, total = await assignment_service.list_assignments(
        db, current_user, cohort_id=cohort_id, status=status, page=page, size=size
    )
    return paginated([a.model_dump() for a in assignments], page, size, total)


@router.post("/assignments", response_model=dict)
async def create_assignment(
    body: AssignmentCreate,
    current_user: Annotated[User, Depends(require_roles("instructor", "admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    assignment = await assignment_service.create_assignment(db, body, current_user)
    return ok(assignment.model_dump())


@router.get("/assignments/{assignment_id}", response_model=dict)
async def get_assignment(
    assignment_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    assignment = await assignment_service.get_assignment(db, assignment_id, current_user)
    return ok(assignment.model_dump())


@router.patch("/assignments/{assignment_id}", response_model=dict)
async def update_assignment(
    assignment_id: int,
    body: AssignmentUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    assignment = await assignment_service.update_assignment(db, assignment_id, body, current_user)
    return ok(assignment.model_dump())


@router.delete("/assignments/{assignment_id}", response_model=dict)
async def delete_assignment(
    assignment_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await assignment_service.delete_assignment(db, assignment_id, current_user)
    return ok({"ok": True})


@router.post("/assignments/{assignment_id}/submissions", response_model=dict)
async def submit_assignment(
    assignment_id: int,
    body: SubmissionCreate,
    current_user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    submission = await assignment_service.submit(db, assignment_id, body, current_user)
    return ok(submission.model_dump())


@router.get("/assignments/{assignment_id}/submissions", response_model=dict)
async def list_submissions(
    assignment_id: int,
    current_user: Annotated[User, Depends(require_roles("instructor", "admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    page: int = 1,
    size: int = 20,
):
    submissions, total = await assignment_service.list_submissions(
        db, assignment_id, current_user, page=page, size=size
    )
    return paginated([s.model_dump() for s in submissions], page, size, total)


@router.get("/submissions/{submission_id}", response_model=dict)
async def get_submission(
    submission_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    submission = await assignment_service.get_submission(db, submission_id, current_user)
    return ok(submission.model_dump())


@router.patch("/submissions/{submission_id}/feedback", response_model=dict)
async def give_feedback(
    submission_id: int,
    body: FeedbackRequest,
    current_user: Annotated[User, Depends(require_roles("instructor", "admin_ops"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    submission = await assignment_service.give_feedback(db, submission_id, body, current_user)
    return ok(submission.model_dump())
