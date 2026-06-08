from __future__ import annotations

import asyncio
import csv
import io
import uuid
from datetime import datetime, timezone

from app.workers.celery_app import celery_app


@celery_app.task(name="attendance.process_csv_import")
def process_csv_import(
    file_key: str,
    file_name: str,
    cohort_id: int,
    institution_id: int,
    uploader_id: int,
    dry_run: bool = False,
) -> dict:
    batch_id = str(uuid.uuid4())
    imported = 0
    failed = 0
    errors: list[dict] = []

    return {
        "batch_id": batch_id,
        "imported": imported,
        "failed": failed,
        "errors": errors,
        "status": "dry_run" if dry_run else "confirmed",
    }
