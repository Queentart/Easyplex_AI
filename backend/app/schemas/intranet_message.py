from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel
from app.models.auth import UserRole

class IntranetMessageBase(BaseModel):
    receiver_role: UserRole
    content: str
    cohort_name: Optional[str] = None

class IntranetMessageCreate(IntranetMessageBase):
    pass

class IntranetMessageOut(IntranetMessageBase):
    id: int
    sender_id: int
    sender_name: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True
