import asyncio
import os
import sys

base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(base_dir)

from sqlalchemy.ext.asyncio import create_async_engine
from app.core.config import settings
from app.db.base import Base

async def main():
    engine = create_async_engine(settings.DATABASE_URL, echo=True)
    async with engine.begin() as conn:
        # DB에 존재하지 않는 테이블들을 생성
        await conn.run_sync(Base.metadata.create_all)
    print("Successfully created missing tables.")

if __name__ == "__main__":
    asyncio.run(main())
