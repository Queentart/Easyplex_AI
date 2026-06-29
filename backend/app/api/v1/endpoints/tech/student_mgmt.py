from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
import logging

from app.api.deps import get_db
from app.models.tech_support_chat import TechTicket, TechMessage
from app.services.notification_service import create_notification_by_name
from app.models.notification import NotificationType

router = APIRouter()
logger = logging.getLogger("TechOpsStudentMgmt")

class AdminReplyRequest(BaseModel):
    message: str
    admin_name: str = "Tech Admin"

@router.get("/tickets")
async def get_tech_tickets(db: AsyncSession = Depends(get_db)):
    """
    기술지원팀 대시보드에서 볼 수 있는 전체 TechTicket 목록
    """
    result = await db.execute(select(TechTicket).order_by(TechTicket.created_at.desc()))
    tickets = result.scalars().all()
    
    return {
        "status": "success",
        "data": [
            {
                "id": t.id,
                "student": t.student_name,
                "issue": t.issue_summary,
                "priority": t.priority,
                "status": t.status,
                "date": t.created_at.isoformat() if t.created_at else None
            }
            for t in tickets
        ]
    }

@router.get("/tickets/{ticket_id}/messages")
async def get_ticket_messages(ticket_id: int, db: AsyncSession = Depends(get_db)):
    """
    특정 TechTicket의 채팅 내역
    """
    result = await db.execute(select(TechMessage).where(TechMessage.ticket_id == ticket_id).order_by(TechMessage.created_at.asc()))
    messages = result.scalars().all()
    
    return {
        "status": "success",
        "data": [
            {
                "id": m.id,
                "sender_type": m.sender_type,
                "sender_name": m.sender_name,
                "message": m.message,
                "timestamp": m.created_at.isoformat() if m.created_at else None
            }
            for m in messages
        ]
    }

@router.post("/tickets/{ticket_id}/messages")
async def send_admin_reply(ticket_id: int, request: AdminReplyRequest, db: AsyncSession = Depends(get_db)):
    """
    관리자가 특정 학생의 기술지원 티켓에 답변 전송
    """
    # 티켓 확인
    result = await db.execute(select(TechTicket).where(TechTicket.id == ticket_id))
    ticket = result.scalars().first()
    if not ticket:
        return {"status": "error", "message": "Ticket not found"}
        
    # 상태를 in_progress로 변경
    if ticket.status == "open":
        ticket.status = "in_progress"
        
    new_msg = TechMessage(
        ticket_id=ticket.id,
        sender_type="admin",
        sender_name=request.admin_name,
        message=request.message
    )
    db.add(new_msg)
    await db.commit()
    
    # 수강생에게 알림 전송
    await create_notification_by_name(
        db=db,
        student_name=ticket.student_name,
        title=f"기술팀({request.admin_name})에서 답변을 남겼습니다.",
        message=f"기술지원 티켓에 대한 답변이 등록되었습니다: {request.message[:20]}...",
        type=NotificationType.MESSAGE,
        link="/student/helpbot" # 봇 또는 문의내역 페이지로 연결
    )
    
    return {
        "status": "success",
        "message": "Reply sent"
    }
