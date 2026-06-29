# 기술팀 스트리밍 링크 관리 페이지 추가 및 백엔드 설정

기술팀(TechOps)에서 온라인 교육 완료 후 유튜브/비메오 스트리밍 링크를 업로드 및 관리할 수 있는 페이지를 추가하고, 관련 백엔드 및 프론트엔드 파일을 수정/작성합니다.

## User Review Required

> [!IMPORTANT]
> 백엔드의 `tech` 폴더 내에 기존에 생성되어 있던 빈 파일들(`daily_ops.py`, `equipment.py`, `student_mgmt.py`)은 모두 프론트엔드에 대응되는 페이지가 있는 **필요한 파일**로 판단되어 삭제하지 않고 FastAPI Router 기본 뼈대 코드를 작성하여 활성화하고자 합니다. 이 결정에 동의하시는지 확인해 주시기 바랍니다.

## Proposed Changes

---

### Frontend

프론트엔드에서는 새로운 관리 페이지를 만들고 네비게이션과 라우터에 추가합니다.

#### [NEW] [StreamMgmt.tsx](file:///c:/Easyplex_AI/frontend/src/pages/techops/StreamMgmt.tsx)
- 스트리밍 링크 업로드, 삭제, 목록 조회를 할 수 있는 UI 컴포넌트 추가
- 기존 `TechOps` 레이아웃(`DesktopLayout`) 활용

#### [MODIFY] [techops.ts](file:///c:/Easyplex_AI/frontend/src/data/techops.ts)
- `techMenu` 배열에 `/techops/streams` (Streaming Mgmt) 항목 추가

#### [MODIFY] [App.tsx](file:///c:/Easyplex_AI/frontend/src/App.tsx)
- `/techops/streams` 경로에 대한 라우팅 추가 (`StreamMgmt` 컴포넌트 연결)

---

### Backend

빈 파일들에 API Router 기본 골격을 작성하고 메인 앱에 연동합니다.

#### [NEW] [streams.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/tech/streams.py)
- 스트리밍 링크 업로드 및 조회를 위한 CRUD 라우터 작성 (기본 목업 API 제공)

#### [MODIFY] [daily_ops.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/tech/daily_ops.py)
- 주석만 있던 빈 파일에 기본 APIRouter 스켈레톤 코드 작성

#### [MODIFY] [equipment.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/tech/equipment.py)
- 주석만 있던 빈 파일에 기본 APIRouter 스켈레톤 코드 작성

#### [MODIFY] [student_mgmt.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/tech/student_mgmt.py)
- 주석만 있던 빈 파일에 기본 APIRouter 스켈레톤 코드 작성

#### [NEW] [router.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/tech/router.py)
- 위 4개의 API 라우터(`streams`, `daily_ops`, `equipment`, `student_mgmt`)를 묶어주는 기술팀(tech) 통합 라우터 생성

#### [MODIFY] [main.py](file:///c:/Easyplex_AI/backend/app/main.py)
- 새로 만든 기술팀 통합 라우터(`tech.router.py`)를 `/tech` prefix로 `api_router`에 등록

## Verification Plan

### Manual Verification
- 프론트엔드 앱 실행 후 기술팀 메뉴(사이드바)에 "Stream Mgmt" 메뉴가 추가되었는지 확인
- "Stream Mgmt" 페이지에서 업로드 폼과 리스트 UI가 정상적으로 표시되는지 확인
- 백엔드 서버(`/docs` Swagger UI)에서 `/tech/streams`, `/tech/daily-ops`, `/tech/equipment`, `/tech/student-mgmt` 엔드포인트들이 모두 정상적으로 등록되었는지 확인
