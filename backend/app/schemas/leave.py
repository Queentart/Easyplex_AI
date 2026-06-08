from __future__ import annotations

from datetime import date, datetime, time
from typing import Optional

from pydantic import BaseModel, Field


class LeaveRequestCreate(BaseModel):
    type: str
    target_date: date
    start_time: Optional[time] = None
    reason: str = Field(min_length=1)
    student_id: Optional[int] = None
    evidence_key: Optional[str] = None
    evidence_name: Optional[str] = None
    evidence_size: Optional[int] = None


class ReviewRequest(BaseModel):
    review_comment: str = Field(min_length=1)


class LeaveBalanceOut(BaseModel):
    allowance_days: Optional[int]  # cohort's configured allowance; None = not set
    used_days: int  # count of this student's approved leave requests
    remaining_days: Optional[int]  # max(0, allowance - used); None when no allowance
    has_allowance: bool  # whether the cohort has a configured allowance


class LeaveRequestOut(BaseModel):
    id: int
    cohort_id: int
    student_id: int
    type: str
    target_date: date
    start_time: Optional[time]
    reason: str
    status: str
    reviewed_by: Optional[int]
    reviewed_at: Optional[datetime]
    review_comment: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}
