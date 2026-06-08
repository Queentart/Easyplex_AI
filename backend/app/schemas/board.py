from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class BoardCreate(BaseModel):
    cohort_id: Optional[int] = None
    name: str = Field(min_length=1, max_length=100)
    type: str
    description: Optional[str] = None
    allow_anonymous: bool = False
    allow_private_post: bool = False
    visibility: str = "cohort"


class BoardUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = None
    allow_anonymous: Optional[bool] = None
    allow_private_post: Optional[bool] = None
    visibility: Optional[str] = None
    sort_order: Optional[int] = None


class BoardOut(BaseModel):
    id: int
    cohort_id: Optional[int]
    name: str
    type: str
    description: Optional[str]
    allow_anonymous: bool
    allow_private_post: bool
    visibility: str
    created_by: int
    is_active: bool
    sort_order: int
    created_at: datetime

    model_config = {"from_attributes": True}


class PostCreate(BaseModel):
    board_id: int
    title: str = Field(min_length=1, max_length=200)
    content: str = Field(min_length=1)
    is_anonymous: bool = False
    is_private: bool = False
    attachments: list[dict] = []


class PostUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    content: Optional[str] = None
    attachments: Optional[list[dict]] = None


class PostOut(BaseModel):
    id: int
    board_id: int
    author_id: int
    title: str
    content: str
    is_anonymous: bool
    is_private: bool
    is_pinned: bool
    view_count: int
    attachments: list
    deleted_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class CommentCreate(BaseModel):
    content: str = Field(min_length=1)
    parent_comment_id: Optional[int] = None
    is_anonymous: bool = False


class CommentUpdate(BaseModel):
    content: str = Field(min_length=1)


class CommentOut(BaseModel):
    id: int
    post_id: Optional[int]
    submission_id: Optional[int]
    author_id: int
    parent_comment_id: Optional[int]
    content: str
    is_anonymous: bool
    deleted_at: Optional[datetime]
    created_at: datetime

    model_config = {"from_attributes": True}


class PinRequest(BaseModel):
    pinned: bool


class AuthorIdentityOut(BaseModel):
    author_id: int
    author_name: str
    created_at: datetime
