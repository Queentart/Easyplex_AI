import asyncio
import os
import sys

base_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(base_dir)

from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.config import settings
from app.core.security import get_password_hash

async def main():
    engine = create_async_engine(settings.DATABASE_URL, isolation_level="AUTOCOMMIT")
    async with engine.connect() as conn:
        hashed_pw = get_password_hash("1234")
        await conn.execute(text("""
            INSERT INTO users (email, hashed_password, role, full_name, is_active, created_at, updated_at)
            VALUES ('eduops@easyplex.com', :hashed_pw, 'EDUOPS', 'EduOps Park', true, NOW(), NOW())
            ON CONFLICT (email) DO UPDATE SET hashed_password = :hashed_pw;
        """), {"hashed_pw": hashed_pw})
        print("Successfully inserted/updated eduops@easyplex.com with proper hash.")

if __name__ == "__main__":
    asyncio.run(main())
