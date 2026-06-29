from fastapi import APIRouter, Body, Depends
from pydantic import BaseModel
import logging
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import re

from app.api.deps import get_db
from app.models.faq import FAQItem
from app.models.ops import OpsTicket
from app.models.tech_support_chat import TechTicket, TechMessage
from app.models.instructor_models import InstructorTicket

# 기본 로거 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("StudentSupportAPI")

router = APIRouter()

class SupportMessageRequest(BaseModel):
    mode: str  # 'faq', 'ops', 'tech', 'instructor'
    message: str
    student_name: str = "Current Student" # 임시 사용자 식별용

@router.get("/faqs")
async def get_faqs(db: AsyncSession = Depends(get_db)):
    """
    RAG용 FAQ 리스트를 반환합니다.
    """
    result = await db.execute(select(FAQItem))
    faqs = result.scalars().all()
    
    return {
        "status": "success",
        "data": [
            {
                "id": faq.id,
                "category": faq.category,
                "question": faq.question,
                "answer": faq.answer
            }
            for faq in faqs
        ]
    }

@router.post("/seed-faqs")
async def seed_faqs(db: AsyncSession = Depends(get_db)):
    """
    개발용 더미 FAQ 데이터 및 벡터 플레이스홀더를 PostgreSQL에 시드합니다.
    """
    # 이미 데이터가 있는지 확인
    result = await db.execute(select(FAQItem))
    existing = result.scalars().first()
    
    if existing:
        return {"status": "success", "message": "FAQ data already exists."}
        
    dummy_faqs = [
        FAQItem(
            category="general",
            question="외출 몇 시간까지 가능한가요?",
            answer="고용24 및 플랫폼 지침에 따라 일일 최대 2시간까지 외출 및 조퇴가 가능합니다. 이를 초과하면 결석으로 처리될 수 있으니 주의해 주세요!",
            embedding=[0.1, 0.2, 0.3, 0.4] # Placeholder vector
        ),
        FAQItem(
            category="general",
            question="출석 체크는 언제 하나요?",
            answer="입실 체크는 수업 시작 전 10분 이내, 퇴실 체크는 세션이 종료된 직후 메인 화면의 QR 코드 위젯을 통해 바로 완료하셔야 합니다.",
            embedding=[0.5, 0.6, 0.7, 0.8] # Placeholder vector
        ),
        FAQItem(
            category="general",
            question="장비(노트북) 대여는 어떻게 하나요?",
            answer="운영팀에 장비 대여 신청서를 제출하시면, 재고 확인 후 당일 내로 대여가 가능합니다. Tech Support 메뉴를 이용해주세요.",
            embedding=[0.9, 0.1, 0.2, 0.3] # Placeholder vector
        )
    ]
    
    db.add_all(dummy_faqs)
    await db.commit()
    
    return {"status": "success", "message": f"{len(dummy_faqs)} FAQs seeded successfully."}

@router.get("/tickets")
async def get_student_tickets(student_name: str = "Current Student", db: AsyncSession = Depends(get_db)):
    """
    특정 수강생의 Ops 티켓 목록을 반환합니다.
    (채팅 모달에서 답변 업데이트를 폴링할 때 사용)
    """
    result = await db.execute(select(OpsTicket).where(OpsTicket.student_name == student_name).order_by(OpsTicket.created_at.desc()))
    tickets = result.scalars().all()
    
    return {
        "status": "success",
        "data": [
            {
                "id": t.id,
                "message": t.message,
                "status": t.status,
                "reply": t.reply,
                "created_at": t.created_at,
                "replied_at": t.replied_at
            }
            for t in tickets
        ]
    }

