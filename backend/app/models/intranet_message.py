from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Enum
from sqlalchemy.orm import relationship
from app.db.base_class import Base
from app.models.auth import UserRole

class IntranetMessage(Base):
    """
    사내 인트라넷용 메세지 모델.
    주강사, 멘토, 운영팀, 기술팀, 오너 간의 메세징에 사용됩니다.
    수신자는 특정 사용자가 아닌 권한(Role) 그룹을 대상으로 합니다.
    """
    __tablename__ = "intranet_messages"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    receiver_role = Column(Enum(UserRole), nullable=False)
    content = Column(Text, nullable=False)
    cohort_name = Column(String(255), nullable=True) # 관련된 기수 정보
    
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    deleted_at = Column(DateTime(timezone=True), nullable=True) # 기수 종료 1개월 후 등 soft delete에 사용

    sender = relationship("User", foreign_keys=[sender_id])

    def __repr__(self):
        return f"<IntranetMessage from User {self.sender_id} to Role {self.receiver_role.value}>"
