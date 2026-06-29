from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.sql import func
from app.db.base_class import Base

class CurriculumStep(Base):
    """
    학습 커리큘럼 로드맵 항목을 나타내는 모델입니다.
    """
    __tablename__ = "curriculum_steps"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    status = Column(String(50), nullable=False, default="upcoming") # 'completed', 'current', 'upcoming'
    progress = Column(Integer, nullable=True) # 0 to 100
    completed_date = Column(String(50), nullable=True)
    starts_date = Column(String(50), nullable=True)
    display_order = Column(Integer, nullable=False, default=0)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
