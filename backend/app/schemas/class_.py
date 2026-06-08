from __future__ import annotations

from datetime import date, datetime, time
from typing import Optional

from pydantic import BaseModel, Field


class ClassCreate(BaseModel):
    cohort_id: int
    instructor_id: int
    title: str = Field(min_length=1, max_length=200)
    date: date
    start_time: time
    end_time: time
    location: Optional[str] = None
    materials: list[dict] = []


class ClassUpdate(BaseModel):
    title: Optional[str] = None
    date: Optional[date] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    location: Optional[str] = None
    materials: Optional[list[dict]] = None
    status: Optional[str] = None


class ClassOut(BaseModel):
    id: int
    cohort_id: int
    instructor_id: int
    title: str
    date: date
    start_time: time
    end_time: time
    location: Optional[str]
    materials: list
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class RecordingCreate(BaseModel):
    file_key: str
    title: Optional[str] = None
    duration_seconds: Optional[int] = None


class TrainingLogCreate(BaseModel):
    content: str = Field(min_length=1)
    achievements: Optional[str] = None
    next_plan: Optional[str] = None
    attendance_summary: Optional[dict] = None


class TrainingLogUpdate(BaseModel):
    content: Optional[str] = None
    achievements: Optional[str] = None
    next_plan: Optional[str] = None


class TrainingLogOut(BaseModel):
    id: int
    class_id: int
    instructor_id: int
    content: str
    achievements: Optional[str]
    next_plan: Optional[str]
    attendance_summary: Optional[dict]
    submitted_at: datetime
    created_at: datetime

    model_config = {"from_attributes": True}


class MentoringLogCreate(BaseModel):
    student_id: int
    session_date: date
    content: str = Field(min_length=1)
    follow_up: Optional[str] = None
    cohort_id: Optional[int] = None


class MentoringLogOut(BaseModel):
    id: int
    cohort_id: int
    instructor_id: int
    student_id: int
    session_date: date
    content: str
    follow_up: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class EvaluationCreate(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: Optional[str] = None
    is_anonymous: bool = True


class EvaluationSummary(BaseModel):
    average: float
    count: int
    distribution: dict[str, int]
    comments: list[str]


class CurriculumItemCreate(BaseModel):
    week: int
    day: Optional[int] = None
    topic: str = Field(min_length=1, max_length=200)
    description: Optional[str] = None
    planned_hours: Optional[int] = None
    parent_item_id: Optional[int] = None
    sort_order: int = 0


class CurriculumItemUpdate(BaseModel):
    topic: Optional[str] = None
    is_completed: Optional[bool] = None
    actual_hours: Optional[int] = None
    sort_order: Optional[int] = None


class CurriculumItemOut(BaseModel):
    id: int
    cohort_id: int
    week: int
    day: Optional[int]
    topic: str
    description: Optional[str]
    planned_hours: Optional[int]
    actual_hours: Optional[int]
    is_completed: bool
    completed_at: Optional[datetime]
    parent_item_id: Optional[int]
    sort_order: int
    created_at: datetime

    model_config = {"from_attributes": True}


class CareerPostingCreate(BaseModel):
    posting_type: str
    title: str = Field(min_length=1, max_length=200)
    content: str = Field(min_length=1)
    external_url: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    target_cohort_ids: Optional[list[int]] = None
    attachments: list[dict] = []


class CareerPostingOut(BaseModel):
    id: int
    institution_id: int
    posting_type: str
    title: str
    content: str
    external_url: Optional[str]
    start_date: Optional[date]
    end_date: Optional[date]
    target_cohort_ids: Optional[list]
    attachments: list
    created_by: int
    created_at: datetime

    model_config = {"from_attributes": True}
