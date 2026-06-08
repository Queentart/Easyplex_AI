"""courses and course_videos

Revision ID: 0003
Revises: 0002
Create Date: 2026-06-07 00:00:00.000000
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # courses
    op.create_table(
        "courses",
        sa.Column("id", sa.BigInteger(), nullable=False),
        sa.Column("cohort_id", sa.BigInteger(), nullable=False),
        sa.Column("instructor_id", sa.BigInteger(), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="active"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["cohort_id"], ["cohorts.id"]),
        sa.ForeignKeyConstraint(["instructor_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_courses_cohort_id", "courses", ["cohort_id"])

    # course_videos
    op.create_table(
        "course_videos",
        sa.Column("id", sa.BigInteger(), nullable=False),
        sa.Column("course_id", sa.BigInteger(), nullable=False),
        sa.Column("class_date", sa.Date(), nullable=False),
        sa.Column("title", sa.String(200), nullable=True),
        sa.Column("file_key", sa.String(500), nullable=False),
        sa.Column("original_filename", sa.String(255), nullable=True),
        sa.Column("content_type", sa.String(100), nullable=True),
        sa.Column("size_bytes", sa.BigInteger(), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("uploaded_by", sa.BigInteger(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["course_id"], ["courses.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["uploaded_by"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_course_videos_course_id", "course_videos", ["course_id"])
    op.create_index(
        "ix_course_videos_course_date",
        "course_videos",
        ["course_id", "class_date"],
    )


def downgrade() -> None:
    op.drop_index("ix_course_videos_course_date", table_name="course_videos")
    op.drop_index("ix_course_videos_course_id", table_name="course_videos")
    op.drop_table("course_videos")
    op.drop_index("ix_courses_cohort_id", table_name="courses")
    op.drop_table("courses")
