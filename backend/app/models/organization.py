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
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.base import TimestampMixin


class Institution(Base, TimestampMixin):
    __tablename__ = "institutions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    code: Mapped[str] = mapped_column(String(30), unique=True, nullable=False)
    contact_email: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    contact_phone: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    address: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    logo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    settings: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    cohorts: Mapped[list["Cohort"]] = relationship(back_populates="institution")


class Cohort(Base, TimestampMixin):
    __tablename__ = "cohorts"
    __table_args__ = (
        UniqueConstraint("institution_id", "code", name="uq_cohorts_institution_code"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    institution_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("institutions.id"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    code: Mapped[str] = mapped_column(String(30), nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    total_hours: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    # Per-cohort excused-leave allowance (total days). NULL = not configured
    # (UI shows "한도 미설정"). A single day count, not per-type.
    leave_allowance_days: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="planned"
    )  # planned, ongoing, completed, archived

    institution: Mapped["Institution"] = relationship(back_populates="cohorts")
    instructor_cohorts: Mapped[list["InstructorCohort"]] = relationship(
        back_populates="cohort"
    )


class InstructorCohort(Base):
    __tablename__ = "instructor_cohorts"
    __table_args__ = (
        UniqueConstraint(
            "instructor_id", "cohort_id", name="uq_instructor_cohort"
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    instructor_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id"), nullable=False
    )
    cohort_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("cohorts.id"), nullable=False
    )
    assigned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    assigned_by: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id"), nullable=False
    )

    cohort: Mapped["Cohort"] = relationship(back_populates="instructor_cohorts")
