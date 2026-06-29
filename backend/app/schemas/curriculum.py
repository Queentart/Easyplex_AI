from pydantic import BaseModel
from typing import Optional

class CurriculumStepBase(BaseModel):
    title: str
    status: str = "upcoming"  # 'completed', 'current', 'upcoming'
    progress: Optional[int] = None # 0~100
    completed_date: Optional[str] = None
    starts_date: Optional[str] = None
    display_order: int = 0

class CurriculumStepCreate(CurriculumStepBase):
    pass

class CurriculumStepUpdate(BaseModel):
    title: Optional[str] = None
    status: Optional[str] = None
    progress: Optional[int] = None
    completed_date: Optional[str] = None
    starts_date: Optional[str] = None
    display_order: Optional[int] = None

class CurriculumStepResponse(CurriculumStepBase):
    id: int

    class Config:
        from_attributes = True
