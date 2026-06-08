from datetime import datetime

from sqlalchemy import BigInteger, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class TenantMixin:
    institution_id: Mapped[int] = mapped_column(
        BigInteger,
        nullable=False,
        default=1,
        comment="기관 ID (MVP: 동아AI랩=1)",
    )
    cohort_id: Mapped[int | None] = mapped_column(
        BigInteger,
        nullable=True,
        comment="기수 ID (운영팀·기술지원팀은 NULL 가능)",
    )
