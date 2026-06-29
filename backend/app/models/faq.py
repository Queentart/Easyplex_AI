from sqlalchemy import Column, Integer, String, Text, JSON
from app.db.base_class import Base

class FAQItem(Base):
    """
    RAG용 FAQ 모델.
    추후 pgvector의 Vector 타입으로 embedding 컬럼을 마이그레이션 할 수 있도록 JSON으로 임시 구성합니다.
    """
    __tablename__ = "faqs"

    id = Column(Integer, primary_key=True, index=True)
    category = Column(String(50), index=True, nullable=False, default="general")
    question = Column(String(255), nullable=False)
    answer = Column(Text, nullable=False)
    
    # 향후 pgvector.sqlalchemy.Vector 타입으로 변경 권장
    embedding = Column(JSON, nullable=True, comment="RAG를 위한 벡터 데이터 플레이스홀더 (Array of floats)")
