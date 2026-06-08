from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field


class AttendanceUpdate(BaseModel):
    type: str
    note: str = Field(min_length=1)


class AttendanceOut(BaseModel):
    id: int
    cohort_id: int
    user_id: int
    date: date
    check_in_at: Optional[datetime]
    check_out_at: Optional[datetime]
    type: str
    late_minutes: Optional[int]
    early_leave_minutes: Optional[int]
    import_source: str
    import_batch_id: Optional[str]
    linked_leave_request_id: Optional[int]
    note: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class AttendanceSummary(BaseModel):
    user_id: Optional[int]
    cohort_id: int
    total_days: int
    present: int
    late: int
    absent: int
    early_leave: int
    medical: int
    official: int
    computed_absent: int
    attendance_rate: float


class ImportRequest(BaseModel):
    file_key: str
    cohort_id: int
    dry_run: bool = False


class ImportResult(BaseModel):
    batch_id: str
    imported: int
    updated: int
    skipped: int
    preview: list[dict]


class ImportLogOut(BaseModel):
    id: int
    batch_id: str
    file_name: str
    cohort_id: int
    row_count: int
    success_count: int
    fail_count: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class NotifyRequest(BaseModel):
    cohort_id: int
    user_ids: list[int]
    message: str
