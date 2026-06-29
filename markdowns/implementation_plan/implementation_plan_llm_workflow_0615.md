# 🧠 LangGraph 멀티 에이전트 워크플로우 구현 계획서

본 계획서는 `workflow.puml` 다이어그램을 바탕으로, "한 번에 하나의 기능씩" 단계적으로 구축하여 추론 부담을 줄이고 메모리 효율(`keep_alive=0`)을 강제하는 안정적인 멀티 에이전트 파이프라인을 구축하기 위해 작성되었습니다.

## ⚠️ User Review Required
> [!IMPORTANT]
> 본 계획은 사용자님의 지침에 따라 **Phase 1부터 순차적으로 하나씩** 개발하고, 각 Phase가 끝날 때마다 보고 및 다음 단계로 넘어가는 방식으로 진행됩니다. 아래의 개발 순서를 확인하시고 승인(Approve)해 주시면 바로 **Phase 1** 작업에 착수하겠습니다.

## 📝 개발 진행 단계 (Phases)

### Phase 1: 코어 기반 공사 (Foundation)
가장 먼저 LLM 모델을 호출하는 공통 클라이언트와 워크플로우의 상태(State)를 관리할 구조를 잡습니다.
- **`.env` 구성**: `OLLAMA_MODEL_NAME` 변수 등록
- **LLM Client Wrapper (`llm_client.py`)**: Langchain의 `ChatOllama` 모듈을 초기화할 때, **무조건 `keep_alive=0`** 옵션을 `model_kwargs` 또는 초기화 파라미터로 강제 삽입하여 모든 에이전트가 VRAM을 즉시 비우도록 설계합니다.
- **State Definition (`state.py`)**: LangGraph의 노드 간 데이터를 주고받을 상태(State) 스키마 정의 (메시지 기록, 에이전트 라우팅 상태 등).

### Phase 2: 데이터 연동 (RAG & Cache)
에이전트들이 사용할 주력 도구(Tools)를 먼저 작성합니다.
- **Redis Cache Tool**: 사용자 질문이 들어왔을 때 가장 먼저 캐시 히트(Cache Hit)를 확인하는 로직.
- **PostgreSQL (pgvector) RAG Tool**: QnA 및 Strategy 에이전트가 데이터베이스의 벡터 데이터를 검색할 수 있도록 해주는 도구.

### Phase 3: 핵심 라우터 (Supervisor Agent)
워크플로우의 두뇌 역할을 하는 Supervisor 에이전트를 작성합니다.
- **`supervisor.py`**: 사용자의 입력을 받아 분석한 뒤, Redis 캐시를 반환할지 아니면 어느 하위 에이전트(Q&A, Grading, Strategy, Admin)에게 작업을 넘길지 결정(Routing)합니다.

### Phase 4: 개별 특수 에이전트 (Sub-Agents)
각 역할별로 프롬프트를 세팅한 특수 에이전트들을 하나씩 분리하여 작성합니다.
1. **`qna_agent.py`**: 학생들의 FAQ 및 학습 질문을 RAG를 활용해 답변.
2. **`grading_agent.py`**: 강사진의 과제 채점 및 피드백 생성 보조.
3. **`strategy_agent.py`**: 오너의 커리큘럼 분석 및 통계 제안.
4. **`admin_agent.py`**: 운영팀/기술팀의 데이터 요약 및 행정 자동화.

### Phase 5: 워크플로우 통합 및 API 연결 (Integration)
지금까지 만든 모듈들을 LangGraph로 묶고 외부에서 호출할 수 있게 뚫어줍니다.
- **`workflow.py`**: `StateGraph`를 생성하고 Supervisor와 Sub-Agents를 노드와 엣지로 연결(Compile).
- **`api/v1/endpoints/ai.py`**: 프론트엔드에서 호출할 수 있는 엔드포인트(`POST /ai/chat`) 개설.

---

## 💡 오픈 퀘스천 (Open Questions)
> [!NOTE]
> 1. Redis 캐싱을 적용할 때 단순 문자열(String) 캐시를 적용할지, 아니면 의미론적 유사도를 비교하는 **Semantic Cache**(임베딩 모델 필요)를 적용할지 결정이 필요합니다. (회사 PC의 리소스 한계를 고려해 초기에는 **단순 Key-Value 캐싱**을 추천합니다.)
> 2. 위 Phase 1부터 바로 진행해도 될까요? 승인해 주시면 Phase 1 작업 후 바로 보고드리겠습니다.
