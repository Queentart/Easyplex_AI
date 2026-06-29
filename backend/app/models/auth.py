import enum
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum
from app.db.base_class import Base

class UserRole(str, enum.Enum):
    STUDENT = "STUDENT"
    INSTRUCTOR = "INSTRUCTOR"
    TUTOR = "TUTOR"
    EDUOPS = "EDUOPS"
    TECHOPS = "TECHOPS"
    OWNER = "OWNER"

class User(Base):
    """
    플랫폼에 접근하는 모든 사용자의 기본 인증 모델입니다.
    수강생과 관리자(강사, 운영팀, 원장 등)를 포괄합니다.
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    role = Column(Enum(UserRole), default=UserRole.STUDENT, nullable=False)
    
    full_name = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True)
    
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    def __repr__(self):
        return f"<User {self.email} ({self.role})>"