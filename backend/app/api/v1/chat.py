import json
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from jose import JWTError
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import async_session_factory, get_db
from app.core.deps import get_current_user, require_roles
from app.core.security import decode_access_token
from app.models.auth import User
from app.models.board import ChatChannel, ChatMessage
from app.schemas.common import ok, paginated


class ChannelCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    type: str = "cohort"  # cohort | class | free
    cohort_id: int
    class_id: Optional[int] = None


async def _sender_names(db: AsyncSession, sender_ids: set[int]) -> dict[int, str]:
    """Maps user id → display name for chat message authorship."""
    if not sender_ids:
        return {}
    rows = await db.execute(select(User.id, User.name).where(User.id.in_(sender_ids)))
    return {uid: name for uid, name in rows.all()}

router = APIRouter(prefix="/chat", tags=["chat"])

# channel_id → list of (user_id, WebSocket).
# Single-process only. For multi-worker / horizontal scaling,
# replace with Redis Pub/Sub (e.g. via redis-py or broadcaster).
_channel_connections: dict[int, list[tuple[int, WebSocket]]] = {}


@router.get("/channels", response_model=dict)
async def list_channels(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    cohort_id: Optional[int] = None,
):
    query = select(ChatChannel).where(
        ChatChannel.cohort_id == (cohort_id or current_user.cohort_id),
        ChatChannel.is_active == True,
    )
    result = await db.execute(query)
    channels = result.scalars().all()
    return ok([
        {
            "id": c.id,
            "name": c.name,
            "type": c.type,
            "cohort_id": c.cohort_id,
            "class_id": c.class_id,
        }
        for c in channels
    ])


@router.post("/channels", response_model=dict)
async def create_channel(
    body: ChannelCreate,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    channel = ChatChannel(
        institution_id=current_user.institution_id,
        cohort_id=body.cohort_id,
        class_id=body.class_id,
        name=body.name,
        type=body.type,
        is_active=True,
    )
    db.add(channel)
    await db.commit()
    await db.refresh(channel)
    return ok({
        "id": channel.id,
        "name": channel.name,
        "type": channel.type,
        "cohort_id": channel.cohort_id,
        "class_id": channel.class_id,
    })


@router.get("/channels/{channel_id}/messages", response_model=dict)
async def list_messages(
    channel_id: int,
    _: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    page: int = 1,
    size: int = 50,
):
    from sqlalchemy import func
    query = select(ChatMessage).where(
        ChatMessage.channel_id == channel_id,
        ChatMessage.deleted_at.is_(None),
    )
    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(ChatMessage.created_at)
    )
    messages = result.scalars().all()
    names = await _sender_names(db, {m.sender_id for m in messages})
    return paginated(
        [
            {
                "id": m.id,
                "sender_id": m.sender_id,
                "sender_name": names.get(m.sender_id, f"사용자 {m.sender_id}"),
                "content": m.content,
                "attachments": m.attachments,
                "created_at": m.created_at.isoformat(),
            }
            for m in messages
        ],
        page,
        size,
        total,
    )


@router.websocket("/ws")
async def chat_ws(websocket: WebSocket, token: str, channel_id: int):
    try:
        payload = decode_access_token(token)
        user_id = int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        await websocket.close(code=4001)
        return

    await websocket.accept()
    _channel_connections.setdefault(channel_id, []).append((user_id, websocket))

    # Resolve the sender's display name once for this connection.
    async with async_session_factory() as db:
        sender_name = (await _sender_names(db, {user_id})).get(
            user_id, f"사용자 {user_id}"
        )

    try:
        while True:
            raw = await websocket.receive_text()

            # Accept either plain text (legacy) or a JSON envelope
            # {"content": str, "attachments": [ {url,name,content_type,...} ]}
            # so clients can send images/files alongside text.
            content = raw
            attachments = None
            try:
                parsed = json.loads(raw)
                if isinstance(parsed, dict) and (
                    "content" in parsed or "attachments" in parsed
                ):
                    content = str(parsed.get("content") or "")
                    att = parsed.get("attachments")
                    if isinstance(att, list) and att:
                        attachments = {"items": att}
            except (ValueError, TypeError):
                pass  # not JSON → treat as plain text

            async with async_session_factory() as db:
                from datetime import datetime, timezone
                message = ChatMessage(
                    channel_id=channel_id,
                    sender_id=user_id,
                    content=content,
                    attachments=attachments,
                    created_at=datetime.now(timezone.utc),
                )
                db.add(message)
                await db.commit()
                await db.refresh(message)

            payload_out = {
                "type": "message",
                "data": {
                    "id": message.id,
                    "sender_id": user_id,
                    "sender_name": sender_name,
                    "content": content,
                    "attachments": attachments,
                    "created_at": message.created_at.isoformat(),
                },
            }
            for uid, ws in _channel_connections.get(channel_id, []):
                try:
                    await ws.send_json(payload_out)
                except Exception:
                    pass
    except WebSocketDisconnect:
        conns = _channel_connections.get(channel_id, [])
        _channel_connections[channel_id] = [
            (uid, ws) for uid, ws in conns if ws is not websocket
        ]
