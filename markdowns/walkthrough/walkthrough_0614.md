# Phase 3: Ollama & LangGraph 초기 설정 완료 🎉

로컬 AI 모델(Ollama)과 LangGraph를 활용한 멀티 에이전트 워크플로우의 기초 뼈대를 성공적으로 구축했습니다! 요청하신 VRAM 관리 최적화 사항도 모두 반영되었습니다.

## 1. 환경 설정 (.env)
하드코딩 없이 모델명을 동적으로 불러올 수 있도록 `.env` 파일과 `app/core/config.py`에 다음 변수들을 추가했습니다.
- `LLM_MAIN_MODEL`: `llama3-groq-tool-use:latest` (메인 오케스트레이터 및 함수 호출 특화)
- `LLM_REASONING_MODEL`: `deepseek-r1:latest` (복잡한 추론 및 피드백 전용)
- `LLM_EMBEDDING_MODEL`: `nomic-embed-text:latest` (임베딩 추출 특화)
- `OLLAMA_BASE_URL`: `http://localhost:11434`

## 2. LLM 코어 엔진 생성 (`app/core/llm.py`)
> [!TIP]
> **VRAM 최적화 핵심:** `get_llm()` 및 `get_reasoning_llm()` 팩토리 함수 내부에 `keep_alive=0` 파라미터를 강제 할당했습니다. 이로 인해 모델 호출이 끝나는 즉시 메모리에서 모델이 자동으로 언로드되어, 여러 에이전트가 동작하더라도 OOM(Out of Memory)를 방지합니다.

## 3. LangGraph 멀티 에이전트 뼈대 생성 (`app/services/agent_workflow.py`)
단순한 챗봇 구조를 넘어서, LangGraph 라이브러리를 활용해 **상태(State) 기반의 에이전트 라우팅 구조**를 구축했습니다.
- **AgentState**: 모든 대화 및 데이터 히스토리가 기록되는 컨테이너
- **Orchestrator Node**: 유저의 요청을 받아 어떤 처리를 할지 고민하는 중앙 노드 (메인 모델 사용)
- **Reasoning Node**: 채점이나 학생 상담 데이터 분석 등 깊은 사고가 필요할 때 라우팅되는 특화 노드

## 4. 백그라운드 자동 테스트 결과
```text
Testing LLM instantiation and keep_alive parameter...
Model configured: llama3-groq-tool-use:latest
Invoking model (this might take a few seconds if loading)...
Response: Hello
```
로컬의 Ollama 서버에 성공적으로 접근하여 응답을 받아왔습니다! `keep_alive=0` 설정도 의도한 대로 동작하고 있습니다.

---

## 🚀 다음 단계 (Next Steps)
이제 기초 공사가 끝났습니다. 이 강력한 AI 코어를 활용해 프론트엔드의 대시보드와 연결될 **실제 기능**들을 만들어 나갈 차례입니다.

**어떤 기능을 가장 먼저 구현해 볼까요?**
1. **AI 상담 코칭 기능:** 학생의 출결/성취도를 입력받아 강사에게 맞춤형 지도 방안 제안하기
2. **AI 과제 자동 채점:** 특정 과제 내용(Text)을 임베딩하고 AI 모델이 예상 점수와 피드백을 자동으로 달아주기
3. **RAG 임베딩 연동:** 더미 텍스트 데이터를 `nomic-embed-text`로 벡터화하여 DB에 저장 및 검색하는 파이프라인 구축
