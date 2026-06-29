from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
import logging
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime

from app.api.deps import get_db
from app.models.ops import OpsTicket
from app.services.notification_service import create_notification_by_name
from app.models.notification import NotificationType

router = APIRouter()
logger = logging.getLogger("OpsInquiriesAPI")

class ReplyRequest(BaseModel):
    reply: str

@router.get("/")
async def get_all_inquiries(db: AsyncSession = Depends(get_db)):
    """
    운영팀에서 수강생이 남긴 모든 티켓(문의사항)을 조회합니다.
    """
    result = await db.execute(select(OpsTicket).order_by(OpsTicket.created_at.desc()))
    tickets = result.scalars().all()
    
    return {
        "status": "success",
        "data": [
            {
                "id": t.id,
                "student_name": t.student_name,
                "message": t.message,
                "status": t.status,
                "reply": t.reply,
                "created_at": t.created_at,
                "replied_at": t.replied_at
            }
            for t in tickets
        ]
    }

@router.post("/{ticket_id}/reply")
async def reply_to_inquiry(ticket_id: int, request: ReplyRequest, db: AsyncSession = Depends(get_db)):
    """
    운영팀이 특정 티켓에 답변을 답니다.
    """
    result = await db.execute(select(OpsTicket).where(OpsTicket.id == ticket_id))
    ticket = result.scalars().first()
    
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
        
    ticket.reply = request.reply
    ticket.status = "answered"
    ticket.replied_at = datetime.utcnow()
    
    await db.commit()
    await db.refresh(ticket)
    
    # 수강생에게 알림 전송
    await create_notification_by_name(
        db=db,
        student_name=ticket.student_name,
        title="운영팀에서 답변을 남겼습니다.",
        message=f"문의사항에 대한 답변이 등록되었습니다: {request.reply[:20]}...",
        type=NotificationType.MESSAGE,
        link="/student/helpbot" # 봇 또는 문의내역 페이지로 연결
    )
    
    logger.info(f"[Ops Ticket Replied] Ticket #{ticket.id}")
    
    return {
        "status": "success",
        "message": "Reply saved successfully.",
        "data": {
            "id": ticket.id,
            "status": ticket.status,
            "reply": ticket.reply,
            "replied_at": ticket.replied_at
        }
    }