@router.post("/message")
async def handle_support_message(request: SupportMessageRequest, db: AsyncSession = Depends(get_db)):
    logger.info(f"Received support message. Mode: {request.mode}, Message: {request.message}")
    
    # 모드별 처리 로직 (실제 배포 시에는 DB 연동 및 WebSocket/소켓 연동)
    if request.mode == "faq":
        # 우선 DB에서 일치하는 FAQ가 있는지 검색합니다.
        result = await db.execute(select(FAQItem).where(FAQItem.question == request.message))
        faq = result.scalars().first()
        
        if faq:
            return {
                "status": "success",
                "reply": faq.answer,
                "sender": "ai"
            }
        
        # 일치하는 항목이 없을 경우의 폴백(추후 LLM RAG 로직으로 대체됨)
        return {
            "status": "success",
            "reply": "질문하신 내용에 대한 정확한 답변을 찾지 못했습니다. 조금 다르게 질문해 주시거나 운영팀 채널을 이용해 주세요.",
            "sender": "ai"
        }
        
    elif request.mode == "ops":
        # 운영팀 채팅 처리 (단일 스레드처럼 작동하지만 DB는 텍스트 누적)
        category_match = re.match(r"^\[(.*?)\]", request.message)
        
        # 해당 학생의 열려있는 OpsTicket 찾기
        result = await db.execute(select(OpsTicket).where(OpsTicket.student_name == request.student_name).order_by(OpsTicket.created_at.desc()))
        ticket = result.scalars().first()
        
        if not ticket or ticket.status != "pending" or category_match:
            # 새로 생성
            new_ticket = OpsTicket(
                student_name=request.student_name,
                message=request.message,
                status="pending"
            )
            db.add(new_ticket)
            await db.commit()
            await db.refresh(new_ticket)
            logger.info(f"[EduOps Ticket Created] Issue: {request.message}")
            final_ticket_id = new_ticket.id
        else:
            # 기존 티켓에 메시지 추가 (채팅 연속성)
            ticket.message += f"\n\n[추가 문의]\n{request.message}"
            db.add(ticket)
            await db.commit()
            logger.info(f"[EduOps Ticket Updated] appended to ticket #{ticket.id}")
            final_ticket_id = ticket.id
            
        return {
            "status": "success",
            "reply": f"메시지가 운영팀에 성공적으로 접수되었습니다. (티켓 #{final_ticket_id}) 담당자가 곧 확인 후 답변해 드리겠습니다.",
            "sender": "system"
        }
        
    elif request.mode == "tech":
        # 기술지원팀 실시간 채팅 처리
        category_match = re.match(r"^\[(.*?)\]", request.message)
        
        # 해당 학생의 열려있는 TechTicket 찾기
        result = await db.execute(select(TechTicket).where(TechTicket.student_name == request.student_name).order_by(TechTicket.created_at.desc()))
        ticket = result.scalars().first()
        
        # 진행 중인 티켓이 없거나, 해결되었거나, 사용자가 새로운 카테고리(제목)를 지정하여 보낸 경우 새 티켓 생성
        if not ticket or ticket.status == "resolved" or category_match:
            # 새로 생성
            ticket = TechTicket(student_name=request.student_name, issue_summary=request.message[:50])
            db.add(ticket)
            await db.commit()
            await db.refresh(ticket)
            
        new_msg = TechMessage(
            ticket_id=ticket.id,
            sender_type="student",
            sender_name=request.student_name,
            message=request.message
        )
        db.add(new_msg)
        await db.commit()
        
        logger.warning(f"[TechOps Alert] Real-time request stored: {request.message}")
        return {
            "status": "success",
            "reply": "[Tech Support System] 메시지가 기술지원팀에 전송되었습니다. 담당 엔지니어가 곧 답변해 드릴 예정입니다...",
            "sender": "system"
        }
        
    elif request.mode == "instructor":
        # 강사진/멘토 채팅 처리 (게시판형 연속성)
        category_match = re.match(r"^\[(.*?)\]", request.message)
        
        # 해당 학생의 열려있는 InstructorTicket 찾기
        result = await db.execute(select(InstructorTicket).where(InstructorTicket.student_name == request.student_name).order_by(InstructorTicket.created_at.desc()))
        ticket = result.scalars().first()
        
        if not ticket or ticket.status != "pending" or category_match:
            # 새로 생성
            new_ticket = InstructorTicket(
                student_name=request.student_name,
                message=request.message,
                status="pending"
            )
            db.add(new_ticket)
            await db.commit()
            await db.refresh(new_ticket)
            logger.info(f"[Instructor Ticket Created] Question: {request.message}")
            final_ticket_id = new_ticket.id
        else:
            # 기존 티켓에 메시지 추가 (채팅 연속성)
            ticket.message += f"\n\n[추가 문의]\n{request.message}"
            db.add(ticket)
            await db.commit()
            logger.info(f"[Instructor Ticket Updated] appended to ticket #{ticket.id}")
            final_ticket_id = ticket.id
            
        return {
            "status": "success",
            "reply": f"질문이 강사진 및 멘토 대시보드에 등록되었습니다. (티켓 #{final_ticket_id}) 확인 후 순차적으로 답변을 드릴 예정입니다.",
            "sender": "system"
        }
        
    else:
        return {"status": "error", "message": "Invalid support mode"}

@router.get("/tech-messages")
async def get_tech_messages(student_name: str, db: AsyncSession = Depends(get_db)):
    """
    특정 학생의 모든 TechTicket에 달린 메시지 목록을 시간순으로 반환 (학생 팝업에서 폴링)
    """
    msg_result = await db.execute(
        select(TechMessage)
        .join(TechTicket, TechMessage.ticket_id == TechTicket.id)
        .where(TechTicket.student_name == student_name)
        .order_by(TechMessage.created_at.asc())
    )
    messages = msg_result.scalars().all()
    
    return {
        "status": "success",
        "data": [
            {
                "id": m.id,
                "sender": "student" if m.sender_type == "student" else "tech",
                "content": m.message,
                "timestamp": m.created_at.isoformat()
            }
            for m in messages
        ]
    }

@router.get("/instructor-tickets")
async def get_instructor_tickets(student_name: str = "Current Student", db: AsyncSession = Depends(get_db)):
    """
    특정 학생의 Instructor Q&A 목록 조회 (학생 팝업에서 폴링)
    """
    result = await db.execute(select(InstructorTicket).where(InstructorTicket.student_name == student_name).order_by(InstructorTicket.created_at.desc()))
    tickets = result.scalars().all()
    
    return {
        "status": "success",
        "data": [
            {
                "id": t.id,
                "message": t.message,
                "status": t.status,
                "reply": t.reply,
                "replied_by": t.replied_by,
                "created_at": t.created_at,
                "replied_at": t.replied_at
            }
            for t in tickets
        ]
    }
