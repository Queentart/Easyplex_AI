import redis.asyncio as redis
import logging
from typing import Optional
from app.core.config import settings

logger = logging.getLogger(__name__)

class RedisClient:
    """
    비동기 Redis 클라이언트 래퍼 클래스입니다.
    빈번하게 조회되는 데이터나 LLM 응답 등을 캐싱하기 위해 사용됩니다.
    """
    def __init__(self):
        self.redis: Optional[redis.Redis] = None

    async def connect(self):
        """Redis 서버와 연결을 시도합니다."""
        try:
            self.redis = redis.from_url(
                settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True,
                protocol=2  # 지원되지 않는 구버전 Redis(RESP3 미지원) 호환을 위해 RESP2 프로토콜 강제 사용
            )
            # 연결 테스트 (ping)
            await self.redis.ping()
            logger.info("Redis 연결 성공 및 초기화 완료.")
            return True
        except Exception as e:
            logger.error(f"Redis 연결 실패: {e}")
            self.redis = None
            return False

    async def close(self):
        """Redis 서버와의 연결을 종료합니다."""
        if self.redis:
            await self.redis.close()

    async def get(self, key: str) -> Optional[str]:
        """캐시에서 값을 가져옵니다."""
        if not self.redis:
            return None
        return await self.redis.get(key)

    async def set(self, key: str, value: str, expire: int = 3600) -> bool:
        """캐시에 값을 저장합니다. (기본 만료 시간 1시간)"""
        if not self.redis:
            return False
        return await self.redis.set(key, value, ex=expire)

# 전역에서 사용할 Redis 클라이언트 인스턴스
redis_client = RedisClient()
