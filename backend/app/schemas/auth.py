from __future__ import annotations

from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class TokenUserInfo(BaseModel):
    id: int
    email: str
    name: str
    role: str
    cohort_id: int | None
    cohort_ids: list[int] = []
    institution_id: int

    model_config = {"from_attributes": True}


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: TokenUserInfo


class MeResponse(BaseModel):
    id: int
    email: str
    name: str
    nickname: str | None
    role: str
    cohort_id: int | None
    cohort_ids: list[int] = []
    institution_id: int
    profile_image_url: str | None
    permissions: list[str]

    model_config = {"from_attributes": True}
