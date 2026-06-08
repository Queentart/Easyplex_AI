"""
개발 환경 초기 데이터 생성 — 최초 1회 자동 실행됨 (run.bat 경유)

생성 항목:
  - Institution: 동아AI랩
  - Cohort: 2026 1기
  - 관리자:    admin@dongaai.com    / Admin1234!
  - 수강생:    student@dongaai.com  / Student1234!
  - 강사:      instructor@dongaai.com / Instr1234!
  - 기술지원:  tech@dongaai.com     / Tech1234!
"""
import asyncio
import sys
from datetime import date
from pathlib import Path

# backend/ 를 sys.path 에 추가 (app.* import 가능하도록)
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select

from app.core.database import async_session_factory
from app.core.security import hash_password
from app.models.auth import User
from app.models.organization import Cohort, Institution

TEST_ACCOUNTS = [
    ("admin@dongaai.com",      "Admin1234!",   "관리자",   "admin_ops",    False),
    ("student@dongaai.com",    "Student1234!", "김수강",   "student",      True),
    ("instructor@dongaai.com", "Instr1234!",   "이강사",   "instructor",   False),
    ("tech@dongaai.com",       "Tech1234!",    "박기술",   "tech_support", False),
]


async def seed() -> None:
    async with async_session_factory() as db:
        existing = await db.execute(select(Institution).limit(1))
        if existing.scalar_one_or_none():
            print("  이미 초기 데이터가 있습니다. 건너뜁니다.")
            return

        institution = Institution(
            name="동아AI랩",
            code="DONGAAI",
            contact_email="contact@dongaai.com",
            settings={},
            is_active=True,
        )
        db.add(institution)
        await db.flush()

        cohort = Cohort(
            institution_id=institution.id,
            name="2026 1기",
            code="2026-01",
            start_date=date(2026, 3, 2),
            end_date=date(2026, 8, 29),
            total_hours=960,
            status="ongoing",
        )
        db.add(cohort)
        await db.flush()

        print(f"  시드 완료")
        for email, password, name, role, needs_cohort in TEST_ACCOUNTS:
            user = User(
                institution_id=institution.id,
                email=email,
                password_hash=hash_password(password),
                name=name,
                role=role,
                cohort_id=cohort.id if needs_cohort else None,
                is_active=True,
            )
            db.add(user)
            print(f"    [{role:12s}] {email} / {password}")

        await db.commit()


if __name__ == "__main__":
    asyncio.run(seed())
