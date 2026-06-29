import asyncio
import sys
from sqlalchemy.ext.asyncio import create_async_engine
from app.db.base_class import Base
from app.models.instructor_models import InstructorTicket # Ensure it's imported so it gets registered in Base.metadata

from app.core.config import settings

async def main():
    engine = create_async_engine(settings.DATABASE_URL, echo=True)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("Tables created successfully.")

if __name__ == "__main__":
    asyncio.run(main())
