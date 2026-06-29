from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean
from app.db.base_class import Base
from sqlalchemy.sql import func

class InstructorTicket(Base):
    """
    강사진(Instructor/Mentor) Q&A 채널을 통해 접수된 수강생의 문의/요청(Ticket)을 관리하는 모델입니다.
    """
    __tablename__ = "instructor_tickets"

    id = Column(Integer, primary_key=True, index=True)
    student_name = Column(String(50), nullable=False) # 임시로 이름만 저장 (추후 JWT user_id 연동)
    message = Column(Text, nullable=False)            # 수강생이 보낸 문의 내용
    status = Column(String(20), default="pending")    # pending, answered, closed 등
    reply = Column(Text, nullable=True)               # 강사진의 답변 내용
    replied_by = Column(String(50), nullable=True)    # 답변을 작성한 강사/멘토 이름
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    replied_at = Column(DateTime(timezone=True), nullable=True)

class CourseMaterial(Base):
    __tablename__ = "course_materials"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    file_name = Column(String(255), nullable=True)  # 원본 파일명
    file_type = Column(String(50), nullable=True)   # pdf, excel, powerpoint, image 등
    file_size = Column(Integer, nullable=True)      # 파일 크기(bytes)
    file_url = Column(String(500), nullable=False)
    uploaded_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

class TrainingLog(Base):
    """주강사용 훈련일지 (운영팀 연동)"""
    __tablename__ = "training_logs"

    id = Column(Integer, primary_key=True, index=True)
    instructor_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

class MentoringLog(Base):
    """멘토용 멘토링일지 (운영팀 연동)"""
    __tablename__ = "mentoring_logs"

    id = Column(Integer, primary_key=True, index=True)
    tutor_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    student_id = Column(Integer, ForeignKey("users.id"), nullable=True) # 특정 학생 대상일 경우
    date = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    receiver_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    message = Column(Text, nullable=False)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
