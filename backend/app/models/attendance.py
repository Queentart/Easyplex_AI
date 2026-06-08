from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from sqlalchemy import (
    BigInteger,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.base import TimestampMixin


class AttendanceRecord(Base, TimestampMixin):
    __tablename__ = "attendance_records"
    __table_args__ = (
        UniqueConstraint("user_id", "date", name="uq_attendance_user_date"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    cohort_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("cohorts.id"), nullable=False
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id"), nullable=False
    )
    date: Mapped[date] = mapped_column(Date, nullable=False)
    check_in_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    check_out_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    type: Mapped[str] = mapped_column(
        String(20), nullable=False
    )  # present, late, absent, early_leave, medical, official
    late_minutes: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    early_leave_minutes: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    import_source: Mapped[str] = mapped_column(
        String(30), nullable=False, default="manual"
    )  # manual, csv_gov, system_calc
    import_batch_id: Mapped[Optional[str]] = mapped_column(
        UUID(as_uuid=False), nullable=True
    )
    linked_leave_request_id: Mapped[Optional[int]] = mapped_column(
        BigInteger, ForeignKey("leave_requests.id"), nullable=True
    )
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)


class AttendanceImportLog(Base):
    __tablename__ = "attendance_import_log"
    __table_args__ = (
        UniqueConstraint("batch_id", name="uq_attendance_import_batch_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    institution_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("institutions.id"), nullable=False
    )
    cohort_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("cohorts.id"), nullable=False
    )
    uploader_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id"), nullable=False
    )
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    file_path: Mapped[str] = mapped_column(Text, nullable=False)
    batch_id: Mapped[str] = mapped_column(UUID(as_uuid=False), nullable=False)
    row_count: Mapped[int] = mapped_column(Integer, nullable=False)
    success_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    fail_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    policy: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending"
    )  # pending, confirmed, rolled_back
    confirmed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    rolled_back_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class AttendanceRule(Base):
    __tablename__ = "attendance_rule"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    institution_id: Mapped[Optional[int]] = mapped_column(
        BigInteger, ForeignKey("institutions.id"), nullable=True
    )
    cohort_id: Mapped[Optional[int]] = mapped_column(
        BigInteger, ForeignKey("cohorts.id"), nullable=True
    )
    late_to_absent_ratio: Mapped[int] = mapped_column(Integer, nullable=False, default=3)
    absent_limit: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    applied_from: Mapped[date] = mapped_column(Date, nullable=False)
    created_by: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
