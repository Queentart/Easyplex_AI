from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class NotificationOut(BaseModel):
    id: int
    user_id: int
    type: str
    title: str
    content: Optional[str]
    link_url: Optional[str]
    related_entity_type: Optional[str]
    related_entity_id: Optional[int]
    is_read: bool
    read_at: Optional[datetime]
    sent_channels: list
    created_at: datetime

    model_config = {"from_attributes": True}
