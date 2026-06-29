from typing import Annotated, Literal, TypedDict
from langchain_core.messages import BaseMessage
from langgraph.graph import StateGraph, START, END
from langgraph.graph.message import add_messages

# 프로젝트 내부 모듈 (루트에서 실행 기준)
from app.core.llm import get_llm, get_reasoning_llm

class AgentState(TypedDict):
    # 메시지 이력 (add_messages 리듀서 사용)
    messages: Annotated[list[BaseMessage], add_messages]
    # 추가로 필요한 상태 (예: 학생 정보, 과제 식별자 등)
    context_type: str  # "grading", "counseling", "general" 등

def orchestrator_node(state: AgentState):
    """
    요청을 분석하고 어떤 에이전트(혹은 도구)가 필요한지 판단하는 오케스트레이터.
    현재는 판단 로직 대신 메인 LLM을 통해 바로 응답을 생성하는 구조로 단순화.
    차후 Tool Calling을 추가하여 분기(routing)할 수 있습니다.
    """
    messages = state.get("messages", [])
    # 메인 모델 (예: llama3-groq-tool-use)
    llm = get_llm()
    
    # keep_alive=0가 설정된 LLM 호출
    response = llm.invoke(messages)
    
    return {"messages": [response]}

def reasoning_node(state: AgentState):
    """
    깊은 분석이 필요한 작업(예: 채점 논리)을 수행하는 서브 에이전트.
    """
    messages = state.get("messages", [])
    # 추론 전용 모델 (예: deepseek-r1)
    llm = get_reasoning_llm()
    response = llm.invoke(messages)
    return {"messages": [response]}

# 1. StateGraph 인스턴스 생성
workflow = StateGraph(AgentState)

# 2. 노드(에이전트 역할) 추가
workflow.add_node("orchestrator", orchestrator_node)
workflow.add_node("reasoning", reasoning_node)

# 3. 라우팅 엣지 설정 로직 (조건부)
def route_logic(state: AgentState) -> Literal["reasoning", "__end__"]:
    # 단순히 context_type에 따라 라우팅하는 예시
    if state.get("context_type") == "grading":
        return "reasoning"
    return "__end__"

workflow.add_edge(START, "orchestrator")
workflow.add_conditional_edges(
    "orchestrator",
    route_logic,
    {
        "reasoning": "reasoning",
        "__end__": END
    }
)
workflow.add_edge("reasoning", END)

# 4. 컴파일하여 실행 가능한 애플리케이션 생성
agent_app = workflow.compile()
