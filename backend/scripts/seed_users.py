import asyncio
import sys
import os

base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(base_dir)

from app.db.session import SessionLocal
from app.models.auth import User, UserRole
from app.models.student import Student, StudentStatus

async def seed_users():
    async with SessionLocal() as db:
        from sqlalchemy import delete, select
        
        # 이미 데이터가 존재하는지 확인 (데이터가 있으면 중복 삽입 방지)
        result = await db.execute(select(User).limit(1))
        if result.scalars().first():
            print("Users already exist. Skipping seed.")
            return

        await db.execute(delete(Student))
        await db.execute(delete(User))
        await db.commit()
        from app.core.security import get_password_hash
        hashed_pw = get_password_hash("1234")
        
        print("Cleared old data. Generating users and student data...")
        
        dummy_users = [
            User(email="24-001@student.easyplex.ai", hashed_password=hashed_pw, role=UserRole.STUDENT, full_name="김지우"),
            User(email="24-042@student.easyplex.ai", hashed_password=hashed_pw, role=UserRole.STUDENT, full_name="박민호"),
            User(email="23-118@student.easyplex.ai", hashed_password=hashed_pw, role=UserRole.STUDENT, full_name="최하은"),
            User(email="instructor@easyplex.com", hashed_password=hashed_pw, role=UserRole.INSTRUCTOR, full_name="김강사"),
            User(email="tutor@easyplex.com", hashed_password=hashed_pw, role=UserRole.TUTOR, full_name="튜터"),
            User(email="eduops@easyplex.com", hashed_password=hashed_pw, role=UserRole.EDUOPS, full_name="운영매니저"),
            User(email="techops@easyplex.com", hashed_password=hashed_pw, role=UserRole.TECHOPS, full_name="관리자"),
            User(email="owner@easyplex.com", hashed_password=hashed_pw, role=UserRole.OWNER, full_name="원장님"),
        ]
        
        db.add_all(dummy_users)
        await db.commit()
        
        student_users = [u for u in dummy_users if u.role == UserRole.STUDENT]
        
        students_data = {
            "24-001@student.easyplex.ai": ("24-001", "Spring 2024"),
            "24-042@student.easyplex.ai": ("24-042", "Spring 2024"),
            "23-118@student.easyplex.ai": ("23-118", "Fall 2023"),
        }
        
        dummy_students = []
        for su in student_users:
            s_num, s_cohort = students_data[su.email]
            dummy_students.append(
                Student(
                    user_id=su.id,
                    student_number=s_num,
                    grade=s_cohort,
                    status=StudentStatus.ACTIVE
                )
            )
            
        db.add_all(dummy_students)
        await db.commit()
        
        print("Success! Created users and students.")
        for u in dummy_users:
            print(f"- Email: {u.email} | PW: 1234 | Role: {u.role.value}")

if __name__ == "__main__":
    asyncio.run(seed_users())
