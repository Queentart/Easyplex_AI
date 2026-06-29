# 강사진 및 운영팀 스트리밍 링크 확인 페이지 추가 계획

기술팀이 업로드한 유튜브/비메오 라이브 스트리밍 링크를 강사진(주강사, 멘토)과 운영팀(EduOps)이 조회하고 확인할 수 있도록, 각 역할에 맞는 확인 전용 페이지(Read-only)를 구현합니다.

## User Review Required
이 구현에서는 프론트엔드에 **강사용** 스트리밍 확인 페이지와 **운영팀용** 스트리밍 확인 페이지 두 개를 각각 생성하고, 두 페이지 모두 백엔드(FastAPI)의 `/tech/streams` API를 호출하거나 혹은 프론트엔드의 공통 모의 데이터(Mock Data)를 조회하도록 구성할 예정입니다.
현재 시스템이 목업 위주로 돌아가고 있으므로 백엔드 `streams.py`에서 모의 데이터를 반환하게 하고, 프론트엔드는 이를 간단히 보여주도록 하겠습니다. 이 방향이 맞는지 확인해 주세요!

## Proposed Changes

---

### Frontend

강사진과 운영팀 각각의 사이드바/레이아웃에 맞춰 조회 전용 페이지를 만듭니다.

#### [NEW] [src/pages/instructor/ClassStreams.tsx](file:///c:/Easyplex_AI/frontend/src/pages/instructor/ClassStreams.tsx)
- 강사진(`instructor`, `tutor`)이 접근할 수 있는 스트리밍 조회 페이지 생성.
- `DesktopLayout`과 `instructorMenuItems`를 사용.

#### [NEW] [src/pages/eduops/ClassStreams.tsx](file:///c:/Easyplex_AI/frontend/src/pages/eduops/ClassStreams.tsx)
- 운영팀(`ops`)이 접근할 수 있는 스트리밍 검수/조회 페이지 생성.
- `DesktopLayout`과 `opsMenu`를 사용.

#### [MODIFY] [src/data/instructor.ts](file:///c:/Easyplex_AI/frontend/src/data/instructor.ts)
- `instructorMenuItems` 배열에 `Class Streams` 메뉴 항목 추가 (경로: `/instructor/streams`)

#### [MODIFY] [src/data/eduops.ts](file:///c:/Easyplex_AI/frontend/src/data/eduops.ts)
- `opsMenu` 배열에 `Class Streams` 메뉴 항목 추가 (경로: `/eduops/streams`)

#### [MODIFY] [src/App.tsx](file:///c:/Easyplex_AI/frontend/src/App.tsx)
- 강사 라우트에 `/instructor/streams` 추가
- 운영 라우트에 `/eduops/streams` 추가

---

### Backend

프론트엔드의 조회 페이지가 데이터를 불러올 수 있도록 기존 `streams.py` API에 모의 데이터를 반환하도록 업그레이드합니다.

#### [MODIFY] [src/api/v1/endpoints/tech/streams.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/tech/streams.py)
- `GET /` 호출 시 빈 메시지가 아닌, 유튜브/비메오 스트리밍 링크를 담은 더미 리스트를 반환하도록 수정합니다. 

## Verification Plan

### Manual Verification
1. 강사 혹은 멘토로 로그인 후 `/instructor/streams`로 이동하여 스트리밍 리스트가 보이는지 확인합니다.
2. 운영팀으로 로그인 후 `/eduops/streams`로 이동하여 스트리밍 리스트와 비디오 플랫폼 아이콘 등이 올바르게 표시되는지 확인합니다.
3. 백엔드 `http://localhost:8000/api/v1/tech/streams` (또는 해당 라우터 경로)가 200 OK와 함께 배열 데이터를 응답하는지 테스트합니다.
