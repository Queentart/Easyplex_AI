# 강사 및 멘토(Tutor) 기능 확장 및 빈 파일 정리 계획

현재 누락된 강사진(Instructor/Tutor) 기능과 프론트엔드 UI/라우팅, 그리고 데이터베이스 및 백엔드 빈 파일 정리를 수행하기 위한 구현 계획입니다.

## User Review Required
> [!IMPORTANT]
> - **채팅 UI 방식**: 수강생과의 채팅은 강사님이 다른 업무(채점 등)를 보면서도 쉽게 응답할 수 있도록 **Global Drawer(우측에서 슬라이드 되어 열리는 패널)** 형태로 구현하고자 합니다. 이렇게 하면 별도 페이지로 이동하지 않아도 채팅을 진행할 수 있어 가장 적합합니다.
> - **역할(Role) 추가**: 현재 DB 모델에 `TUTOR`(멘토) 권한이 없으므로, `UserRole` Enum에 `TUTOR`를 추가하고, DB에 강사와 멘토 더미 데이터를 추가할 계획입니다.
> - **빈 파일 정리**: 백엔드의 빈 파일들 중 강사 관련 파일들을 새로운 기능(자료 업로드, 일지) API로 활용하고, 불필요한 빈 파일은 삭제하겠습니다. 

## Proposed Changes

### 1. Database & Models
#### [MODIFY] [auth.py](file:///c:/Easyplex_AI/backend/app/models/auth.py)
- `UserRole` Enum에 `TUTOR` 역할 추가.

#### [NEW] [instructor_models.py](file:///c:/Easyplex_AI/backend/app/models/instructor_models.py)
- `CourseMaterial` (강의 자료)
- `TrainingLog` (주강사용 훈련일지)
- `MentoringLog` (멘토용 멘토링일지)
- *운영팀(EDUOPS)에서 위 일지 데이터를 조회할 수 있는 관계 매핑 포함.*

#### [NEW] [seed_data.py](file:///c:/Easyplex_AI/backend/seed_data.py)
- `create_db.py` 실행 후 또는 별도 스크립트로 주강사(instructor)와 멘토(tutor) 더미 데이터를 삽입.

---

### 2. Backend API & Services (빈 파일 활용 및 정리)
현재 `backend/app/api/v1/endpoints/instructor` 등지에 비어있는 파이썬 파일들이 있습니다. 이 파일들을 목적에 맞게 재작성/이름 변경하고, 불필요한 파일은 삭제합니다.

#### [MODIFY] [materials.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/instructor/materials.py) (기존 빈 파일 활용/이름 변경)
- 강의 자료 업로드, 조회, 삭제 API (`/api/v1/instructor/materials`) 구현

#### [MODIFY] [logs.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/instructor/logs.py) (기존 빈 파일 활용/이름 변경)
- 훈련일지(주강사) 및 멘토링일지(멘토) CRUD API (`/api/v1/instructor/logs`) 구현
- eduops 운영팀과의 데이터 연동(조회) 기능 포함

#### [MODIFY] [chat.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/instructor/chat.py) (새로운 엔드포인트)
- 수강생과의 1:1 채팅 관련 기록 조회 및 웹소켓 처리 백엔드 엔드포인트.

#### [DELETE] 불필요한 빈 파일들
- 역할을 잃었거나 너무 잘게 쪼개져 있는 빈 파일들 (예: `assignments.py`, `attendance.py`, `reports.py` 중 내용이 없는 파일)은 하나로 통합하거나 삭제 처리합니다.

---

### 3. Frontend UI & Routing
#### [MODIFY] [App.tsx](file:///c:/Easyplex_AI/frontend/src/App.tsx)
- 라우팅 추가:
  - `/instructor/materials` (강의 자료 관리)
  - `/instructor/training-logs` (주강사 - 훈련일지)
  - `/instructor/mentoring-logs` (멘토 - 멘토링일지)
- `ProtectedRoute`에 `tutor` 권한 허용 추가.

#### [MODIFY] 사이드바 컴포넌트
- 권한(Role)에 따른 메뉴 동적 렌더링:
  - 공통: `강의 자료 관리` (좌측 사이드바 추가)
  - Role `instructor`: `학습 일지 (훈련일지)` 렌더링
  - Role `tutor`: `멘토링 일지` 렌더링 (`학습 일지` 숨김)

#### [NEW] 채팅 Drawer 컴포넌트
- 페이지 이동 없이 어디서든 우측 하단 버튼이나 단축키로 열 수 있는 전역 채팅 패널 구축 (Context/Zustand 기반 상태 관리 적용).

#### [NEW] 강의 자료 및 일지 페이지 컴포넌트
- `CourseMaterials.tsx`, `TrainingLogs.tsx`, `MentoringLogs.tsx` 프론트엔드 페이지 작성.

## Verification Plan
### Manual Verification
- 프론트엔드를 실행하여 더미 주강사 계정과 더미 멘토 계정으로 각각 로그인.
- **주강사 계정**: 좌측 사이드바에 [강의 자료], [학습 일지]가 보이고 [멘토링 일지]는 보이지 않는지 확인.
- **멘토 계정**: 좌측 사이드바에 [강의 자료], [멘토링 일지]가 보이고 [학습 일지]는 보이지 않는지 확인.
- **채팅 기능**: 우측에 채팅 Drawer 패널이 정상적으로 열리고 닫히는지 검증.
- **운영팀(EDUOPS)**: 운영팀 계정으로 일지 조회 API를 호출할 때 두 종류의 일지가 모두 조회되는지 검증.
