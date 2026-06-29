from typing import Literal
from langchain_core.messages import SystemMessage, HumanMessage, AIMessage
from pydantic import BaseModel, Field
from app.services.ai.state import AgentState
from app.services.ai.llm_client import get_llm
from app.services.ai.tools.cache_tool import check_semantic_cache
import logging

logger = logging.getLogger(__name__)

class Router(BaseModel):
    """라우팅 대상(다음 노드)을 결정합니다."""
    next: Literal["qna_agent", "grading_agent", "strategy_agent", "admin_agent"] = Field(
        description="다음에 실행할 에이전트 노드"
    )

system_prompt = """당신은 EasyPlex AI의 수석 라우터(Supervisor)입니다. 
다음 역할과 업무에 따라 사용자의 질문을 가장 잘 처리할 수 있는 하위 에이전트를 선택해야 합니다.

- qna_agent: 일반적인 학습 관련 질문, 시스템 안내, 단순 인사, FAQ 응답
- grading_agent: 강사진의 과제 채점, 시험 평가, 학생 피드백 관련
- strategy_agent: 오너/원장의 커리큘럼 최적화, 수익률 예측, 성적 통계 분석
- admin_agent: 운영팀/기술팀의 데이터 요약, 행정 업무 자동화, 장비 상태 요약

사용자의 역할(role)과 이전 대화 맥락을 참고하여 반드시 위 4가지 에이전트 중 하나를 선택하세요.
어디에 속하는지 애매하다면 'qna_agent'를 선택하세요.
"""

async def supervisor_node(state: AgentState):
    """
    1. Redis 캐시를 가장 먼저 확인하여 히트 시 즉각 반환 (VRAM 점유 0)
    2. 캐시 미스 시, LLM(keep_alive=0)을 사용해 요청을 분석하고 담당 에이전트에게 라우팅
    """
    messages = state.get("messages", [])
    if not messages:
        return {"next": "qna_agent", "is_cached": False}
        
    last_message = messages[-1].content
    role = state.get("sender_role", "student")
    
    logger.info(f"[Supervisor] 라우팅 분석 시작 (Role: {role}, Query: {last_message[:20]}...)")
    
    # 1. Redis 캐시 확인 (ainvoke 사용)
    cache_result = await check_semantic_cache.ainvoke({"query": last_message, "role": role})
    
    if "[CACHE_HIT]" in cache_result:
        cached_content = cache_result.replace("[CACHE_HIT]", "").strip()
        logger.info("[Supervisor] Cache Hit! LLM 호출 없이 즉시 종료합니다.")
        
        # 캐시된 답변을 시스템에서 대신 대답한 것처럼 가공
        return {
            "messages": [AIMessage(content=cached_content, name="Cache")],
            "next": "END", # langgraph.graph.END 노드로 라우팅
            "is_cached": True
        }

    logger.info("[Supervisor] Cache Miss. LLM을 통한 에이전트 라우팅을 진행합니다.")

    # 2. 캐시 미스인 경우, LLM을 사용해 라우팅 (VRAM 즉시 반환 보장)
    llm = get_llm(temperature=0.0)
    
    # Pydantic을 사용하여 강제로 JSON 스키마에 맞춰 응답하도록 제한 (Tool Use 기능)
    structured_llm = llm.with_structured_output(Router)
    
    routing_messages = [
        SystemMessage(content=system_prompt),
        HumanMessage(content=f"[요청자 역할: {role}] 사용자의 질문: {last_message}")
    ]
    
    try:
        # LLM 추론 수행 및 구조화된 결과 파싱
        response = await structured_llm.ainvoke(routing_messages)
        next_agent = response.next
    except Exception as e:
        logger.warning(f"라우팅 실패, 기본 qna_agent로 폴백합니다. Error: {str(e)}")
        next_agent = "qna_agent"
    
    logger.info(f"[Supervisor] 라우팅 결정 완료: {next_agent}")
    
    return {
        "next": next_agent,
        "is_cached": False
    }
