import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.config import settings

async def main():
    engine = create_async_engine(settings.DATABASE_URL, isolation_level='AUTOCOMMIT')
    async with engine.connect() as conn:
        try:
            await conn.execute(text("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'TUTOR'"))
            print('Enum updated successfully')
        except Exception as e:
            print('Error:', e)

if __name__ == '__main__':
    asyncio.run(main())
