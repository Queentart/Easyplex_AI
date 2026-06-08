from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_DEFAULT_SECRET = "change-me-to-random-32-bytes-string"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    debug: bool = True

    database_url: str = "postgresql+asyncpg://dev:dev1234@localhost:5432/dongaai_dev"
    redis_url: str = "redis://localhost:6379/0"

    secret_key: str = _DEFAULT_SECRET
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 14

    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    aws_s3_bucket: str = ""
    aws_region: str = "ap-northeast-2"
    aws_endpoint_url: str | None = None

    aes_secret_key: str = ""

    @field_validator("secret_key")
    @classmethod
    def secret_key_must_be_set(cls, v: str) -> str:
        if v == _DEFAULT_SECRET:
            raise ValueError(
                "SECRET_KEY must be changed from the default value. "
                "Set it via the SECRET_KEY environment variable."
            )
        return v

    @field_validator("aes_secret_key")
    @classmethod
    def aes_key_must_be_set(cls, v: str) -> str:
        if not v:
            raise ValueError(
                "AES_SECRET_KEY must be set. "
                "Set it via the AES_SECRET_KEY environment variable."
            )
        return v


settings = Settings()
