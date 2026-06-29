from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.api.deps import get_db, get_current_user
from app.models.auth import User
from app.schemas.announcement import AnnouncementResponse
from app.crud.crud_announcement import announcement as crud_announcement

router = APIRouter()

@router.get("/", response_model=List[AnnouncementResponse])
async def read_announcements(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    학생용 공지사항 리스트 조회
    """
    announcements = await crud_announcement.get_multi(db, skip=skip, limit=limit)
    return announcements
