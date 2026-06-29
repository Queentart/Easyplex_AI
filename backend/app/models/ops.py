from sqlalchemy import Column, Integer, String, Text, DateTime
from sqlalchemy.sql import func
from app.db.base_class import Base

class OpsTicket(Base):
    """
    운영팀 채널을 통해 접수된 수강생의 문의/요청(Ticket)을 관리하는 모델입니다.
    """
    __tablename__ = "ops_tickets"

    id = Column(Integer, primary_key=True, index=True)
    student_name = Column(String(50), nullable=False) # 임시로 이름만 저장 (추후 JWT user_id 연동)
    message = Column(Text, nullable=False)            # 수강생이 보낸 문의 내용
    status = Column(String(20), default="pending")    # pending, answered, closed 등
    reply = Column(Text, nullable=True)               # 운영팀의 답변 내용
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    replied_at = Column(DateTime(timezone=True), nullable=True)
