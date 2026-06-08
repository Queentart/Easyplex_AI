from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field


class InquiryCreate(BaseModel):
    type: str
    title: str = Field(min_length=1, max_length=200)
    content: str = Field(min_length=1)
    priority: str = "normal"
    attachments: list[dict] = []


class InquiryUpdate(BaseModel):
    status: Optional[str] = None
    assigned_to: Optional[int] = None
    priority: Optional[str] = None


class InquiryMessageCreate(BaseModel):
    content: str = Field(min_length=1)
    attachments: list[dict] = []


class InquiryOut(BaseModel):
    id: int
    cohort_id: Optional[int]
    author_id: int
    type: str
    title: str
    content: str
    attachments: list
    status: str
    priority: str
    assigned_to: Optional[int]
    resolved_at: Optional[datetime]
    created_at: datetime

    model_config = {"from_attributes": True}


class InquiryMessageOut(BaseModel):
    id: int
    inquiry_id: int
    sender_id: int
    content: str
    attachments: list
    read_at: Optional[datetime]
    created_at: datetime

    model_config = {"from_attributes": True}


class LicenseCreate(BaseModel):
    service_name: str = Field(min_length=1, max_length=100)
    license_key: str = Field(min_length=1)
    issued_at: Optional[date] = None
    expires_at: Optional[date] = None
    seat_count: Optional[int] = None
    notes: Optional[str] = None


class LicenseOut(BaseModel):
    id: int
    institution_id: int
    service_name: str
    issued_at: Optional[date]
    expires_at: Optional[date]
    seat_count: Optional[int]
    status: str
    notes: Optional[str]
    last_accessed_at: Optional[datetime]
    created_at: datetime

    model_config = {"from_attributes": True}


class LicenseWithKey(LicenseOut):
    license_key: str
