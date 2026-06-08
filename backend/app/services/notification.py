from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification
from app.schemas.notification import NotificationOut


async def list_notifications(
    db: AsyncSession,
    user_id: int,
    is_read: Optional[bool] = None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[NotificationOut], int, int]:
    query = select(Notification).where(Notification.user_id == user_id)
    if is_read is not None:
        query = query.where(Notification.is_read == is_read)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    unread_result = await db.execute(
        select(func.count()).where(
            Notification.user_id == user_id, Notification.is_read == False
        )
    )
    unread_count = unread_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(Notification.created_at.desc())
    )
    notifications = result.scalars().all()
    return [NotificationOut.model_validate(n) for n in notifications], total, unread_count


async def mark_read(
    db: AsyncSession, notification_id: int, user_id: int
) -> NotificationOut:
    result = await db.execute(
        select(Notification).where(
            Notification.id == notification_id, Notification.user_id == user_id
        )
    )
    notification = result.scalar_one_or_none()
    if notification is None:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "알림을 찾을 수 없습니다."})

    notification.is_read = True
    notification.read_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(notification)
    return NotificationOut.model_validate(notification)


async def mark_all_read(db: AsyncSession, user_id: int) -> int:
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(func.count()).where(
            Notification.user_id == user_id, Notification.is_read == False
        )
    )
    count = result.scalar_one()

    await db.execute(
        update(Notification)
        .where(Notification.user_id == user_id, Notification.is_read == False)
        .values(is_read=True, read_at=now)
    )
    await db.commit()
    return count


async def create_notification(
    db: AsyncSession,
    user_id: int,
    notification_type: str,
    title: str,
    content: Optional[str] = None,
    link_url: Optional[str] = None,
    related_entity_type: Optional[str] = None,
    related_entity_id: Optional[int] = None,
) -> None:
    notification = Notification(
        user_id=user_id,
        type=notification_type,
        title=title,
        content=content,
        link_url=link_url,
        related_entity_type=related_entity_type,
        related_entity_id=related_entity_id,
        sent_channels=["in_app"],
    )
    db.add(notification)
    await db.commit()
