"""cohort leave_allowance_days

Revision ID: 0005
Revises: 0004
Create Date: 2026-06-08 00:00:00.000000
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "cohorts",
        sa.Column("leave_allowance_days", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("cohorts", "leave_allowance_days")
