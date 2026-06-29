# 학습 커리큘럼 관리 기능 구현 계획

사용자(운영팀 및 강사진)가 수강생(Student) 페이지에서 보이는 '학습 커리큘럼 로드맵'을 동적으로 관리할 수 있도록 커리큘럼 관리 기능을 구현합니다.

## User Review Required
- 이 계획서는 데이터베이스 모델 추가 및 API 연동, 마이그레이션이 포함되어 있어 작업을 시작하기 전에 사용자의 승인이 필요합니다.
- 데이터베이스에 CurriculumStep(학습 커리큘럼 단계)을 추가하고 수강생 PWA 화면이 이를 동적으로 불러오게 됩니다.

## Proposed Changes

---

### Backend: Database Models & Schemas
학습 커리큘럼(CurriculumStep) 데이터를 저장할 새로운 데이터베이스 모델과 Pydantic 스키마를 생성합니다.

#### [NEW] [models/curriculum.py](file:///c:/Easyplex_AI/backend/app/models/curriculum.py)
- `CurriculumStep` SQLAlchemy 모델 추가
- 컬럼: `id`, `title`, `status` (completed/current/upcoming), `progress` (0~100), `completed_date`, `starts_date`, `display_order`, `created_at`, `updated_at`

#### [NEW] [schemas/curriculum.py](file:///c:/Easyplex_AI/backend/app/schemas/curriculum.py)
- `CurriculumStepCreate`, `CurriculumStepUpdate`, `CurriculumStepResponse` Pydantic 모델 추가

---

### Backend: CRUD & API Endpoints
운영팀, 주강사, 멘토가 모두 접근 가능한 커리큘럼 관리 API를 개발합니다.

#### [NEW] [crud/crud_curriculum.py](file:///c:/Easyplex_AI/backend/app/crud/crud_curriculum.py)
- `CRUDCurriculumStep` 생성 (순서 정렬 기준 목록 조회 기능 포함)

#### [NEW] [api/v1/endpoints/shared/curriculum.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/shared/curriculum.py)
- `GET /` (수강생, 강사, 운영팀 모두 조회 가능)
- `POST /`, `PUT /{id}`, `DELETE /{id}` (강사, 멘토, 운영팀 권한만 접근 가능)

#### [MODIFY] [api/v1/api.py](file:///c:/Easyplex_AI/backend/app/api/v1/api.py)
- 새 라우터 `/curriculum` 등록

---

### Backend: Alembic Migration
모델 추가를 데이터베이스 스키마에 반영합니다.

#### [MODIFY] [alembic/env.py](file:///c:/Easyplex_AI/backend/alembic/env.py)
- `models/curriculum.py` 임포트 확인 (base.py 등 연관 파일)

---

### Frontend: API Client & Data Fetching
프론트엔드에서 백엔드 API를 통해 데이터를 주고받도록 구성합니다.

#### [NEW] [api/curriculumApi.ts](file:///c:/Easyplex_AI/frontend/src/api/curriculumApi.ts)
- `getCurriculumSteps`, `createCurriculumStep`, `updateCurriculumStep`, `deleteCurriculumStep` 함수 구현

---

### Frontend: UI Components & Routing
새로운 관리 페이지를 만들고 강사 및 운영팀 사이드바에 연결합니다.

#### [NEW] [pages/shared/CurriculumMgmt.tsx](file:///c:/Easyplex_AI/frontend/src/pages/shared/CurriculumMgmt.tsx)
- 커리큘럼 단계를 추가, 수정, 삭제, 상태 변경(진행도 업데이트) 할 수 있는 통합 관리 UI 페이지 작성

#### [MODIFY] [App.tsx](file:///c:/Easyplex_AI/frontend/src/App.tsx)
- `/instructor/curriculum` 및 `/eduops/curriculum` 라우트 추가 (둘 다 `CurriculumMgmt` 컴포넌트 렌더링)

#### [MODIFY] [data/instructor.ts](file:///c:/Easyplex_AI/frontend/src/data/instructor.ts)
- 사이드바 메뉴에 `{ id: 'curriculum', label: '학습 커리큘럼 관리', icon: 'route', path: '/instructor/curriculum', allowedRoles: ['instructor', 'tutor'] }` 추가

#### [MODIFY] [data/eduops.ts](file:///c:/Easyplex_AI/frontend/src/data/eduops.ts)
- 사이드바 메뉴에 `{ id: 'curriculum', label: '학습 커리큘럼 관리', icon: 'route', path: '/eduops/curriculum', allowedRoles: ['ops'] }` 추가

#### [MODIFY] [pages/student/Classroom.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/Classroom.tsx)
- 목업 데이터(`curriculumRoadmap`) 대신 `curriculumApi.getCurriculumSteps()`를 호출하여 동적으로 렌더링하도록 변경

---

## Verification Plan

### Automated Tests
- DB 마이그레이션 (`docker exec fastapi_backend alembic upgrade head`) 시 에러가 없는지 검증

### Manual Verification
1. 강사 계정(`instructor@easyplex.com`) 및 멘토 계정(`tutor@easyplex.com`)으로 로그인 후 좌측 탭에 "학습 커리큘럼 관리" 메뉴 확인 및 권한 검증.
2. 운영팀 계정(`ops@easyplex.com`) 로그인 후 동일하게 확인.
3. 관리 페이지에서 새 커리큘럼 아이템(완료, 진행중, 예정) 생성 및 상태, 진행률 수정.
4. 수강생 계정(`student@easyplex.com`)으로 로그인하여 Classroom 페이지에서 변경된 커리큘럼 로드맵이 정상적으로 나타나는지 확인.
