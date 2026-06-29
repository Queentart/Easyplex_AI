import asyncio
import os
import sys

base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(base_dir)

from app.db.session import SessionLocal
from app.models.auth import User
from app.models.student import Student
from sqlalchemy import delete

async def clear():
    async with SessionLocal() as db:
        await db.execute(delete(Student))
        await db.execute(delete(User))
        await db.commit()
        print('Cleared DB')

if __name__ == "__main__":
    asyncio.run(clear())
