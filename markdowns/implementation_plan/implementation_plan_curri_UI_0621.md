# Curriculum Roadmap V2 (AI Parsing & Node Editor)

현재의 단순한 학습 커리큘럼 리스트를 고도화하여, 운영팀(EduOps)은 문서를 통한 AI 자동 등록을, 강사진(Instructor)은 노드(Node) 기반의 시각적 로드맵 편집 기능을 사용할 수 있도록 시스템을 개편합니다.

## User Review Required

> [!WARNING]
> 노드 편집기(Node Editor)를 도입하기 위해 프론트엔드에 `@xyflow/react` (기존 React Flow) 라이브러리를 새로 설치해야 합니다.
> 또한, 엑셀 파일(.xlsx) 파싱을 위해 백엔드에 `openpyxl` 파이썬 패키지를 추가할 계획입니다.

## Open Questions

> [!IMPORTANT]
> 1. **노드 연결 방식 (데이터 구조):** 강사가 노드를 선으로 연결할 때, 이것이 단순한 "순서(display_order)"를 의미하나요? 아니면 "선수 과목(Prerequisite / Parent-Child)" 등 복잡한 분기(Branching)를 가지는 트리/그래프 구조를 의미하나요? 현재 DB 구조는 선형적인 순서(`display_order`)만 가지고 있습니다. 복잡한 그래프가 필요하다면 DB 스키마 수정(Edge 추가)이 필요합니다. 일단은 **순서에 따른 선형 그래프 형태(혹은 단순 순차 연결)**로 구현하는 것을 제안합니다.
> 2. **AI 파싱 후 동작:** 문서 업로드 후 AI가 파싱한 결과를 즉시 DB에 저장할까요? 아니면 화면에 먼저 뿌려주고 사용자가 검토(수정)한 후 일괄 저장(Save) 버튼을 누르게 할까요? 후자가 안전할 것으로 보여 제안합니다.

## Proposed Changes

### Backend (FastAPI)
- 백엔드에 엑셀 파싱을 위한 의존성 추가 (`openpyxl`).
- 문서 텍스트 추출 로직 개발 (PDF는 `pypdf`, 엑셀은 `pandas` 활용).
- LangChain / Ollama(`get_reasoning_llm`)를 활용하여 추출된 텍스트에서 커리큘럼 단계(제목, 기간, 내용 등)를 JSON 형태로 정형화하는 프롬프트 및 서비스 레이어 추가.

#### [MODIFY] `backend/app/api/v1/endpoints/curriculum.py`
- `POST /upload`: 문서를 받아 파싱된 커리큘럼 목록(JSON)을 반환하는 엔드포인트 추가.

### Frontend (React)
- 패키지 매니저를 통해 `@xyflow/react` 설치.
- 기존 공통이었던 `CurriculumMgmt`를 운영팀용과 강사용으로 분리하거나 모드를 나눔.

#### [MODIFY] `frontend/package.json`
- `@xyflow/react` 패키지 추가.

#### [MODIFY] `frontend/src/api/curriculumApi.ts`
- 파일 업로드 API 호출 메서드 추가.

#### [MODIFY] `frontend/src/pages/shared/CurriculumMgmt.tsx`
- 운영팀(EduOps) 모드:
  - 파일(PDF, XLSX) 업로드 영역 추가.
  - 업로드 완료 시 AI가 반환한 결과를 리스트(테이블) 형태로 임시 렌더링.
  - 각 항목 직접 수정 및 일괄 저장 기능 추가.
- 강사진(Instructor) 모드:
  - `@xyflow/react`를 활용한 Node 기반 캔버스 화면 구성.
  - 노드를 드래그 앤 드롭으로 배치하고 Edge(연결선)를 이을 수 있는 UI.
  - 노드 클릭 시 사이드 패널에서 제목 등 세부 내용 수정.

## Verification Plan

### Automated Tests
- 없음

### Manual Verification
1. 운영팀 계정에서 PDF/XLSX 파일을 업로드하여 AI가 올바르게 커리큘럼 단계를 분리해 오는지 확인.
2. 불러온 데이터를 수정 후 DB에 잘 저장되는지 확인.
3. 강사 계정에서 노드를 드래그하고 연결한 뒤 저장했을 때, 수강생 화면에 올바른 순서로 노출되는지 확인.
