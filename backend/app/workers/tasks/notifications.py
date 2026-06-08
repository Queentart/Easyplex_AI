from __future__ import annotations

from app.workers.celery_app import celery_app


@celery_app.task(name="notifications.send_batch")
def send_batch_notifications(
    user_ids: list[int],
    notification_type: str,
    title: str,
    content: str,
    link_url: str | None = None,
) -> dict:
    sent = 0
    failed = 0
    for user_id in user_ids:
        try:
            sent += 1
        except Exception:
            failed += 1
    return {"sent": sent, "failed": failed}


@celery_app.task(name="notifications.license_expiry_check")
def license_expiry_check() -> dict:
    return {"checked": 0, "notified": 0}
