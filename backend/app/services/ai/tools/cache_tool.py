from langchain_core.tools import tool
from app.db.redis_client import redis_client
import hashlib

def generate_cache_key(query: str, role: str) -> str:
    """
    질문과 역할을 바탕으로 고유한 캐시 키를 생성합니다.
    """
    raw_key = f"{role}:{query.strip().lower()}"
    return f"cache:llm:{hashlib.md5(raw_key.encode('utf-8')).hexdigest()}"

@tool
async def check_semantic_cache(query: str, role: str = "student") -> str:
    """
    주어진 질문(query)이 이미 Redis 캐시에 있는지 확인합니다.
    자주 들어오는 중복 질문을 LLM을 거치지 않고 빠르게 반환합니다.
    """
    key = generate_cache_key(query, role)
    result = await redis_client.get(key)
    
    if result:
        return f"[CACHE_HIT] {result}"
    return "[CACHE_MISS]"

async def set_cache(query: str, response: str, role: str = "student", expire: int = 3600) -> bool:
    """
    에이전트가 새롭게 생성한 응답을 Redis 캐시에 저장합니다.
    """
    key = generate_cache_key(query, role)
    return await redis_client.set(key, response, expire)
