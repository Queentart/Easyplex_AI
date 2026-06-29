import asyncio
import sys
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.config import settings

async def main():
    try:
        # DB 접속
        engine = create_async_engine(settings.DATABASE_URL, isolation_level="AUTOCOMMIT")
        
        async with engine.connect() as conn:
            print("Seeding dummy data for INSTRUCTOR and TUTOR...")
            
            # userrole enum에 TUTOR 추가 (이미 있을 경우를 대비해 예외처리)
            try:
                await conn.execute(text("ALTER TYPE userrole ADD VALUE 'TUTOR'"))
            except Exception:
                pass
            
            # 주강사 추가 (기존에 없으면)
            await conn.execute(text("""
                INSERT INTO users (email, hashed_password, role, full_name, is_active, created_at, updated_at)
                SELECT 'instructor@test.com', 'hashed_pw_dummy', 'INSTRUCTOR', '주강사', true, NOW(), NOW()
                WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'instructor@test.com')
            """))
            
            # 멘토 추가
            await conn.execute(text("""
                INSERT INTO users (email, hashed_password, role, full_name, is_active, created_at, updated_at)
                SELECT 'tutor@test.com', 'hashed_pw_dummy', 'TUTOR', '보조멘토', true, NOW(), NOW()
                WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'tutor@test.com')
            """))
            
            print("Successfully inserted dummy instructor and tutor.")
            
    except Exception as e:
        print(f"Error: {e.__class__.__name__}: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
