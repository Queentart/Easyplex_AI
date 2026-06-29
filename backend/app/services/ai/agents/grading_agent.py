from langchain_core.messages import SystemMessage
from app.services.ai.state import AgentState
from app.services.ai.llm_client import get_llm
from app.services.ai.tools.cache_tool import set_cache
import logging

logger = logging.getLogger(__name__)

system_prompt = """당신은 EasyPlex AI의 과제 채점 및 평가 전문 에이전트입니다.
강사진을 도와 학생들의 제출물을 분석하고, 채점 기준에 맞게 점수를 매기거나 피드백을 제공합니다.
칭찬할 부분과 보완할 부분을 나누어 공정하고 명확한 어조로 피드백을 작성하세요.
항상 한국어로 답변하세요.
"""

async def grading_agent_node(state: AgentState):
    logger.info("[Grading Agent] 과제/채점 평가 처리 시작")
    messages = list(state.get("messages", []))
    role = state.get("sender_role", "instructor")
    
    if not any(isinstance(m, SystemMessage) for m in messages):
        messages.insert(0, SystemMessage(content=system_prompt))
        
    # 평가의 일관성을 위해 온도를 낮춤
    llm = get_llm(temperature=0.1)
    
    response = await llm.ainvoke(messages)
    
    original_query = state.get("messages")[-1].content if state.get("messages") else ""
    if original_query:
        await set_cache(original_query, response.content, role=role)

    return {"messages": [response]}
