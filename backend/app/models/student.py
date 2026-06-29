import enum
from sqlalchemy import Column, Integer, String, ForeignKey, Enum
from sqlalchemy.orm import relationship
from app.db.base_class import Base

class StudentStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    ON_LEAVE = "ON_LEAVE"
    GRADUATED = "GRADUATED"
    DROPPED = "DROPPED"

class Student(Base):
    """
    수강생 상세 정보를 담는 모델입니다.
    User 테이블과 1:1 관계를 가집니다.
    """
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    
    student_number = Column(String(50), unique=True, index=True, nullable=False) # 학번
    grade = Column(String(50), nullable=True) # 학년/반 정보
    status = Column(Enum(StudentStatus), default=StudentStatus.ACTIVE, nullable=False)
    
    # 릴레이션 (SQLAlchemy ORM Navigation)
    # User 테이블과의 관계 설정은 필요시 추가
