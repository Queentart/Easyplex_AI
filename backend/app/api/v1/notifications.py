from typing import Annotated, Optional

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.security import decode_access_token
from app.models.auth import User
from app.schemas.common import ok, paginated
from app.services import notification as notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])

# In-memory connection registry keyed by user_id.
# Single-process only. For multi-worker / horizontal scaling,
# replace with Redis Pub/Sub (e.g. via redis-py or broadcaster).
_connections: dict[int, list[WebSocket]] = {}


@router.get("/", response_model=dict)
async def list_notifications(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    is_read: Optional[bool] = None,
    page: int = 1,
    size: int = 20,
):
    notifications, total, unread_count = await notification_service.list_notifications(
        db, current_user.id, is_read=is_read, page=page, size=size
    )
    return {
        "data": [n.model_dump() for n in notifications],
        "meta": {"page": page, "size": size, "total": total, "unread_count": unread_count},
        "error": None,
    }


@router.post("/{notification_id}/read", response_model=dict)
async def mark_read(
    notification_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    notification = await notification_service.mark_read(db, notification_id, current_user.id)
    return ok(notification.model_dump())


@router.post("/read-all", response_model=dict)
async def mark_all_read(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    marked = await notification_service.mark_all_read(db, current_user.id)
    return ok({"marked": marked})


@router.websocket("/ws")
async def notifications_ws(websocket: WebSocket, token: str):
    try:
        payload = decode_access_token(token)
        user_id = int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        await websocket.close(code=4001)
        return

    await websocket.accept()
    _connections.setdefault(user_id, []).append(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        _connections[user_id].remove(websocket)


async def push_notification(user_id: int, data: dict) -> None:
    for ws in _connections.get(user_id, []):
        try:
            await ws.send_json({"type": "notification", "data": data})
        except Exception:
            pass
