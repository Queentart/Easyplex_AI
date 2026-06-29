from langgraph.graph import StateGraph, START, END
from app.services.ai.state import AgentState
from app.services.ai.agents.supervisor import supervisor_node
from app.services.ai.agents.qna_agent import qna_agent_node
from app.services.ai.agents.grading_agent import grading_agent_node
from app.services.ai.agents.strategy_agent import strategy_agent_node
from app.services.ai.agents.admin_agent import admin_agent_node
import logging

logger = logging.getLogger(__name__)

def route_from_supervisor(state: AgentState):
    """Supervisor 노드가 반환한 next 키 값을 기반으로 다음 실행할 에이전트(노드)를 결정합니다."""
    return state.get("next", "END")

# 1. StateGraph 초기화
workflow = StateGraph(AgentState)

# 2. 노드 추가
workflow.add_node("supervisor", supervisor_node)
workflow.add_node("qna_agent", qna_agent_node)
workflow.add_node("grading_agent", grading_agent_node)
workflow.add_node("strategy_agent", strategy_agent_node)
workflow.add_node("admin_agent", admin_agent_node)

# 3. 엣지 연결 (워크플로우 흐름)
# 무조건 Supervisor가 가장 먼저 시작되어 캐시 확인 및 라우팅을 담당합니다.
workflow.add_edge(START, "supervisor")

# Supervisor의 라우팅 결정(next 값)에 따라 엣지가 조건부 분기됩니다.
workflow.add_conditional_edges(
    "supervisor",
    route_from_supervisor,
    {
        "qna_agent": "qna_agent",
        "grading_agent": "grading_agent",
        "strategy_agent": "strategy_agent",
        "admin_agent": "admin_agent",
        "END": END  # 캐시 히트 시 즉시 종료
    }
)

# 각 하위 전문 에이전트들의 작업(추론 및 캐시 저장)이 끝나면 워크플로우를 종료합니다.
workflow.add_edge("qna_agent", END)
workflow.add_edge("grading_agent", END)
workflow.add_edge("strategy_agent", END)
workflow.add_edge("admin_agent", END)

# 4. 워크플로우 컴파일
app_workflow = workflow.compile()
logger.info("LangGraph 멀티 에이전트 워크플로우(Supervisor 기반)가 성공적으로 컴파일되었습니다.")
