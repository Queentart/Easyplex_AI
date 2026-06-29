from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.announcement import Announcement
from app.schemas.announcement import AnnouncementCreate, AnnouncementUpdate

class CRUDAnnouncement:
    async def get(self, db: AsyncSession, id: int) -> Optional[Announcement]:
        result = await db.execute(select(Announcement).filter(Announcement.id == id))
        return result.scalars().first()

    async def get_multi(self, db: AsyncSession, skip: int = 0, limit: int = 100) -> List[Announcement]:
        result = await db.execute(select(Announcement).order_by(Announcement.created_at.desc()).offset(skip).limit(limit))
        return list(result.scalars().all())

    async def create(self, db: AsyncSession, obj_in: AnnouncementCreate, author_id: int) -> Announcement:
        db_obj = Announcement(
            title=obj_in.title,
            content=obj_in.content,
            is_important=obj_in.is_important,
            attachment_name=obj_in.attachment_name,
            attachment_url=obj_in.attachment_url,
            author_id=author_id
        )
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)
        return db_obj

    async def update(self, db: AsyncSession, db_obj: Announcement, obj_in: AnnouncementUpdate) -> Announcement:
        update_data = obj_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)
        return db_obj

    async def delete(self, db: AsyncSession, id: int) -> Announcement:
        result = await db.execute(select(Announcement).filter(Announcement.id == id))
        obj = result.scalars().first()
        if obj:
            await db.delete(obj)
            await db.commit()
        return obj

announcement = CRUDAnnouncement()
