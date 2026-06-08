from typing import Annotated, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_roles
from app.models.auth import User
from app.schemas.inquiry import InquiryCreate, InquiryMessageCreate, InquiryUpdate
from app.schemas.common import ok, paginated
from app.services import inquiry as inquiry_service

router = APIRouter(prefix="/inquiries", tags=["inquiries"])


@router.get("/", response_model=dict)
async def list_inquiries(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    status: Optional[str] = None,
    type: Optional[str] = None,
    priority: Optional[str] = None,
    assigned_to_me: bool = False,
    page: int = 1,
    size: int = 20,
):
    inquiries, total = await inquiry_service.list_inquiries(
        db, current_user, status=status, type_filter=type, priority=priority,
        assigned_to_me=assigned_to_me, page=page, size=size,
    )
    return paginated([i.model_dump() for i in inquiries], page, size, total)


@router.post("/", response_model=dict)
async def create_inquiry(
    body: InquiryCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    inquiry = await inquiry_service.create_inquiry(db, body, current_user)
    return ok(inquiry.model_dump())


@router.get("/{inquiry_id}", response_model=dict)
async def get_inquiry(
    inquiry_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    inquiry = await inquiry_service.get_inquiry(db, inquiry_id, current_user)
    return ok(inquiry.model_dump())


@router.patch("/{inquiry_id}", response_model=dict)
async def update_inquiry(
    inquiry_id: int,
    body: InquiryUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    inquiry = await inquiry_service.update_inquiry(db, inquiry_id, body, current_user)
    return ok(inquiry.model_dump())


@router.get("/{inquiry_id}/messages", response_model=dict)
async def list_messages(
    inquiry_id: int,
    _: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    page: int = 1,
    size: int = 50,
):
    messages, total = await inquiry_service.list_messages(db, inquiry_id, page, size)
    return paginated([m.model_dump() for m in messages], page, size, total)


@router.post("/{inquiry_id}/messages", response_model=dict)
async def add_message(
    inquiry_id: int,
    body: InquiryMessageCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    message = await inquiry_service.add_message(db, inquiry_id, body, current_user)
    return ok(message.model_dump())


@router.post("/{inquiry_id}/close", response_model=dict)
async def close_inquiry(
    inquiry_id: int,
    _: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    inquiry = await inquiry_service.close_inquiry(db, inquiry_id)
    return ok(inquiry.model_dump())
