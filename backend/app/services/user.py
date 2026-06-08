from __future__ import annotations

import csv
import io
import secrets
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.auth import User
from app.services.scoping import get_instructor_cohort_ids
from app.schemas.user import (
    BulkImportResult,
    PasswordResetResult,
    UserCreate,
    UserListItem,
    UserOut,
    UserRoleUpdate,
    UserUpdate,
)

VALID_ROLES = {"admin_ops", "tech_support", "instructor", "student"}


async def list_users(
    db: AsyncSession,
    current_user: User,
    role: Optional[str] = None,
    cohort_id: Optional[int] = None,
    search: Optional[str] = None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[UserListItem], int]:
    query = select(User).where(
        User.institution_id == current_user.institution_id
    )

    if current_user.role == "instructor":
        taught = await get_instructor_cohort_ids(db, current_user.id)
        if not taught:
            return [], 0
        query = query.where(
            User.cohort_id.in_(taught),
            User.role == "student",
        )
    elif current_user.role == "student":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                            detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    if role:
        query = query.where(User.role == role)
    if cohort_id:
        query = query.where(User.cohort_id == cohort_id)
    if search:
        query = query.where(
            or_(User.name.ilike(f"%{search}%"), User.email.ilike(f"%{search}%"))
        )

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(User.id)
    )
    users = result.scalars().all()
    return [UserListItem.model_validate(u) for u in users], total


async def get_user(
    db: AsyncSession, user_id: int, current_user: User
) -> UserOut:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404,
                            detail={"code": "NOT_FOUND", "message": "사용자를 찾을 수 없습니다."})

    if current_user.role in ("admin_ops", "tech_support"):
        pass
    elif current_user.role == "instructor":
        taught = await get_instructor_cohort_ids(db, current_user.id)
        if user.cohort_id not in taught or user.role != "student":
            raise HTTPException(status_code=403,
                                detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})
    elif current_user.id != user_id:
        raise HTTPException(status_code=403,
                            detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    return UserOut.model_validate(user)


async def create_user(
    db: AsyncSession, data: UserCreate, current_user: User
) -> UserOut:
    if data.role not in VALID_ROLES:
        raise HTTPException(status_code=422,
                            detail={"code": "INVALID_ROLE", "message": "유효하지 않은 역할입니다."})

    existing = await db.execute(
        select(User).where(
            User.institution_id == current_user.institution_id,
            User.email == data.email,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409,
                            detail={"code": "EMAIL_DUPLICATE", "message": "이미 사용 중인 이메일입니다."})

    temp_password = secrets.token_urlsafe(12)
    user = User(
        institution_id=current_user.institution_id,
        cohort_id=data.cohort_id,
        email=data.email,
        name=data.name,
        phone=data.phone,
        role=data.role,
        password_hash=hash_password(temp_password),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return UserOut.model_validate(user)


async def update_user(
    db: AsyncSession, user_id: int, data: UserUpdate, current_user: User
) -> UserOut:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404,
                            detail={"code": "NOT_FOUND", "message": "사용자를 찾을 수 없습니다."})

    if current_user.role != "admin_ops" and current_user.id != user_id:
        raise HTTPException(status_code=403,
                            detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return UserOut.model_validate(user)


async def update_user_role(
    db: AsyncSession, user_id: int, data: UserRoleUpdate
) -> UserOut:
    if data.role not in VALID_ROLES:
        raise HTTPException(status_code=422,
                            detail={"code": "INVALID_ROLE", "message": "유효하지 않은 역할입니다."})

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404,
                            detail={"code": "NOT_FOUND", "message": "사용자를 찾을 수 없습니다."})

    user.role = data.role
    if data.cohort_id is not None:
        user.cohort_id = data.cohort_id
    await db.commit()
    await db.refresh(user)
    return UserOut.model_validate(user)


async def deactivate_user(db: AsyncSession, user_id: int) -> dict:
    from datetime import datetime, timedelta, timezone

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404,
                            detail={"code": "NOT_FOUND", "message": "사용자를 찾을 수 없습니다."})

    user.is_active = False
    await db.commit()

    now = datetime.now(timezone.utc)
    return {
        "deactivated_at": now.isoformat(),
        "scheduled_purge_at": (now + timedelta(days=30)).isoformat(),
    }


async def reset_password(db: AsyncSession, user_id: int) -> PasswordResetResult:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404,
                            detail={"code": "NOT_FOUND", "message": "사용자를 찾을 수 없습니다."})

    temp_password = secrets.token_urlsafe(12)
    user.password_hash = hash_password(temp_password)
    await db.commit()
    return PasswordResetResult(temporary_password=temp_password)


async def bulk_import(db: AsyncSession, csv_content: str, current_user: User) -> BulkImportResult:
    reader = csv.DictReader(io.StringIO(csv_content))
    imported = 0
    failed = 0
    errors: list[dict] = []

    for i, row in enumerate(reader, start=2):
        try:
            email = row.get("email", "").strip()
            name = row.get("name", "").strip()
            role = row.get("role", "student").strip()
            cohort_id_str = row.get("cohort_id", "").strip()

            if not email or not name:
                raise ValueError("이메일과 이름은 필수입니다.")
            if role not in VALID_ROLES:
                raise ValueError(f"유효하지 않은 역할: {role}")

            existing = await db.execute(
                select(User).where(
                    User.institution_id == current_user.institution_id,
                    User.email == email,
                )
            )
            if existing.scalar_one_or_none():
                raise ValueError("이메일 중복")

            user = User(
                institution_id=current_user.institution_id,
                cohort_id=int(cohort_id_str) if cohort_id_str else None,
                email=email,
                name=name,
                role=role,
                password_hash=hash_password(secrets.token_urlsafe(12)),
            )
            db.add(user)
            imported += 1
        except Exception as e:
            failed += 1
            errors.append({"row": i, "reason": str(e)})

    await db.commit()
    return BulkImportResult(imported=imported, failed=failed, errors=errors)
