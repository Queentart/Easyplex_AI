from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.sql import func
from app.db.base_class import Base

class TechTicket(Base):
    """
    기술팀 채널을 통해 접수된 수강생의 기술지원 문의(Ticket) 모델입니다.
    """
    __tablename__ = "tech_tickets"

    id = Column(Integer, primary_key=True, index=True)
    student_name = Column(String(50), nullable=False)
    status = Column(String(20), default="open") # open, in_progress, resolved
    priority = Column(String(20), default="Medium") # Low, Medium, High
    issue_summary = Column(String(255), nullable=True) # First message summary
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

class TechMessage(Base):
    """
    기술지원 티켓에 속한 개별 채팅 메시지 모델입니다.
    """
    __tablename__ = "tech_messages"

    id = Column(Integer, primary_key=True, index=True)
    ticket_id = Column(Integer, ForeignKey("tech_tickets.id", ondelete="CASCADE"), nullable=False)
    sender_type = Column(String(20), nullable=False) # 'student' or 'admin'
    sender_name = Column(String(50), nullable=True)  # Name of the sender
    message = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
