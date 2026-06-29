from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
import logging
from sqlalchemy.sql import func

from app.api.deps import get_db, get_current_user
from app.models.instructor_models import InstructorTicket
from app.models.auth import User
from app.services.notification_service import create_notification_by_name
from app.models.notification import NotificationType

router = APIRouter()
logger = logging.getLogger("InstructorQuestionsAPI")

class ReplyRequest(BaseModel):
    reply: str

@router.get("/tickets")
async def get_instructor_tickets(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    """
    강사 및 멘토가 학생들의 질문(Ticket) 목록을 조회합니다.
    """
    from app.models.auth import UserRole
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR]:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    result = await db.execute(select(InstructorTicket).order_by(InstructorTicket.created_at.desc()))
    tickets = result.scalars().all()
    
    return {
        "status": "success",
        "data": [
            {
                "id": t.id,
                "student": t.student_name,
                "issue": t.message,
                "status": t.status,
                "reply": t.reply,
                "replied_by": t.replied_by,
                "created_at": t.created_at,
                "replied_at": t.replied_at
            }
            for t in tickets
        ]
    }

@router.post("/tickets/{ticket_id}/reply")
async def reply_to_ticket(
    ticket_id: int, 
    req: ReplyRequest, 
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    강사 또는 멘토가 질문에 답변을 작성합니다.
    """
    from app.models.auth import UserRole
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR]:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    result = await db.execute(select(InstructorTicket).where(InstructorTicket.id == ticket_id))
    ticket = result.scalars().first()
    
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
        
    # 기존 답변이 있으면 누적(이어붙이기), 없으면 새로 작성
    from app.models.auth import UserRole
    role_label = 'Instructor' if current_user.role == UserRole.INSTRUCTOR else 'Mentor'
    user_name = current_user.full_name or 'Unknown'
    reply_header = f"[{role_label} {user_name}]"
    
    if ticket.reply:
        ticket.reply += f"\n\n{reply_header}\n{req.reply}"
    else:
        ticket.reply = f"{reply_header}\n{req.reply}"
        
    ticket.status = "answered"
    ticket.replied_by = user_name
    ticket.replied_at = func.now()
    
    db.add(ticket)
    await db.commit()
    
    # 수강생에게 알림 전송
    await create_notification_by_name(
        db=db,
        student_name=ticket.student_name,
        title=f"강사진({user_name})이 답변을 남겼습니다.",
        message=f"질문에 대한 답변이 등록되었습니다: {req.reply[:20]}...",
        type=NotificationType.MESSAGE,
        link="/student/helpbot" # 봇 또는 문의내역 페이지로 연결
    )
    
    logger.info(f"[{role_label} Reply] Ticket #{ticket.id} answered by {user_name}")
    
    return {"status": "success", "message": "Reply sent successfully"}
