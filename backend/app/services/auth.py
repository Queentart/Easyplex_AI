from __future__ import annotations

import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
)
from app.models.auth import RefreshToken, User
from app.models.organization import InstructorCohort
from app.schemas.auth import LoginResponse, MeResponse, TokenUserInfo

ROLE_PERMISSIONS: dict[str, list[str]] = {
    "admin_ops": [
        "user.create", "user.update", "user.delete",
        "cohort.create", "cohort.update", "cohort.delete",
        "attendance.import", "attendance.update",
        "post.create", "post.update", "post.delete",
        "assignment.create", "assignment.update",
        "leave_request.review",
        "inquiry.assign", "inquiry.resolve",
        "license.read", "license.create",
        "class.create", "class.update",
        "career_posting.create",
    ],
    "tech_support": [
        "user.read", "attendance.read",
        "inquiry.assign", "inquiry.resolve",
        "license.read",
        "post.create", "post.update",
    ],
    "instructor": [
        "post.create", "post.update",
        "assignment.create", "assignment.update",
        "attendance.read", "attendance.update",
        "submission.review",
        "class.create", "class.update",
        "training_log.create",
        "mentoring_log.create",
        "career_posting.create",
    ],
    "student": [
        "post.create",
        "submission.create",
        "leave_request.create",
        "inquiry.create",
        "class_evaluation.create",
        "attendance.read_self",
    ],
}


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


async def get_user_cohort_ids(db: AsyncSession, user: User) -> list[int]:
    """Resolve the full set of cohort ids a user is associated with.

    - student: their single ``users.cohort_id`` (if set).
    - instructor: the cohorts they teach, via the ``instructor_cohorts`` join
      table (one query, no N+1).
    - admin_ops / tech_support: [] (institution-wide; not cohort-scoped here).
    """
    if user.role == "instructor":
        result = await db.execute(
            select(InstructorCohort.cohort_id).where(
                InstructorCohort.instructor_id == user.id
            )
        )
        return [row[0] for row in result.all()]
    if user.role == "student":
        return [user.cohort_id] if user.cohort_id is not None else []
    return []


def _token_user_info(user: User, cohort_ids: list[int]) -> TokenUserInfo:
    return TokenUserInfo(
        id=user.id,
        email=user.email,
        name=user.name,
        role=user.role,
        cohort_id=user.cohort_id,
        cohort_ids=cohort_ids,
        institution_id=user.institution_id,
    )


async def login(
    email: str, password: str, db: AsyncSession, ip_address: Optional[str] = None
) -> LoginResponse:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if user is None or not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "UNAUTHORIZED", "message": "이메일 또는 비밀번호가 올바르지 않습니다."},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "ACCOUNT_DISABLED", "message": "비활성화된 계정입니다."},
        )

    access_token = create_access_token({"sub": str(user.id), "role": user.role})
    refresh_token_raw = create_refresh_token()
    refresh_token_hash = _hash_token(refresh_token_raw)

    expires_at = datetime.now(timezone.utc) + timedelta(
        days=settings.refresh_token_expire_days
    )
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=refresh_token_hash,
            ip_address=ip_address,
            expires_at=expires_at,
            created_at=datetime.now(timezone.utc),
        )
    )

    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()

    cohort_ids = await get_user_cohort_ids(db, user)
    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token_raw,
        expires_in=settings.access_token_expire_minutes * 60,
        user=_token_user_info(user, cohort_ids),
    )


async def refresh(
    refresh_token_raw: str, db: AsyncSession, ip_address: Optional[str] = None
) -> LoginResponse:
    token_hash = _hash_token(refresh_token_raw)
    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )
    token_record = result.scalar_one_or_none()

    now = datetime.now(timezone.utc)
    if (
        token_record is None
        or token_record.revoked_at is not None
        or token_record.expires_at < now
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_REFRESH", "message": "리프레시 토큰이 유효하지 않거나 만료되었습니다."},
        )

    user_result = await db.execute(select(User).where(User.id == token_record.user_id))
    user = user_result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "ACCOUNT_DISABLED", "message": "비활성화된 계정입니다."},
        )

    # rotate: revoke old, issue new
    token_record.revoked_at = now

    new_refresh_raw = create_refresh_token()
    new_refresh_hash = _hash_token(new_refresh_raw)
    new_expires = now + timedelta(days=settings.refresh_token_expire_days)

    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=new_refresh_hash,
            ip_address=ip_address,
            expires_at=new_expires,
            created_at=now,
        )
    )

    new_access = create_access_token({"sub": str(user.id), "role": user.role})
    await db.commit()

    cohort_ids = await get_user_cohort_ids(db, user)
    return LoginResponse(
        access_token=new_access,
        refresh_token=new_refresh_raw,
        expires_in=settings.access_token_expire_minutes * 60,
        user=_token_user_info(user, cohort_ids),
    )


async def logout(refresh_token_raw: str, db: AsyncSession) -> None:
    token_hash = _hash_token(refresh_token_raw)
    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )
    token_record = result.scalar_one_or_none()
    if token_record and token_record.revoked_at is None:
        token_record.revoked_at = datetime.now(timezone.utc)
        await db.commit()


async def change_password(
    user: User, current_password: str, new_password: str, db: AsyncSession
) -> None:
    if not verify_password(current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "INVALID_CURRENT_PASSWORD", "message": "현재 비밀번호가 올바르지 않습니다."},
        )
    if len(new_password) < 8:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "WEAK_PASSWORD", "message": "비밀번호는 8자 이상이어야 합니다."},
        )
    user.password_hash = hash_password(new_password)
    await db.commit()


async def build_me_response(db: AsyncSession, user: User) -> MeResponse:
    permissions = ROLE_PERMISSIONS.get(user.role, [])
    cohort_ids = await get_user_cohort_ids(db, user)
    return MeResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        nickname=user.nickname,
        role=user.role,
        cohort_id=user.cohort_id,
        cohort_ids=cohort_ids,
        institution_id=user.institution_id,
        profile_image_url=user.profile_image_url,
        permissions=permissions,
    )
