# Phase 3: Local LLM (Ollama) & Multi-Agent (LangGraph) 연동 계획

Ollama 로컬 모델을 활용하여 보안을 유지하면서도 비용 없이 강력한 AI 워크플로우를 구축하기 위한 계획입니다. 조회된 모델 목록을 분석하여 각 역할에 최적화된 모델을 선정하였고, `keep_alive=0` 파라미터를 적용하여 VRAM(메모리) 관리를 최적화합니다.

> [!IMPORTANT]
> 로컬 환경에서 여러 에이전트(LangGraph)가 동작하므로 모델이 메모리에 계속 상주하면 VRAM 초과(OOM) 오류가 발생할 수 있습니다. 요청하신 대로 모든 호출에 `keep_alive=0`을 적용하여 작업 즉시 모델이 메모리에서 해제되도록 구성합니다.

## User Review Required

아래 선정된 모델 조합과 `.env` 변수 구조가 마음에 드시는지 확인해 주세요. 

## 1. 모델 선정 및 환경 변수(.env) 설정

`ollama list` 결과를 분석하여 가장 성능이 좋고 목적에 맞는 모델 3가지를 선정했습니다.

### 제안하는 모델 구성
- **메인 오케스트레이터 및 Tool Calling:** `llama3-groq-tool-use:latest` (Tool Calling에 특화되어 LangGraph 에이전트 라우팅에 최적화됨)
- **복잡한 논리/추론 (선택적):** `deepseek-r1:latest` (깊은 사고가 필요한 과제 피드백 등)
- **임베딩 (RAG용 벡터 변환):** `nomic-embed-text:latest` (가볍고 빠르며 검색 정확도가 높은 임베딩 모델)

### [MODIFY] `c:\Easyplex_AI\.env`
다음 환경 변수들을 추가하여 코드 내 하드코딩을 방지합니다.
```env
# AI & LLM Settings (Ollama)
OLLAMA_BASE_URL=http://localhost:11434
LLM_MAIN_MODEL=llama3-groq-tool-use:latest
LLM_REASONING_MODEL=deepseek-r1:latest
LLM_EMBEDDING_MODEL=nomic-embed-text:latest
```

## 2. 핵심 AI 서비스 모듈 구현 (Backend)

### [NEW] `backend/app/core/llm.py`
`.env`의 환경 변수를 읽어오고 `keep_alive=0` 파라미터가 기본 적용된 LangChain 기반의 통일된 LLM 클라이언트를 생성하는 팩토리 모듈을 만듭니다.
- `ChatOllama(model=..., keep_alive=0, base_url=...)`
- `OllamaEmbeddings(model=...)`

### [NEW] `backend/app/services/agent_workflow.py` (또는 `agents/` 디렉터리)
LangGraph를 사용하여 상태 기반(StateGraph) 멀티 에이전트를 구축합니다.
- **State 정의:** 메시지 내역, 현재 처리 중인 문서/학생 정보 등
- **Orchestrator 노드:** 사용자의 요청(혹은 시스템 이벤트)을 분석해 어떤 Sub-Agent가 처리할지 결정 (Tool Calling 활용).
- **Sub-Agents 노드:** 과제 채점용(Grading), 상담 분석용(Counseling) 등 특화된 작업을 수행.

## Verification Plan

### Automated Tests
- 백엔드에서 `python -m pytest` 또는 단일 스크립트(`scripts/test_llm.py`)를 실행하여 `keep_alive=0` 속성 하에서 Ollama 응답이 정상적으로 수신되는지 확인합니다.

### Manual Verification
1. FastAPI 서버 시작 후 Swagger UI(`/docs`)에서 테스트 엔드포인트를 호출해 봅니다.
2. 실행 도중 및 직후 작업 관리자(또는 `nvidia-smi`)를 통해 VRAM 점유율이 0으로 다시 떨어지는지(모델 언로드) 직접 확인합니다.
