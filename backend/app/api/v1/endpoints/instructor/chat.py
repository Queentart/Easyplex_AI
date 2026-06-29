from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List, Any
from app.api.deps import get_db
from app.models.instructor_models import ChatMessage
import json

router = APIRouter()

# 임시 메모리 기반 커넥션 매니저
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            await connection.send_text(message)

manager = ConnectionManager()

@router.get("/messages", response_model=List[Any])
async def get_chat_messages(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(ChatMessage).order_by(ChatMessage.created_at))
    msgs = result.scalars().all()
    return [{"id": m.id, "sender_id": m.sender_id, "receiver_id": m.receiver_id, "message": m.message, "is_read": m.is_read} for m in msgs]

@router.post("/messages")
async def send_message(sender_id: int, receiver_id: int, message: str, db: AsyncSession = Depends(get_db)):
    msg = ChatMessage(sender_id=sender_id, receiver_id=receiver_id, message=message)
    db.add(msg)
    await db.commit()
    await db.refresh(msg)
    
    # 웹소켓 브로드캐스트 (실제로는 특정 방이나 유저에게만 전송해야 함)
    await manager.broadcast(json.dumps({"sender_id": sender_id, "receiver_id": receiver_id, "message": message}))
    
    return {"message": "Message sent", "id": msg.id}

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            await manager.broadcast(f"New message: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)
