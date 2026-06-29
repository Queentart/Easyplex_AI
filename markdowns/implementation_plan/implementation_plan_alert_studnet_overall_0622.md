# Notification Center (알림 센터) Implementation Plan

사용자 화면 상단의 종 모양 아이콘과 연동되어 수강생 및 강사/운영진에게 다양한 알림을 띄우는 알림 센터 기능 구현 계획입니다. 백엔드 데이터베이스 설계부터 프론트엔드 전역 상태 관리 및 UI 연결까지 전 구간을 아우릅니다.

## Proposed Changes

### 1. Database & Backend Model
알림 데이터를 영구적으로 저장하고 읽음(Read) 상태를 관리하기 위해 새로운 모델과 마이그레이션을 추가합니다.

#### [NEW] `backend/app/models/notification.py`
- `Notification` 모델 생성 (테이블명: `notifications`)
- **주요 필드**: `id`, `user_id` (수신자), `title` (알림 제목), `message` (내용), `type` (warning, info, success, message 등), `is_read` (기본 False), `link` (클릭 시 이동할 URL), `created_at`.
- 백엔드 컨테이너 내에서 Alembic을 이용해 마이그레이션(`revision --autogenerate`, `upgrade head`)을 수행합니다.

#### [NEW] `backend/app/services/notification_service.py`
- 내부적으로 다른 엔드포인트(예: 새 자료 업로드, 질문 답변 등록, 과제 마감 임박 등)에서 손쉽게 알림을 생성할 수 있도록 `create_notification` 헬퍼 함수를 구현합니다.

### 2. Backend API Endpoint
프론트엔드와 통신하기 위한 전용 API를 추가합니다.

#### [NEW] `backend/app/api/v1/endpoints/notifications.py`
- `GET /api/v1/notifications`: 현재 로그인한 사용자의 모든 알림 목록 반환 (최신순).
- `POST /api/v1/notifications/{id}/read`: 특정 알림을 읽음 처리.
- `POST /api/v1/notifications/read-all`: 모든 알림을 일괄 읽음 처리.

#### [MODIFY] `backend/app/api/v1/api.py`
- 새롭게 만든 notifications 라우터를 `api_router.include_router`에 등록합니다.

---

### 3. Frontend Global State & API
어느 페이지에 있더라도 새로운 알림이 생기면 상단 종 모양에 빨간 뱃지(Badge)를 띄우기 위해 전역 상태(Context)를 도입합니다.

#### [NEW] `frontend/src/api/notificationApi.ts`
- 알림 목록 조회, 읽음 처리, 모두 읽기 처리 등을 담당하는 Axios 호출 로직 작성.

#### [NEW] `frontend/src/contexts/NotificationContext.tsx`
- 애플리케이션 최상단(`App.tsx` 또는 레이아웃 래퍼)에 알림 상태를 관리하는 Context Provider를 추가합니다.
- `unreadCount`를 추적하고 폴링(Polling) 또는 페이지 이동 시 알림 데이터를 갱신합니다.

### 4. Frontend UI & Routing
실제 알림 리스트 화면과 상단 헤더 연결을 진행합니다.

#### [MODIFY] `frontend/src/components/layout/DesktopLayout.tsx` & `MobileLayout.tsx`
- `NotificationContext`를 구독하여 안읽은 알림이 있을 경우 `showNotificationBadge` 속성을 켜주고, 종 모양 아이콘을 클릭하면 `/notifications` 경로로 이동하도록 `onNotificationClick`을 `Header`에 전달합니다.

#### [NEW] `frontend/src/pages/shared/Notifications.tsx`
- 스크린샷과 동일한 UI의 "알림 센터" 전체 페이지를 구현합니다.
- 알림 타입(`warning`, `info`, `success`, `message` 등)에 따라 아이콘과 색상을 다르게 렌더링.
- 우측 상단에 "모두 읽음" 및 "테스트(임의의 알림 생성)" 버튼 추가.
- 클릭 시 해당 알림을 읽음 처리하고, `link`가 존재하면 해당 경로로 라우팅.

#### [MODIFY] `frontend/src/App.tsx`
- `/notifications` 경로를 추가하고 학생, 멘토, 강사 모두가 접근 가능하도록 라우터를 연결합니다.

## User Review Required

> [!IMPORTANT]
> **알림 생성 시점**: 현재 백엔드 로직에 "새로운 과제 등록", "새로운 자료 등록", "질문/답변 작성" 등의 기능들이 있습니다. 알림 센터가 구축된 후, 실제 알림이 언제 발송되어야 할지 명확한 시나리오가 필요합니다. 
> 임시로 "테스트" 버튼을 통해 알림을 인위적으로 발생시키는 기능을 구현해 둘 예정이며, 추후 필요한 서비스 로직 곳곳에 `notification_service`를 이식할 계획입니다. 

위 계획대로 알림 센터 구현을 진행해도 될지 승인해 주시면, 바로 개발을 시작하겠습니다!
