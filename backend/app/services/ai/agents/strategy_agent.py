from langchain_core.messages import SystemMessage
from app.services.ai.state import AgentState
from app.services.ai.llm_client import get_llm
from app.services.ai.tools.cache_tool import set_cache
import logging

logger = logging.getLogger(__name__)

system_prompt = """당신은 EasyPlex AI의 전략 및 통계 전문 에이전트입니다.
오너/원장님의 요청에 따라 커리큘럼 성과, 수익률, 학생 성취도 통계 데이터를 분석하고 전략적 인사이트를 제공합니다.
논리적이고, 데이터에 기반하며, 통찰력 있는 전문가의 어조로 답변하세요.
항상 한국어로 답변하세요.
"""

async def strategy_agent_node(state: AgentState):
    logger.info("[Strategy Agent] 전략 및 통계 분석 처리 시작")
    messages = list(state.get("messages", []))
    role = state.get("sender_role", "owner")
    
    if not any(isinstance(m, SystemMessage) for m in messages):
        messages.insert(0, SystemMessage(content=system_prompt))
        
    # 창의성(전략 도출)을 위해 온도를 약간 올림
    llm = get_llm(temperature=0.5)
    
    response = await llm.ainvoke(messages)
    
    original_query = state.get("messages")[-1].content if state.get("messages") else ""
    if original_query:
        await set_cache(original_query, response.content, role=role)

    return {"messages": [response]}
