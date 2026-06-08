from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AssignmentCreate(BaseModel):
    cohort_id: int
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(min_length=1)
    due_date: datetime
    allow_late_submission: bool = False
    max_score: Optional[int] = None
    attachments: list[dict] = []


class AssignmentUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = None
    due_date: Optional[datetime] = None
    allow_late_submission: Optional[bool] = None
    max_score: Optional[int] = None
    status: Optional[str] = None


class AssignmentOut(BaseModel):
    id: int
    cohort_id: int
    created_by: int
    title: str
    description: str
    due_date: datetime
    allow_late_submission: bool
    max_score: Optional[int]
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class SubmissionCreate(BaseModel):
    content: Optional[str] = None
    file_key: Optional[str] = None
    file_name: Optional[str] = None
    file_size: Optional[int] = None
    mime_type: Optional[str] = None


class FeedbackRequest(BaseModel):
    score: Optional[int] = None
    feedback: str
    status: str = "reviewed"


class SubmissionOut(BaseModel):
    id: int
    assignment_id: int
    student_id: int
    content: Optional[str]
    submitted_at: datetime
    is_late: bool
    score: Optional[int]
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class SubmissionListItem(BaseModel):
    id: int
    student_id: int
    student_name: Optional[str]
    submitted_at: datetime
    is_late: bool
    score: Optional[int]
    status: str

    model_config = {"from_attributes": True}
