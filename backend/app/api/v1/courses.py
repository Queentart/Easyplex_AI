from datetime import date
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_roles
from app.models.auth import User
from app.schemas.common import ok, paginated
from app.schemas.course import (
    CourseCreate,
    CourseDayLogUpsert,
    CourseUpdate,
    CourseVideoCreate,
)
from app.services import course as course_service

router = APIRouter(prefix="/courses", tags=["courses"])


@router.post("/", response_model=dict)
async def create_course(
    body: CourseCreate,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    course = await course_service.create_course(db, body, current_user)
    return ok(course.model_dump())


@router.get("/", response_model=dict)
async def list_courses(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    cohort_id: Optional[int] = None,
    page: int = 1,
    size: int = 20,
):
    courses, total = await course_service.list_courses(
        db, current_user, cohort_id=cohort_id, page=page, size=size
    )
    return paginated([c.model_dump() for c in courses], page, size, total)


@router.get("/{course_id}", response_model=dict)
async def get_course(
    course_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    course = await course_service.get_course(db, course_id, current_user)
    return ok(course.model_dump())


@router.patch("/{course_id}", response_model=dict)
async def update_course(
    course_id: int,
    body: CourseUpdate,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    course = await course_service.update_course(db, course_id, body, current_user)
    return ok(course.model_dump())


@router.post("/{course_id}/videos", response_model=dict)
async def add_video(
    course_id: int,
    body: CourseVideoCreate,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    video = await course_service.add_video(db, course_id, body, current_user)
    return ok(video.model_dump())


@router.get("/{course_id}/videos", response_model=dict)
async def list_videos(
    course_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    from_: Optional[date] = Query(default=None, alias="from"),
    to: Optional[date] = None,
):
    videos = await course_service.list_videos(
        db, course_id, current_user, from_date=from_, to_date=to
    )
    return ok([v.model_dump() for v in videos])


@router.delete("/{course_id}/videos/{video_id}", response_model=dict)
async def delete_video(
    course_id: int,
    video_id: int,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await course_service.delete_video(db, course_id, video_id, current_user)
    return ok(result)


@router.get("/{course_id}/day-logs", response_model=dict)
async def list_day_logs(
    course_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    from_: Optional[date] = Query(default=None, alias="from"),
    to: Optional[date] = None,
):
    logs = await course_service.list_day_logs(
        db, course_id, current_user, from_date=from_, to_date=to
    )
    return ok([log.model_dump() for log in logs])


@router.get("/{course_id}/day-logs/{class_date}", response_model=dict)
async def get_day_log(
    course_id: int,
    class_date: date,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    log = await course_service.get_day_log(db, course_id, class_date, current_user)
    return ok(log.model_dump() if log is not None else None)


@router.put("/{course_id}/day-logs", response_model=dict)
async def upsert_day_log(
    course_id: int,
    body: CourseDayLogUpsert,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    log = await course_service.upsert_day_log(db, course_id, body, current_user)
    return ok(log.model_dump())
