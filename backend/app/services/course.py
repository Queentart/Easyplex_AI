from __future__ import annotations

from datetime import date as date_type, datetime, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.auth import User
from app.models.course import Course, CourseDayLog, CourseVideo
from app.models.organization import Cohort
from app.schemas.course import (
    CourseCreate,
    CourseDayLogOut,
    CourseDayLogUpsert,
    CourseOut,
    CourseUpdate,
    CourseVideoCreate,
    CourseVideoOut,
)
from app.services.scoping import get_instructor_cohort_ids


def _forbidden() -> HTTPException:
    return HTTPException(
        status_code=403,
        detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."},
    )


def _not_found() -> HTTPException:
    return HTTPException(
        status_code=404,
        detail={"code": "NOT_FOUND", "message": "수업을 찾을 수 없습니다."},
    )


def _validation(message: str) -> HTTPException:
    return HTTPException(
        status_code=422,
        detail={"code": "VALIDATION_ERROR", "message": message},
    )


async def _cohort_in_institution(
    db: AsyncSession, cohort_id: int, institution_id: int
) -> bool:
    result = await db.execute(
        select(Cohort.id).where(
            Cohort.id == cohort_id, Cohort.institution_id == institution_id
        )
    )
    return result.scalar_one_or_none() is not None


async def _can_read_course(db: AsyncSession, course: Course, user: User) -> bool:
    if user.role == "admin_ops":
        return await _cohort_in_institution(db, course.cohort_id, user.institution_id)
    if user.role == "student":
        return course.cohort_id == user.cohort_id
    if user.role == "instructor":
        taught = await get_instructor_cohort_ids(db, user.id)
        return course.cohort_id in taught
    # tech_support or others: institution-wide read
    return await _cohort_in_institution(db, course.cohort_id, user.institution_id)


async def _can_write_course(db: AsyncSession, course: Course, user: User) -> bool:
    if user.role == "admin_ops":
        return await _cohort_in_institution(db, course.cohort_id, user.institution_id)
    return course.instructor_id == user.id


async def create_course(
    db: AsyncSession, data: CourseCreate, current_user: User
) -> CourseOut:
    if data.end_date < data.start_date:
        raise _validation("종료일은 시작일 이후여야 합니다.")

    if current_user.role == "admin_ops":
        if not await _cohort_in_institution(
            db, data.cohort_id, current_user.institution_id
        ):
            raise _forbidden()
    elif current_user.role == "instructor":
        taught = await get_instructor_cohort_ids(db, current_user.id)
        if data.cohort_id not in taught:
            raise _forbidden()
    else:
        raise _forbidden()

    # No instructor picker in MVP: instructor_id defaults to the current user
    # for both instructor and admin_ops.
    course = Course(
        cohort_id=data.cohort_id,
        instructor_id=current_user.id,
        title=data.title,
        description=data.description,
        start_date=data.start_date,
        end_date=data.end_date,
        status="active",
    )
    db.add(course)
    await db.commit()
    await db.refresh(course)
    return CourseOut.model_validate(course)


async def list_courses(
    db: AsyncSession,
    current_user: User,
    cohort_id: Optional[int] = None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[CourseOut], int]:
    query = select(Course)

    if current_user.role == "student":
        query = query.where(Course.cohort_id == current_user.cohort_id)
        if cohort_id and cohort_id != current_user.cohort_id:
            # student may only see their own cohort
            return [], 0
    elif current_user.role == "instructor":
        taught = await get_instructor_cohort_ids(db, current_user.id)
        if not taught:
            return [], 0
        if cohort_id:
            if cohort_id not in taught:
                return [], 0
            query = query.where(Course.cohort_id == cohort_id)
        else:
            query = query.where(Course.cohort_id.in_(taught))
    else:
        # admin_ops / tech_support: institution-wide
        query = query.join(Cohort, Course.cohort_id == Cohort.id).where(
            Cohort.institution_id == current_user.institution_id
        )
        if cohort_id:
            query = query.where(Course.cohort_id == cohort_id)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.order_by(Course.created_at.desc())
        .offset((page - 1) * size)
        .limit(size)
    )
    return [CourseOut.model_validate(c) for c in result.scalars().all()], total


async def _get_course_or_404(db: AsyncSession, course_id: int) -> Course:
    result = await db.execute(select(Course).where(Course.id == course_id))
    course = result.scalar_one_or_none()
    if course is None:
        raise _not_found()
    return course


async def get_course(
    db: AsyncSession, course_id: int, current_user: User
) -> CourseOut:
    course = await _get_course_or_404(db, course_id)
    if not await _can_read_course(db, course, current_user):
        raise _forbidden()
    return CourseOut.model_validate(course)


async def update_course(
    db: AsyncSession, course_id: int, data: CourseUpdate, current_user: User
) -> CourseOut:
    course = await _get_course_or_404(db, course_id)
    if not await _can_write_course(db, course, current_user):
        raise _forbidden()

    updates = data.model_dump(exclude_none=True)
    new_start = updates.get("start_date", course.start_date)
    new_end = updates.get("end_date", course.end_date)
    if new_start is not None and new_end is not None and new_end < new_start:
        raise _validation("종료일은 시작일 이후여야 합니다.")

    # Period changes keep existing videos (no deletion); out-of-range videos are
    # surfaced as "out of period" by the frontend.
    for field, value in updates.items():
        setattr(course, field, value)
    await db.commit()
    await db.refresh(course)
    return CourseOut.model_validate(course)


