from __future__ import annotations

import os
from base64 import b64decode, b64encode
from datetime import datetime, timezone
from typing import Optional

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.hashes import SHA256
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.auth import AuditLog, User
from app.models.inquiry import Inquiry, InquiryMessage, SoftwareLicense
from app.services.scoping import get_instructor_cohort_ids
from app.schemas.inquiry import (
    InquiryCreate,
    InquiryMessageCreate,
    InquiryMessageOut,
    InquiryOut,
    InquiryUpdate,
    LicenseCreate,
    LicenseOut,
    LicenseWithKey,
)


async def list_inquiries(
    db: AsyncSession,
    current_user: User,
    status: Optional[str] = None,
    type_filter: Optional[str] = None,
    priority: Optional[str] = None,
    assigned_to_me: bool = False,
    page: int = 1,
    size: int = 20,
) -> tuple[list[InquiryOut], int]:
    query = select(Inquiry)

    if current_user.role == "student":
        query = query.where(Inquiry.author_id == current_user.id)
    elif current_user.role == "instructor":
        taught = await get_instructor_cohort_ids(db, current_user.id)
        if taught:
            query = query.where(
                (Inquiry.author_id == current_user.id) |
                (Inquiry.cohort_id.in_(taught))
            )
        else:
            query = query.where(Inquiry.author_id == current_user.id)

    if assigned_to_me:
        query = query.where(Inquiry.assigned_to == current_user.id)
    if status:
        query = query.where(Inquiry.status == status)
    if type_filter:
        query = query.where(Inquiry.type == type_filter)
    if priority:
        query = query.where(Inquiry.priority == priority)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(Inquiry.created_at.desc())
    )
    return [InquiryOut.model_validate(i) for i in result.scalars().all()], total


async def create_inquiry(
    db: AsyncSession, data: InquiryCreate, current_user: User
) -> InquiryOut:
    inquiry = Inquiry(
        cohort_id=current_user.cohort_id,
        author_id=current_user.id,
        **data.model_dump(),
    )
    db.add(inquiry)
    await db.commit()
    await db.refresh(inquiry)
    return InquiryOut.model_validate(inquiry)


async def get_inquiry(
    db: AsyncSession, inquiry_id: int, current_user: User
) -> InquiryOut:
    result = await db.execute(select(Inquiry).where(Inquiry.id == inquiry_id))
    inquiry = result.scalar_one_or_none()
    if inquiry is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "문의를 찾을 수 없습니다."})

    if current_user.role == "student" and inquiry.author_id != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    return InquiryOut.model_validate(inquiry)


async def update_inquiry(
    db: AsyncSession, inquiry_id: int, data: InquiryUpdate, current_user: User
) -> InquiryOut:
    result = await db.execute(select(Inquiry).where(Inquiry.id == inquiry_id))
    inquiry = result.scalar_one_or_none()
    if inquiry is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "문의를 찾을 수 없습니다."})

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(inquiry, field, value)

    if data.status == "resolved":
        inquiry.resolved_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(inquiry)
    return InquiryOut.model_validate(inquiry)


async def add_message(
    db: AsyncSession, inquiry_id: int, data: InquiryMessageCreate, current_user: User
) -> InquiryMessageOut:
    message = InquiryMessage(
        inquiry_id=inquiry_id,
        sender_id=current_user.id,
        **data.model_dump(),
    )
    db.add(message)
    await db.commit()
    await db.refresh(message)
    return InquiryMessageOut.model_validate(message)


async def list_messages(
    db: AsyncSession, inquiry_id: int, page: int = 1, size: int = 50
) -> tuple[list[InquiryMessageOut], int]:
    query = select(InquiryMessage).where(InquiryMessage.inquiry_id == inquiry_id)
    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(InquiryMessage.created_at)
    )
    return [InquiryMessageOut.model_validate(m) for m in result.scalars().all()], total


async def close_inquiry(db: AsyncSession, inquiry_id: int) -> InquiryOut:
    result = await db.execute(select(Inquiry).where(Inquiry.id == inquiry_id))
    inquiry = result.scalar_one_or_none()
    if inquiry is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "문의를 찾을 수 없습니다."})
    inquiry.status = "closed"
    await db.commit()
    await db.refresh(inquiry)
    return InquiryOut.model_validate(inquiry)


def _derive_aes_key(salt: bytes) -> bytes:
    return HKDF(
        algorithm=SHA256(),
        length=32,
        salt=salt,
        info=b"dongaai-license-key",
    ).derive(settings.aes_secret_key.encode())


def _encrypt_key(plain_key: str) -> tuple[bytes, bytes]:
    iv = os.urandom(16)
    key = _derive_aes_key(salt=iv)
    cipher = Cipher(algorithms.AES(key), modes.CFB(iv))
    enc = cipher.encryptor()
    encrypted = enc.update(plain_key.encode()) + enc.finalize()
    return encrypted, iv


def _decrypt_key(encrypted: bytes, iv: bytes) -> str:
    key = _derive_aes_key(salt=iv)
    cipher = Cipher(algorithms.AES(key), modes.CFB(iv))
    dec = cipher.decryptor()
    return (dec.update(encrypted) + dec.finalize()).decode()


async def create_license(
    db: AsyncSession, data: LicenseCreate, current_user: User
) -> LicenseOut:
    encrypted_key, iv = _encrypt_key(data.license_key)
    license_ = SoftwareLicense(
        institution_id=current_user.institution_id,
        service_name=data.service_name,
        encrypted_key=encrypted_key,
        key_iv=iv,
        issued_at=data.issued_at,
        expires_at=data.expires_at,
        seat_count=data.seat_count,
        notes=data.notes,
        created_by=current_user.id,
    )
    db.add(license_)
    await db.commit()
    await db.refresh(license_)
    return LicenseOut.model_validate(license_)


async def list_licenses(
    db: AsyncSession, current_user: User, page: int = 1, size: int = 20
) -> tuple[list[LicenseOut], int]:
    query = select(SoftwareLicense).where(
        SoftwareLicense.institution_id == current_user.institution_id
    )
    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(SoftwareLicense.created_at.desc())
    )
    return [LicenseOut.model_validate(l) for l in result.scalars().all()], total


async def get_license_with_key(
    db: AsyncSession, license_id: int, current_user: User
) -> LicenseWithKey:
    result = await db.execute(select(SoftwareLicense).where(SoftwareLicense.id == license_id))
    lic = result.scalar_one_or_none()
    if lic is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "라이센스를 찾을 수 없습니다."})

    plain_key = _decrypt_key(bytes(lic.encrypted_key), bytes(lic.key_iv))

    now = datetime.now(timezone.utc)
    lic.last_accessed_at = now

    log = AuditLog(
        actor_id=current_user.id,
        action="license.read",
        target_type="software_license",
        target_id=license_id,
        created_at=now,
    )
    db.add(log)
    await db.commit()

    out = LicenseOut.model_validate(lic)
    return LicenseWithKey(**out.model_dump(), license_key=plain_key)
