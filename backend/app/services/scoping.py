from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.auth import User
from app.models.organization import InstructorCohort


async def get_instructor_cohort_ids(db: AsyncSession, instructor_id: int) -> list[int]:
    """Cohort ids an instructor teaches, via the ``instructor_cohorts`` join table.

    Instructors are linked to cohorts through the many-to-many join table, not via
    ``users.cohort_id`` (which is NULL for instructors). Services must scope
    instructor access by this set rather than the single column. One query per
    request (no N+1).
    """
    result = await db.execute(
        select(InstructorCohort.cohort_id).where(
            InstructorCohort.instructor_id == instructor_id
        )
    )
    return [row[0] for row in result.all()]


async def get_user_cohort_ids(db: AsyncSession, user: User) -> list[int]:
    """Resolve the full set of cohort ids a user is associated with.

    - student: their single ``users.cohort_id`` (if set).
    - instructor: the cohorts they teach, via ``instructor_cohorts``.
    - admin_ops / tech_support: [] (institution-wide; not cohort-scoped here).
    """
    if user.role == "instructor":
        return await get_instructor_cohort_ids(db, user.id)
    if user.role == "student":
        return [user.cohort_id] if user.cohort_id is not None else []
    return []
