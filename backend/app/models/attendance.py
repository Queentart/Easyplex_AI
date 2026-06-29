import enum
from datetime import date
from sqlalchemy import Column, Integer, ForeignKey, Date, Enum, String
from app.db.base_class import Base

class AttendanceStatus(str, enum.Enum):
    PRESENT = "PRESENT"
    LATE = "LATE"
    ABSENT = "ABSENT"
    EXCUSED = "EXCUSED"
    EARLY_LEAVE = "EARLY_LEAVE"

class Attendance(Base):
    """
    수강생의 일일 출결 기록을 관리하는 모델입니다.
    """
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True)
    
    attendance_date = Column(Date, default=date.today, nullable=False, index=True)
    status = Column(Enum(AttendanceStatus), default=AttendanceStatus.PRESENT, nullable=False)
    
    remarks = Column(String(255), nullable=True) # 비고 (예: 지각 사유)
