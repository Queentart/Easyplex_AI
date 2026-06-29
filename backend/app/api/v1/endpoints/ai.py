from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from langchain_core.messages import HumanMessage
from app.services.ai.workflow import app_workflow
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

class ChatRequest(BaseModel):
    query: str
    role: str = "guest"  # student, instructor, admin, owner 등 역할

class ChatResponse(BaseModel):
    answer: str
    is_cached: bool
    agent_used: str

@router.post("/chat", response_model=ChatResponse)
async def chat_with_ai(request: ChatRequest):
    """
    사용자의 질문과 역할을 받아 Multi-Agent 워크플로우(LangGraph)로 전달하고 답변을 반환합니다.
    """
    # 1. 초기 상태(State) 설정
    initial_state = {
        "messages": [HumanMessage(content=request.query)],
        "sender_role": request.role,
        "is_cached": False,
        "next": ""
    }
    
    try:
        # 2. 워크플로우 비동기 실행
        # app_workflow는 supervisor를 거쳐 적절한 agent로 라우팅되거나 캐시를 반환합니다.
        result = await app_workflow.ainvoke(initial_state)
        
        # 3. 최종 응답 데이터 추출
        final_message = result["messages"][-1].content
        is_cached = result.get("is_cached", False)
        
        # 캐시된 경우 'next'가 END이므로, 실제 캐시 히트임을 명시적으로 표기
        agent_used = "redis_cache" if is_cached else result.get("next", "unknown")
        
        return ChatResponse(
            answer=final_message,
            is_cached=is_cached,
            agent_used=agent_used
        )
        
    except Exception as e:
        logger.error(f"AI Chat 에러 발생: {str(e)}")
        raise HTTPException(status_code=500, detail="AI 에이전트 처리 중 오류가 발생했습니다.")
