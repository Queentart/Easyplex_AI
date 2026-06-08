from celery import Celery

from app.core.config import settings

celery_app = Celery(
    "dongaai",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=[
        "app.workers.tasks.attendance",
        "app.workers.tasks.notifications",
    ],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="Asia/Seoul",
    enable_utc=True,
    task_track_started=True,
)
