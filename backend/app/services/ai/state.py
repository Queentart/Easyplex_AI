from typing import Annotated, Sequence, TypedDict, Optional
from langchain_core.messages import BaseMessage
from langgraph.graph.message import add_messages

class AgentState(TypedDict):
    """
    LangGraph 워크플로우의 노드 간 데이터를 주고받기 위한 전역 상태(State) 스키마입니다.
    """
    # 사용자의 입력 및 에이전트들의 응답 메시지 기록
    # add_messages: 메시지 리스트를 덮어쓰지 않고 추가(Append)하는 reducer
    messages: Annotated[Sequence[BaseMessage], add_messages]
    
    # 다음에 실행될 노드(에이전트)의 이름
    next: str
    
    # 캐시 히트 여부 (Supervisor가 캐시에서 답변을 찾았는지 여부)
    is_cached: bool
    
    # 호출한 사용자의 ID 또는 세션 컨텍스트 (필요 시 RAG 등에 사용)
    sender: str
    
    # 사용자 Role (Student, Instructor, EduOps, Owner 등)에 따라 다르게 처리하기 위한 정보
    sender_role: Optional[str]
