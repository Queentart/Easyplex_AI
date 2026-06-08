from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=50)
    role: str
    cohort_id: Optional[int] = None
    phone: Optional[str] = None
    send_invitation: bool = False


class UserUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=50)
    nickname: Optional[str] = Field(None, max_length=50)
    phone: Optional[str] = None
    profile_image_url: Optional[str] = None
    birth_date: Optional[date] = None
    gender: Optional[str] = None


class UserRoleUpdate(BaseModel):
    role: str
    cohort_id: Optional[int] = None


class UserOut(BaseModel):
    id: int
    institution_id: int
    cohort_id: Optional[int]
    email: str
    name: str
    nickname: Optional[str]
    phone: Optional[str]
    role: str
    profile_image_url: Optional[str]
    birth_date: Optional[date]
    gender: Optional[str]
    is_active: bool
    last_login_at: Optional[datetime]
    created_at: datetime

    model_config = {"from_attributes": True}


class UserListItem(BaseModel):
    id: int
    email: str
    name: str
    role: str
    cohort_id: Optional[int]
    is_active: bool

    model_config = {"from_attributes": True}


class BulkImportResult(BaseModel):
    imported: int
    failed: int
    errors: list[dict]


class PasswordResetResult(BaseModel):
    temporary_password: Optional[str] = None
    email_sent: bool = False
