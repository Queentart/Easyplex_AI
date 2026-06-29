from langchain_core.tools import tool
from langchain_ollama import OllamaEmbeddings
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

@tool
async def search_knowledge_base(query: str, k: int = 3) -> str:
    """
    PostgreSQL의 pgvector를 활용하여 EasyPlex 지식 베이스(매뉴얼, 교안, 정책 등)에서 
    사용자의 질문(query)과 의미론적으로 연관된 문서들을 검색하여 반환합니다.
    모르는 정보나 규정에 대한 질의가 들어오면 이 도구를 사용하세요.
    """
    try:
        # 1. 임베딩 모델 인스턴스화
        embeddings = OllamaEmbeddings(
            model=settings.LLM_EMBEDDING_MODEL,
            base_url=settings.OLLAMA_BASE_URL
        )
        
        # 실제 환경:
        # conn_str = settings.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")
        # vector_store = PGVector(connection_string=conn_str, embedding_function=embeddings, ...)
        # results = vector_store.similarity_search(query, k=k)
        
        # 현재는 인프라 파이프라인 검증용으로 Mock 반환.
        # 실제 문서를 밀어넣는 작업(Ingestion)이 완료된 후 위 주석을 해제합니다.
        
        mock_response = f"""
        [지식 베이스 검색 결과]
        검색어: '{query}'
        
        <문서 1>
        관련 내용이 임시 반환되었습니다. (현재 pgvector 통신 파이프라인 검증 모드입니다.)
        </문서 1>
        """
        return mock_response
        
    except Exception as e:
        logger.error(f"RAG 검색 중 오류 발생: {str(e)}")
        return "문서 검색에 실패했습니다. 기본 지식을 활용하여 답변해 주세요."
