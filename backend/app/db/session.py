import sys
import logging
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import text

from app.core.config import settings

# 로거 설정
logger = logging.getLogger(__name__)

# 비동기 엔진 생성
try:
    engine = create_async_engine(
        settings.DATABASE_URL,
        echo=False,  # SQL 로깅이 필요하면 True로 변경
        pool_pre_ping=True, # 연결이 끊어졌는지 확인
    )
except Exception as e:
    logger.error(f"데이터베이스 엔진 생성 실패: {e}")
    sys.exit(1)

# 비동기 세션 팩토리 생성
# 세션을 요청할 때마다 새 트랜잭션을 엽니다.
SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)

async def check_database_connection():
    """데이터베이스 연결 상태를 확인하고, pgvector 확장을 설치(활성화)합니다."""
    try:
        async with engine.begin() as conn:
            # 기본 연결 테스트
            await conn.execute(text("SELECT 1"))
            # pgvector 확장은 슈퍼유저 권한이 필요할 수 있습니다. 
            # 벡터 데이터를 담는 주 DB이므로 서버 구동 시 활성화를 시도합니다.
            try:
                await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector;"))
                logger.info("pgvector 확장이 성공적으로 확인/활성화되었습니다.")
            except Exception as vector_err:
                logger.warning(f"pgvector 확장 활성화 중 경고 발생 (슈퍼유저 권한 필요할 수 있음): {vector_err}")
                
        logger.info("데이터베이스 연결 성공 및 초기화 완료.")
        return True
    except Exception as e:
        logger.error(f"데이터베이스 연결 테스트 실패: {e}")
        return False
