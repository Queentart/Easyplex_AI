from __future__ import annotations

from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field


class CourseCreate(BaseModel):
    cohort_id: int
    title: str = Field(min_length=1, max_length=200)
    description: Optional[str] = None
    start_date: date
    end_date: date


class CourseUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=200)
    description: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    status: Optional[Literal["active", "archived"]] = None


class CourseOut(BaseModel):
    id: int
    cohort_id: int
    instructor_id: int
    title: str
    description: Optional[str]
    start_date: date
    end_date: date
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class CourseVideoCreate(BaseModel):
    class_date: date
    file_key: str
    title: Optional[str] = None
    original_filename: Optional[str] = None
    content_type: Optional[str] = None
    size_bytes: Optional[int] = None
    duration_seconds: Optional[int] = None
    sort_order: int = 0


class CourseVideoOut(BaseModel):
    id: int
    course_id: int
    class_date: date
    title: Optional[str]
    file_key: str
    original_filename: Optional[str]
    content_type: Optional[str]
    size_bytes: Optional[int]
    duration_seconds: Optional[int]
    sort_order: int
    uploaded_by: int
    created_at: datetime

    model_config = {"from_attributes": True}


class CourseDayLogUpsert(BaseModel):
    class_date: date
    content: str


class CourseDayLogOut(BaseModel):
    id: int
    course_id: int
    class_date: date
    content: str
    updated_by: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
