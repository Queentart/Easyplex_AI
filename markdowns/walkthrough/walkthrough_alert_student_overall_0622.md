# Notification Center (알림 센터) Implementation Walkthrough

제시해 드렸던 플랜에 따라 알림 센터의 엔드투엔드(End-to-End) 구현을 모두 완료했습니다. 이제 상단 종 모양 아이콘을 통해 어떤 페이지에 있더라도 새 알림 여부를 확인하고, 알림 센터 페이지에서 알림 목록을 한눈에 관리할 수 있습니다.

## 백엔드 구현 (Backend)

1. **알림 모델 (Notification Model)**
   - `app/models/notification.py`에 새 모델을 생성했습니다.
   - 사용자 식별(`user_id`), 제목(`title`), 상세 내용(`message`), 타입(`type`), 읽음 여부(`is_read`), 클릭 시 이동 경로(`link`) 필드를 포함합니다.
   - 데이터베이스 스키마 확장을 위해 Alembic 마이그레이션(`0d8178437000_add_notification_model`)을 생성 및 반영 완료했습니다.

2. **알림 서비스 헬퍼 (Service)**
   - `app/services/notification_service.py`에 `create_notification` 함수를 마련하여, 추후 다른 서비스(예: 과제 등록, 질의응답)에서 쉽게 알림을 쏠 수 있도록 했습니다.

3. **API 엔드포인트**
   - `GET /api/v1/notifications`: 사용자의 알림 목록 불러오기
   - `POST /api/v1/notifications/{id}/read`: 개별 읽음 처리
   - `POST /api/v1/notifications/read-all`: 모두 읽음 처리
   - **`POST /api/v1/notifications/test`**: 시연 및 테스트용으로 무작위 알림을 생성할 수 있는 엔드포인트

## 프론트엔드 구현 (Frontend)

1. **전역 상태 관리 (Context API)**
   - `NotificationContext.tsx`를 생성해 사용자가 로그인하면 **1분마다 자동으로 알림을 갱신(Polling)**하도록 구현했습니다.
   - 안 읽은 알림 개수(`unreadCount`)를 전역적으로 추적하여 헤더 UI와 즉각 동기화합니다.

2. **UI 및 레이아웃 연결**
   - 강사/운영진이 쓰는 `DesktopLayout`과 수강생이 쓰는 `MobileLayout` 모두 종 모양 아이콘에 `unreadCount` 뱃지(빨간 점)가 켜지도록 연결했습니다.
   - 아이콘 클릭 시 `/notifications` 경로로 라우팅됩니다.

3. **알림 센터 페이지 (Notifications)**
   - 스크린샷과 동일한 구성의 리스트 UI(`pages/shared/Notifications.tsx`)를 구축했습니다.
   - "모두 읽음" 버튼과 함께, 백엔드 테스트 API와 연동되는 **[테스트]** 버튼을 상단에 추가했습니다. 이 버튼을 누르면 무작위 유형(Warning, Info, Success 등)의 알림이 즉시 생성되어 화면에 나타납니다.

> [!TIP]
> **확인 방법**: 지금 바로 브라우저를 새로고침하신 뒤 상단의 **종 모양 아이콘**을 클릭해 보세요. "알림 센터" 페이지로 이동되며, 우측 상단의 **[테스트]** 버튼을 여러 번 눌러 알림이 잘 쌓이고 색상이 변하는지, 모두 읽음 처리가 정상 동작하는지 테스트해 보실 수 있습니다.
