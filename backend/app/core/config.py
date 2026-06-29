from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class Settings(BaseSettings):
    # 기본 환경 정보
    PROJECT_NAME: str = "EasyPlex AI Backend"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # JWT 인증 설정
    SECRET_KEY: str = "your-super-secret-key-for-jwt-signing" # 실제 배포 시 무작위 생성 키 사용
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7 # 7일

    # PostgreSQL 설정 (asyncpg)
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str = "1234"  # 실제 환경에서는 .env 파일로 관리 요망
    POSTGRES_DB: str = "easyplex_db"
    POSTGRES_PORT: str = "5432"

    @property
    def DATABASE_URL(self) -> str:
        """SQLAlchemy를 위한 비동기 PostgreSQL 접속 URL"""
        return f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    # Redis 설정
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0
    REDIS_PASSWORD: Optional[str] = None

    # AI & LLM Settings (Ollama)
    OLLAMA_BASE_URL: str = "http://localhost:11434"
    LLM_MAIN_MODEL: str = "qwen2.5:latest"
    LLM_REASONING_MODEL: str = "deepseek-r1:latest"
    LLM_EMBEDDING_MODEL: str = "nomic-embed-text:latest"

    @property
    def REDIS_URL(self) -> str:
        """Redis 접속 URL"""
        if self.REDIS_PASSWORD:
            return f"redis://:{self.REDIS_PASSWORD}@{self.REDIS_HOST}:{self.REDIS_PORT}/{self.REDIS_DB}"
        return f"redis://{self.REDIS_HOST}:{self.REDIS_PORT}/{self.REDIS_DB}"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

settings = Settings()
