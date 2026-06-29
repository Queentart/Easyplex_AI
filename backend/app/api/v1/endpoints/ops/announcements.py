from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional
import os
import uuid
import shutil

from app.api.deps import get_db, get_current_user, require_role
from app.models.auth import User
from app.schemas.announcement import AnnouncementCreate, AnnouncementResponse, AnnouncementUpdate
from app.crud.crud_announcement import announcement as crud_announcement

router = APIRouter()

# TODO: require_role(['ops', 'admin']) 추가 가능

@router.get("/", response_model=List[AnnouncementResponse])
async def read_announcements(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    모든 공지사항 조회 (운영팀)
    """
    announcements = await crud_announcement.get_multi(db, skip=skip, limit=limit)
    return announcements

@router.post("/", response_model=AnnouncementResponse, status_code=status.HTTP_201_CREATED)
async def create_announcement(
    title: str = Form(...),
    content: str = Form(...),
    is_important: bool = Form(False),
    file: Optional[UploadFile] = File(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    새로운 공지사항 생성 (운영팀) - 첨부파일 지원
    """
    attachment_name = None
    attachment_url = None

    if file:
        # 파일 저장 디렉토리 (backend 디렉토리 내 uploads/announcements)
        base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))))
        upload_dir = os.path.join(base_dir, "uploads", "announcements")
        os.makedirs(upload_dir, exist_ok=True)
        
        # 안전한 파일명 생성 (확장자 유지)
        file_ext = os.path.splitext(file.filename)[1] if file.filename else ""
        unique_filename = f"{uuid.uuid4()}{file_ext}"
        file_path = os.path.join(upload_dir, unique_filename)
        
        # 파일 저장
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        attachment_name = file.filename
        # 프론트엔드에서 접근할 URL 경로
        attachment_url = f"/uploads/announcements/{unique_filename}"

    announcement_in = AnnouncementCreate(
        title=title,
        content=content,
        is_important=is_important,
        attachment_name=attachment_name,
        attachment_url=attachment_url
    )
    
    return await crud_announcement.create(db=db, obj_in=announcement_in, author_id=current_user.id)

@router.delete("/{announcement_id}", response_model=AnnouncementResponse)
async def delete_announcement(
    *,
    db: AsyncSession = Depends(get_db),
    announcement_id: int,
    current_user: User = Depends(get_current_user)
):
    """
    특정 공지사항 삭제 (운영팀)
    """
    obj = await crud_announcement.get(db=db, id=announcement_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Announcement not found")
    obj = await crud_announcement.delete(db=db, id=announcement_id)
    return obj
