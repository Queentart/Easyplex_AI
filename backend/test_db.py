import asyncio
import os
import sys

base_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(base_dir)

from app.db.session import SessionLocal
from sqlalchemy import select
from app.models.auth import User

async def main():
    async with SessionLocal() as db:
        result = await db.execute(select(User.email, User.hashed_password, User.is_active, User.role))
        users = result.all()
        for u in users:
            print(u)

if __name__ == "__main__":
    asyncio.run(main())
