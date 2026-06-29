from langchain_core.messages import SystemMessage
from app.services.ai.state import AgentState
from app.services.ai.llm_client import get_llm
from app.services.ai.tools.cache_tool import set_cache
import logging

logger = logging.getLogger(__name__)

system_prompt = """당신은 EasyPlex AI의 행정 및 기술 운영 에이전트입니다.
운영팀(EduOps) 및 기술팀(TechOps)의 시스템 모니터링 로그, 장비 상태 요약, 학생 출결/등록 데이터 요약 요청 등을 처리합니다.
장황하게 설명하지 말고, 빠르고 명확하게 핵심 요약 정보만 불릿 포인트(Bullet points)로 정리하여 답변하세요.
항상 한국어로 답변하세요.
"""

async def admin_agent_node(state: AgentState):
    logger.info("[Admin Agent] 행정 데이터 및 운영 상태 요약 처리 시작")
    messages = list(state.get("messages", []))
    role = state.get("sender_role", "admin")
    
    if not any(isinstance(m, SystemMessage) for m in messages):
        messages.insert(0, SystemMessage(content=system_prompt))
        
    # 사실에 기반한 요약을 위해 온도를 0으로 고정
    llm = get_llm(temperature=0.0)
    
    response = await llm.ainvoke(messages)
    
    original_query = state.get("messages")[-1].content if state.get("messages") else ""
    if original_query:
        await set_cache(original_query, response.content, role=role)

    return {"messages": [response]}
