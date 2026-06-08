"""add missing indexes

Revision ID: 0002
Revises: 0001
Create Date: 2026-05-26 00:00:00.000000
"""
from __future__ import annotations

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # refresh_tokens: token_hash is looked up on every refresh/logout
    op.create_index("ix_refresh_tokens_token_hash", "refresh_tokens", ["token_hash"])

    # refresh_tokens: find all tokens for a user (revocation / cleanup)
    op.create_index("ix_refresh_tokens_user_id", "refresh_tokens", ["user_id"])

    # posts: primary list query (by board, excluding soft-deleted)
    op.create_index(
        "ix_posts_board_deleted",
        "posts",
        ["board_id", "deleted_at"],
    )

    # submissions: look up a student's submission for an assignment (UPSERT path)
    op.create_index(
        "ix_submissions_assignment_student",
        "submissions",
        ["assignment_id", "student_id"],
    )

    # leave_requests: list by student or cohort
    op.create_index("ix_leave_requests_student_id", "leave_requests", ["student_id"])
    op.create_index("ix_leave_requests_cohort_id", "leave_requests", ["cohort_id"])

    # audit_logs: search by actor or action type
    op.create_index("ix_audit_logs_actor_action", "audit_logs", ["actor_id", "action"])


def downgrade() -> None:
    op.drop_index("ix_audit_logs_actor_action", table_name="audit_logs")
    op.drop_index("ix_leave_requests_cohort_id", table_name="leave_requests")
    op.drop_index("ix_leave_requests_student_id", table_name="leave_requests")
    op.drop_index("ix_submissions_assignment_student", table_name="submissions")
    op.drop_index("ix_posts_board_deleted", table_name="posts")
    op.drop_index("ix_refresh_tokens_user_id", table_name="refresh_tokens")
    op.drop_index("ix_refresh_tokens_token_hash", table_name="refresh_tokens")
