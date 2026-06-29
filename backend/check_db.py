import asyncio
import os
import sys

base_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(base_dir)

from app.db.session import SessionLocal
from app.models.auth import User
from app.models.student import Student
from sqlalchemy import select

async def main():
    async with SessionLocal() as db:
        # Check users
        result = await db.execute(select(User))
        users = result.scalars().all()
        print(f"Total users: {len(users)}")
        for u in users:
            print(f"User: {u.email}, Role: {u.role}, ID: {u.id}, Active: {u.is_active}")
            
        # Check students
        result = await db.execute(select(Student))
        students = result.scalars().all()
        print(f"\nTotal students: {len(students)}")
        for s in students:
            print(f"Student: {s.student_number}, User ID: {s.user_id}, Status: {s.status}")

        # Try the join query
        student_number = "24-001"
        stmt = select(User).join(Student, User.id == Student.user_id).where(Student.student_number == student_number)
        result = await db.execute(stmt)
        user = result.scalars().first()
        print(f"\nLogin Query Result for {student_number}: {user}")
        if user:
            print(f"User email: {user.email}")

if __name__ == "__main__":
    asyncio.run(main())
