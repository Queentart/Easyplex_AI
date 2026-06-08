from __future__ import annotations

from typing import Optional

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.auth import User
from app.models.organization import Cohort, InstructorCohort
from app.schemas.cohort import (
    CohortCreate,
    CohortDetail,
    CohortOut,
    CohortUpdate,
    MembersAddResult,
)


async def list_cohorts(
    db: AsyncSession,
    current_user: User,
    status: Optional[str] = None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[CohortOut], int]:
    query = select(Cohort).where(Cohort.institution_id == current_user.institution_id)

    if current_user.role == "student":
        query = query.where(Cohort.id == current_user.cohort_id)
    elif current_user.role == "instructor":
        sub = select(InstructorCohort.cohort_id).where(
            InstructorCohort.instructor_id == current_user.id
        )
        query = query.where(Cohort.id.in_(sub))

    if status:
        query = query.where(Cohort.status == status)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(Cohort.start_date.desc())
    )
    cohorts = result.scalars().all()
    return [CohortOut.model_validate(c) for c in cohorts], total


async def get_cohort(
    db: AsyncSession, cohort_id: int, current_user: User
) -> CohortDetail:
    result = await db.execute(select(Cohort).where(Cohort.id == cohort_id))
    cohort = result.scalar_one_or_none()
    if cohort is None:
        raise HTTPException(status_code=404,
                            detail={"code": "NOT_FOUND", "message": "기수를 찾을 수 없습니다."})

    _assert_cohort_access(cohort, current_user)

    student_count_result = await db.execute(
        select(func.count()).where(
            User.cohort_id == cohort_id, User.role == "student", User.is_active == True
        )
    )
    instructor_count_result = await db.execute(
        select(func.count()).where(InstructorCohort.cohort_id == cohort_id)
    )

    detail = CohortDetail.model_validate(cohort)
    detail.student_count = student_count_result.scalar_one()
    detail.instructor_count = instructor_count_result.scalar_one()
    return detail


async def create_cohort(
    db: AsyncSession, data: CohortCreate, current_user: User
) -> CohortOut:
    existing = await db.execute(
        select(Cohort).where(
            Cohort.institution_id == current_user.institution_id,
            Cohort.code == data.code,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409,
                            detail={"code": "CODE_DUPLICATE", "message": "이미 사용 중인 기수 코드입니다."})

    cohort = Cohort(
        institution_id=current_user.institution_id,
        **data.model_dump(),
    )
    db.add(cohort)
    await db.commit()
    await db.refresh(cohort)
    return CohortOut.model_validate(cohort)


async def update_cohort(
    db: AsyncSession, cohort_id: int, data: CohortUpdate
) -> CohortOut:
    result = await db.execute(select(Cohort).where(Cohort.id == cohort_id))
    cohort = result.scalar_one_or_none()
    if cohort is None:
        raise HTTPException(status_code=404,
                            detail={"code": "NOT_FOUND", "message": "기수를 찾을 수 없습니다."})

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(cohort, field, value)
    await db.commit()
    await db.refresh(cohort)
    return CohortOut.model_validate(cohort)


async def archive_cohort(db: AsyncSession, cohort_id: int) -> None:
    result = await db.execute(select(Cohort).where(Cohort.id == cohort_id))
    cohort = result.scalar_one_or_none()
    if cohort is None:
        raise HTTPException(status_code=404,
                            detail={"code": "NOT_FOUND", "message": "기수를 찾을 수 없습니다."})

    student_count = await db.execute(
        select(func.count()).where(
            User.cohort_id == cohort_id, User.role == "student", User.is_active == True
        )
    )
    if student_count.scalar_one() > 0:
        raise HTTPException(status_code=422,
                            detail={"code": "COHORT_NOT_EMPTY", "message": "활성 학생이 있는 기수는 삭제할 수 없습니다."})

    cohort.status = "archived"
    await db.commit()


async def add_members(
    db: AsyncSession, cohort_id: int, user_ids: list[int], role: str, current_user: User
) -> MembersAddResult:
    added = 0
    skipped = 0

    for uid in user_ids:
        user_result = await db.execute(select(User).where(User.id == uid))
        user = user_result.scalar_one_or_none()
        if user is None:
            skipped += 1
            continue

        if role == "student":
            if user.cohort_id == cohort_id:
                skipped += 1
            else:
                user.cohort_id = cohort_id
                added += 1
        elif role == "instructor":
            existing = await db.execute(
                select(InstructorCohort).where(
                    InstructorCohort.instructor_id == uid,
                    InstructorCohort.cohort_id == cohort_id,
                )
            )
            if existing.scalar_one_or_none():
                skipped += 1
            else:
                db.add(InstructorCohort(
                    instructor_id=uid,
                    cohort_id=cohort_id,
                    assigned_by=current_user.id,
                ))
                added += 1

    await db.commit()
    return MembersAddResult(added=added, skipped=skipped)


async def get_cohort_members(
    db: AsyncSession,
    cohort_id: int,
    role: Optional[str] = None,
) -> list:
    from app.schemas.user import UserListItem

    members = []

    if role is None or role == "student":
        q = select(User).where(
            User.cohort_id == cohort_id,
            User.role == "student",
            User.is_active == True,
        )
        res = await db.execute(q)
        members += [UserListItem.model_validate(u) for u in res.scalars().all()]

    if role is None or role == "instructor":
        q = (
            select(User)
            .join(InstructorCohort, InstructorCohort.instructor_id == User.id)
            .where(InstructorCohort.cohort_id == cohort_id)
        )
        res = await db.execute(q)
        members += [UserListItem.model_validate(u) for u in res.scalars().all()]

    return members


async def remove_member(db: AsyncSession, cohort_id: int, user_id: int) -> None:
    user_res = await db.execute(select(User).where(User.id == user_id))
    user = user_res.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "NOT_FOUND", "message": "사용자를 찾을 수 없습니다."},
        )

    if user.role == "student" and user.cohort_id == cohort_id:
        user.cohort_id = None
        await db.commit()
        return

    if user.role == "instructor":
        ic_res = await db.execute(
            select(InstructorCohort).where(
                InstructorCohort.instructor_id == user_id,
                InstructorCohort.cohort_id == cohort_id,
            )
        )
        ic = ic_res.scalar_one_or_none()
        if ic:
            await db.delete(ic)
            await db.commit()
            return

    raise HTTPException(
        status_code=422,
        detail={"code": "NOT_MEMBER", "message": "해당 기수의 구성원이 아닙니다."},
    )


def _assert_cohort_access(cohort: Cohort, current_user: User) -> None:
    if current_user.role in ("admin_ops", "tech_support"):
        return
    if current_user.role == "student" and current_user.cohort_id != cohort.id:
        raise HTTPException(status_code=403,
                            detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})
