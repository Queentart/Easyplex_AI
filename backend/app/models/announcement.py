from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base_class import Base

class Announcement(Base):
    __tablename__ = "announcements"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    is_important = Column(Boolean, default=False)
    attachment_name = Column(String(255), nullable=True) # 파일명
    attachment_url = Column(String(500), nullable=True)  # 다운로드 URL
    author_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 릴레이션 (User 모델은 app.models.auth에 존재한다고 가정)
    author = relationship("User", foreign_keys=[author_id])
