from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime

class AnnouncementBase(BaseModel):
    title: str
    content: str
    is_important: Optional[bool] = False
    attachment_name: Optional[str] = None
    attachment_url: Optional[str] = None

class AnnouncementCreate(AnnouncementBase):
    pass

class AnnouncementUpdate(AnnouncementBase):
    title: Optional[str] = None
    content: Optional[str] = None
    is_important: Optional[bool] = None
    attachment_name: Optional[str] = None
    attachment_url: Optional[str] = None

class AnnouncementResponse(AnnouncementBase):
    id: int
    author_id: Optional[int]
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
