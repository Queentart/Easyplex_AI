from langchain_core.messages import SystemMessage, ToolMessage
from app.services.ai.state import AgentState
from app.services.ai.llm_client import get_llm
from app.services.ai.tools.rag_tool import search_knowledge_base
from app.services.ai.tools.cache_tool import set_cache
import logging

logger = logging.getLogger(__name__)

system_prompt = """당신은 EasyPlex AI의 Q&A 담당 에이전트입니다.
주로 학생들의 학습 관련 질문, 학교 규정, 시스템 이용 방법 등에 대해 친절하고 정확하게 답변합니다.
필요하다면 지식 기반 검색 도구(search_knowledge_base)를 사용하여 정확한 정보를 찾아 답변하세요.
항상 한국어로 답변하세요.
"""

async def qna_agent_node(state: AgentState):
    logger.info("[QnA Agent] 질의 처리 시작")
    messages = list(state.get("messages", []))
    role = state.get("sender_role", "student")
    
    # 시스템 프롬프트 주입
    if not any(isinstance(m, SystemMessage) for m in messages):
        messages.insert(0, SystemMessage(content=system_prompt))
        
    # VRAM 절약형 LLM 호출 및 도구 바인딩
    llm = get_llm(temperature=0.3)
    llm_with_tools = llm.bind_tools([search_knowledge_base])
    
    # 1차 추론 (도구 호출 여부 판단)
    response = await llm_with_tools.ainvoke(messages)
    
    new_messages = [response]
    
    # 도구(Tool) 호출 로직
    if hasattr(response, 'tool_calls') and response.tool_calls:
        logger.info(f"[QnA Agent] Tool 호출 감지: {len(response.tool_calls)}개")
        tool_messages = []
        for tool_call in response.tool_calls:
            if tool_call["name"] == "search_knowledge_base":
                tool_result = await search_knowledge_base.ainvoke(tool_call["args"])
                tool_messages.append(ToolMessage(content=tool_result, tool_call_id=tool_call["id"]))
        
        new_messages.extend(tool_messages)
        
        # 도구 실행 결과를 바탕으로 최종 2차 추론 진행
        final_response = await llm.ainvoke(messages + new_messages)
        new_messages.append(final_response)
        final_content = final_response.content
    else:
        final_content = response.content

    # 새로운 답변을 캐시에 비동기로 저장 (다음 번 같은 질문이 올 때 VRAM 사용 방지)
    original_query = state.get("messages")[-1].content if state.get("messages") else ""
    if original_query:
        await set_cache(original_query, final_content, role=role)

    return {"messages": new_messages}
