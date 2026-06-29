from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime, Float
from sqlalchemy.dialects.postgresql import ARRAY
from app.db.base_class import Base

class AssignmentTask(Base):
    """
    강사가 등록한 과제 정보를 담는 모델입니다.
    """
    __tablename__ = "assignment_tasks"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=False)
    deadline = Column(DateTime(timezone=True), nullable=True)
    created_by_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class Assignment(Base):
    """
    학생이 제출한 과제 기본 정보를 담는 모델입니다.
    """
    __tablename__ = "assignments"

    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("assignment_tasks.id", ondelete="CASCADE"), nullable=False, index=True)
    student_id = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True)
    
    title = Column(String(255), nullable=True) # 제출된 과제물 제목 (optional but kept for backwards compat)
    content = Column(Text, nullable=True)
    status = Column(String(50), default="submitted") # submitted, graded
    
    # 파일 업로드 지원
    file_url = Column(String(500), nullable=True)
    file_name = Column(String(255), nullable=True)
    file_type = Column(String(50), nullable=True)
    file_size = Column(Integer, nullable=True)
    
    submitted_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    
    # AI 자동 채점 및 피드백 (LLM 파이프라인 결과)
    ai_score = Column(Float, nullable=True)
    ai_confidence = Column(String(50), nullable=True) # High, Low
    ai_feedback = Column(Text, nullable=True)
    
    # 강사 최종 확정 점수
    final_score = Column(Float, nullable=True)
    final_feedback = Column(Text, nullable=True)

class AssignmentVector(Base):
    """
    과제 내용의 벡터 임베딩을 저장하는 모델입니다.
    의미론적 검색(유사도 기반 표절 검사, 주제 분석 등)에 사용됩니다.
    1536 차원은 OpenAI의 text-embedding-3-small 등 최신 임베딩 모델의 기본 차원입니다.
    """
    __tablename__ = "assignment_vectors"

    id = Column(Integer, primary_key=True, index=True)
    assignment_id = Column(Integer, ForeignKey("assignments.id", ondelete="CASCADE"), unique=True, nullable=False)
    
    # 로컬 Windows 환경에서 pgvector 확장이 없는 경우를 대비하여 기본 ARRAY(Float)로 대체
    embedding = Column(ARRAY(Float), nullable=False)
