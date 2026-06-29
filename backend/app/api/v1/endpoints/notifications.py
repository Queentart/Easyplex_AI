from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime

from app.api.deps import get_db, get_current_user
from app.models.auth import User
from app.models.notification import Notification, NotificationType
from app.services.notification_service import create_notification

router = APIRouter()

# --- Pydantic Schemas ---

class NotificationResponse(BaseModel):
    id: int
    title: str
    message: str
    type: str
    is_read: bool
    link: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

# --- API Endpoints ---

@router.get("", response_model=List[NotificationResponse])
async def get_notifications(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """현재 로그인한 사용자의 모든 알림을 최신순으로 가져옵니다."""
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
    )
    notifications = result.scalars().all()
    return notifications

@router.post("/{notification_id}/read")
async def mark_notification_read(
    notification_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """특정 알림을 읽음 처리합니다."""
    result = await db.execute(
        select(Notification)
        .where(Notification.id == notification_id)
        .where(Notification.user_id == current_user.id)
    )
    notification = result.scalars().first()
    
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
        
    notification.is_read = True
    await db.commit()
    return {"message": "Notification marked as read"}

@router.post("/read-all")
async def mark_all_notifications_read(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """모든 알림을 일괄 읽음 처리합니다."""
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .where(Notification.is_read == False)
    )
    unread_notifications = result.scalars().all()
    
    for n in unread_notifications:
        n.is_read = True
        
    await db.commit()
    return {"message": f"{len(unread_notifications)} notifications marked as read"}

@router.post("/test", status_code=201)
async def create_test_notification(
    title: str,
    message: str,
    type: str = "info",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """테스트 목적으로 현재 사용자에게 임의의 알림을 발송합니다."""
    # Enum 검증
    try:
        notif_type = NotificationType(type)
    except ValueError:
        notif_type = NotificationType.INFO

    notification = await create_notification(
        db=db,
        user_id=current_user.id,
        title=title,
        message=message,
        type=notif_type,
        link="/notifications"
    )
    
    return {"message": "Test notification created", "id": notification.id}
