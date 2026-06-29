# EduOps 강사 로그 뷰어 페이지 구현

운영팀(EduOps)이 주강사 및 멘토가 작성한 강의 자료, 학습 일지, 멘토링 일지를 통합적으로 확인할 수 있는 새로운 페이지를 구축합니다.

## User Review Required

- **페이지 통합 vs 분리:** 
  운영팀이 3가지 항목(강의 자료, 학습 일지, 멘토링 일지)을 한 화면에서 탭(Tab)으로 전환하며 볼 수 있도록 단일 페이지(`InstructorLogs.tsx`)로 통합 구성하는 방안을 제안합니다. 이렇게 하면 사이드바 메뉴가 너무 길어지지 않고 관리 효율이 올라갑니다.

## Proposed Changes

### Frontend
- **EduOps 라우터 및 사이드바 메뉴 업데이트**
  #### [MODIFY] [App.tsx](file:///c:/Easyplex_AI/frontend/src/App.tsx)
  - `/eduops/instructor-logs` 라우트 추가.
  
  #### [MODIFY] [StudentMgmt.tsx](file:///c:/Easyplex_AI/frontend/src/pages/eduops/StudentMgmt.tsx) (및 기타 EduOps 페이지들)
  - 사이드바 `opsMenu` 배열에 "Instructor Logs" 메뉴 아이템 추가.

- **신규 페이지 컴포넌트**
  #### [NEW] [InstructorLogs.tsx](file:///c:/Easyplex_AI/frontend/src/pages/eduops/InstructorLogs.tsx)
  - `DesktopLayout`의 `headerTabs`를 활용해 3개의 탭(강의 자료, 학습 일지, 멘토링 일지) 구성.
  - 강사별 필터링 기능 및 날짜 기반 조회 UI 구현.

### Backend
- **운영팀용 조회 API 추가**
  기존 강사(instructor) 폴더의 엔드포인트는 자신들의 기록을 올리고 보는 데 초점이 맞춰져 있으므로, 운영팀이 모든 강사의 기록을 열람할 수 있는 API를 제공합니다.

  #### [NEW] [logs.py (ops)](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/ops/logs.py)
  - `GET /api/v1/ops/logs/materials` : 모든 강의 자료 조회
  - `GET /api/v1/ops/logs/training` : 모든 학습 일지 조회
  - `GET /api/v1/ops/logs/mentoring` : 모든 멘토링 일지 조회

  #### [MODIFY] [router.py (ops)](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/ops/router.py) 또는 `__init__.py`
  - 신규 라우터 등록

## Verification Plan

### Manual Verification
1. `opsUser` 권한으로 로그인 후 사이드바에 추가된 `Instructor Logs` 메뉴 클릭.
2. 탭을 전환하며 목업 데이터가 각기 다르게 잘 표시되는지 확인.
3. 운영팀 전용 프리미엄 UI가 기존 EduOps 디자인 패턴과 잘 어울리는지 확인.
