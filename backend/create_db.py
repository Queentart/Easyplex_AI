import asyncio
import sys
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

async def main():
    try:
        # DB 이름을 지정하지 않고 postgres 기본 DB에 접속 (127.0.0.1 사용)
        engine = create_async_engine("postgresql+asyncpg://postgres:1234@localhost:5432/postgres", isolation_level="AUTOCOMMIT")
        
        async with engine.connect() as conn:
            # 데이터베이스 존재 여부 확인
            result = await conn.execute(text("SELECT 1 FROM pg_database WHERE datname='easyplex_db'"))
            exists = result.fetchone()
            if not exists:
                await conn.execute(text('CREATE DATABASE easyplex_db'))
                print("Database 'easyplex_db' created successfully.")
            else:
                print("Database 'easyplex_db' already exists.")
            
    except Exception as e:
        print(f"Error: {e.__class__.__name__}: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
