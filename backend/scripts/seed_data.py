import asyncio
import os
import sys

# Add the parent directory to sys.path to import from app
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db.session import SessionLocal
from app.models.auth import User, UserRole
from app.core.security import get_password_hash

async def seed_users(db: AsyncSession):
    # 테스트용 사용자들이 이미 존재하는지 확인
    result = await db.execute(select(User))
    existing_users = result.scalars().all()
    if existing_users:
        print("이미 사용자가 존재합니다. Seed를 건너뜁니다.")
        return

    print("초기 사용자 데이터를 생성합니다...")
    
    users_to_create = [
        {
            "email": "owner@easyplex.ai",
            "hashed_password": get_password_hash("1234"),
            "full_name": "원장님",
            "role": UserRole.OWNER
        },
        {
            "email": "admin@easyplex.ai",
            "hashed_password": get_password_hash("1234"),
            "full_name": "관리자",
            "role": UserRole.TECHOPS # TECHOPS 또는 ADMIN 매핑
        },
        {
            "email": "instructor@easyplex.ai",
            "hashed_password": get_password_hash("1234"),
            "full_name": "김강사",
            "role": UserRole.INSTRUCTOR
        },
        {
            "email": "ops@easyplex.ai",
            "hashed_password": get_password_hash("1234"),
            "full_name": "운영매니저",
            "role": UserRole.EDUOPS
        },
        {
            "email": "24-001@student.easyplex.ai",
            "hashed_password": get_password_hash("1234"),
            "full_name": "이학생",
            "role": UserRole.STUDENT
        },
        {
            "email": "24-042@student.easyplex.ai",
            "hashed_password": get_password_hash("1234"),
            "full_name": "박민호",
            "role": UserRole.STUDENT
        },
        {
            "email": "23-118@student.easyplex.ai",
            "hashed_password": get_password_hash("1234"),
            "full_name": "최하은",
            "role": UserRole.STUDENT
        }
    ]

    for user_data in users_to_create:
        db_user = User(**user_data)
        db.add(db_user)
        
    await db.commit()
    print("초기 사용자 데이터 생성 완료!")

async def main():
    async with SessionLocal() as session:
        await seed_users(session)

if __name__ == "__main__":
    asyncio.run(main())
