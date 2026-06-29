import enum
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey, Enum
from app.db.base_class import Base

class NotificationType(str, enum.Enum):
    WARNING = "warning"
    INFO = "info"
    SUCCESS = "success"
    MESSAGE = "message"
    ALERT = "alert"

class Notification(Base):
    """
    사용자에게 전송되는 알림 정보를 저장하는 모델입니다.
    """
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    type = Column(Enum(NotificationType), default=NotificationType.INFO, nullable=False)
    
    is_read = Column(Boolean, default=False, nullable=False)
    link = Column(String(500), nullable=True) # 알림 클릭 시 이동할 URL
    
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