async def add_video(
    db: AsyncSession, course_id: int, data: CourseVideoCreate, current_user: User
) -> CourseVideoOut:
    course = await _get_course_or_404(db, course_id)
    if not await _can_write_course(db, course, current_user):
        raise _forbidden()

    if not (course.start_date <= data.class_date <= course.end_date):
        raise _validation("영상 날짜가 수업 기간을 벗어났습니다.")

    video = CourseVideo(
        course_id=course_id,
        class_date=data.class_date,
        title=data.title,
        file_key=data.file_key,
        original_filename=data.original_filename,
        content_type=data.content_type,
        size_bytes=data.size_bytes,
        duration_seconds=data.duration_seconds,
        sort_order=data.sort_order,
        uploaded_by=current_user.id,
        created_at=datetime.now(timezone.utc),
    )
    db.add(video)
    await db.commit()
    await db.refresh(video)
    return CourseVideoOut.model_validate(video)


async def list_videos(
    db: AsyncSession,
    course_id: int,
    current_user: User,
    from_date: Optional[date_type] = None,
    to_date: Optional[date_type] = None,
) -> list[CourseVideoOut]:
    course = await _get_course_or_404(db, course_id)
    if not await _can_read_course(db, course, current_user):
        raise _forbidden()

    query = select(CourseVideo).where(CourseVideo.course_id == course_id)
    if from_date:
        query = query.where(CourseVideo.class_date >= from_date)
    if to_date:
        query = query.where(CourseVideo.class_date <= to_date)
    query = query.order_by(CourseVideo.class_date, CourseVideo.sort_order)

    result = await db.execute(query)
    return [CourseVideoOut.model_validate(v) for v in result.scalars().all()]


async def delete_video(
    db: AsyncSession, course_id: int, video_id: int, current_user: User
) -> dict:
    course = await _get_course_or_404(db, course_id)
    if not await _can_write_course(db, course, current_user):
        raise _forbidden()

    result = await db.execute(
        select(CourseVideo).where(
            CourseVideo.id == video_id, CourseVideo.course_id == course_id
        )
    )
    video = result.scalar_one_or_none()
    if video is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "NOT_FOUND", "message": "영상을 찾을 수 없습니다."},
        )

    # TODO: also delete the S3/MinIO object via app.utils.s3.delete_object(video.file_key)
    # once object lifecycle cleanup is in scope (MVP keeps the object).
    await db.delete(video)
    await db.commit()
    return {"ok": True}


async def list_day_logs(
    db: AsyncSession,
    course_id: int,
    current_user: User,
    from_date: Optional[date_type] = None,
    to_date: Optional[date_type] = None,
) -> list[CourseDayLogOut]:
    course = await _get_course_or_404(db, course_id)
    if not await _can_read_course(db, course, current_user):
        raise _forbidden()

    query = select(CourseDayLog).where(CourseDayLog.course_id == course_id)
    if from_date:
        query = query.where(CourseDayLog.class_date >= from_date)
    if to_date:
        query = query.where(CourseDayLog.class_date <= to_date)
    query = query.order_by(CourseDayLog.class_date)

    result = await db.execute(query)
    return [CourseDayLogOut.model_validate(log) for log in result.scalars().all()]


async def get_day_log(
    db: AsyncSession,
    course_id: int,
    class_date: date_type,
    current_user: User,
) -> Optional[CourseDayLogOut]:
    course = await _get_course_or_404(db, course_id)
    if not await _can_read_course(db, course, current_user):
        raise _forbidden()

    result = await db.execute(
        select(CourseDayLog).where(
            CourseDayLog.course_id == course_id,
            CourseDayLog.class_date == class_date,
        )
    )
    log = result.scalar_one_or_none()
    if log is None:
        return None
    return CourseDayLogOut.model_validate(log)


async def upsert_day_log(
    db: AsyncSession,
    course_id: int,
    data: CourseDayLogUpsert,
    current_user: User,
) -> CourseDayLogOut:
    course = await _get_course_or_404(db, course_id)
    if not await _can_write_course(db, course, current_user):
        raise _forbidden()

    if not (course.start_date <= data.class_date <= course.end_date):
        raise _validation("일지 날짜가 수업 기간을 벗어났습니다.")

    result = await db.execute(
        select(CourseDayLog).where(
            CourseDayLog.course_id == course_id,
            CourseDayLog.class_date == data.class_date,
        )
    )
    log = result.scalar_one_or_none()
    if log is None:
        log = CourseDayLog(
            course_id=course_id,
            class_date=data.class_date,
            content=data.content,
            updated_by=current_user.id,
        )
        db.add(log)
    else:
        log.content = data.content
        log.updated_by = current_user.id

    await db.commit()
    await db.refresh(log)
    return CourseDayLogOut.model_validate(log)
