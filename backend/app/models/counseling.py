from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy import Float
from app.db.base_class import Base

class CounselingLog(Base):
    """
    학생 상담 기록(대화 내역, 봇 채팅 로그 포함)을 저장하는 모델입니다.
    """
    __tablename__ = "counseling_logs"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # 사람이 상담한 경우 counselor_id에 해당 관리자의 user_id가 들어갑니다.
    # AI HelpBot이 상담한 경우 null이 될 수 있습니다.
    counselor_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    topic = Column(String(255), nullable=True)
    notes = Column(Text, nullable=False) # 상담 내용 또는 채팅 로그
    
    # 상담 기록을 RAG 기반 AI에 활용하기 위한 벡터 컬럼 (로컬 환경 호환용 ARRAY)
    embedding = Column(ARRAY(Float), nullable=True)
    
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
