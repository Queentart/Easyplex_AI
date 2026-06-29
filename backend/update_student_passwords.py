import asyncio
import os
import sys

base_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(base_dir)

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db.session import SessionLocal
from app.models.auth import User, UserRole
from app.core.security import get_password_hash

async def main():
    async with SessionLocal() as db:
        result = await db.execute(select(User).where(User.role == UserRole.STUDENT))
        students = result.scalars().all()
        
        hashed_pw = get_password_hash("1234")
        
        for student in students:
            student.hashed_password = hashed_pw
            
        await db.commit()
        print(f"Updated passwords for {len(students)} students to '1234'.")

if __name__ == "__main__":
    asyncio.run(main())
