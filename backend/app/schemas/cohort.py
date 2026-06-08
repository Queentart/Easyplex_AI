from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field


class CohortCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    code: str = Field(min_length=1, max_length=30)
    start_date: date
    end_date: date
    total_hours: Optional[int] = None
    leave_allowance_days: Optional[int] = Field(None, ge=0)
    description: Optional[str] = None


class CohortUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    total_hours: Optional[int] = None
    leave_allowance_days: Optional[int] = Field(None, ge=0)
    description: Optional[str] = None
    status: Optional[str] = None


class CohortOut(BaseModel):
    id: int
    institution_id: int
    name: str
    code: str
    start_date: date
    end_date: date
    total_hours: Optional[int]
    leave_allowance_days: Optional[int]
    description: Optional[str]
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class CohortDetail(CohortOut):
    student_count: int = 0
    instructor_count: int = 0


class MembersAddRequest(BaseModel):
    user_ids: list[int]
    role: str


class MembersAddResult(BaseModel):
    added: int
    skipped: int
