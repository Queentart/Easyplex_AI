# Notification System Improvement Plan

이 문서는 수강생 측 알림 센터의 기능 세분화 및 UI 개선을 위한 구현 계획입니다. 사용자님의 피드백을 반영하여 알림 유형을 명확히 정의하고, 화면 전환 없이 바로 확인할 수 있는 드롭다운(팝업) UI로 개편합니다.

## User Review Required

> [!IMPORTANT]  
> **'warning' 유형 활용에 대한 제안**
> `warning`은 주로 "사용자의 주의가 필요한 임박한 이벤트나 조기 경보"에 사용하는 것이 일반적입니다. 다음과 같은 활용 방안을 제안해 드립니다:
> 1. **과제 마감 기한 임박 알림**: "과제 3의 제출 마감일이 24시간 남았습니다." (가장 유용합니다)
> 2. **장기 미접속/미출결 주의**: "3일 연속으로 출석 체크가 진행되지 않았습니다."
> 3. **시스템/플랫폼 점검 예정**: "내일 새벽 2시부터 서버 정기 점검이 예정되어 있습니다."
> 
> *제안해 드린 `warning` 유형 활용 방안 중 마음에 드시는 것이 있는지 피드백을 부탁드립니다.*

## 1. Notification Types (유형 세분화)

알림은 전체 수강생에게 브로드캐스트되는 **Global** 알림과 개별 수강생에게만 발송되는 **Targeted** 알림으로 나뉩니다.

- **[info] (Global / Targeted)**: 운영팀, 기술팀, 강사진 등에서 공지사항, 유튜브 영상, 강의 자료, 새 과제 등이 업로드 되었을 때
- **[success] (Targeted)**: 수강생 측에서 과제를 성공적으로 제출했을 때
- **[alert] (Targeted)**: 출결 및 기타 점수, 학업 진행 시 해당 학생에게 신고가 들어왔거나 부정적인 영향(경고 누적 등)이 갈 경우
- **[message] (Targeted)**: 운영팀/기술팀/강사진 측에서 수강생이 보낸 질의에 대한 답변(Reply)을 달았을 때
- **[warning] (Targeted / Global)**: (제안) 마감 기한 임박, 출결 주의망, 혹은 시스템 점검 등 주의가 필요한 사항

## 2. Notification Scope (발송 범위)

백엔드에서 알림을 발송할 때 `user_id`를 지정하는 방식에 따라 범위를 나눕니다.

- **개인 알림 (Targeted)**: `user_id`에 특정 학생의 ID를 입력하여 저장. (과제 채점, Q&A 답변, 개별 경고 등)
- **전체 알림 (Global)**: 공지사항이나 전체 자료 업로드의 경우, 전체 학생의 `user_id` 목록을 조회하여 일괄적으로(Bulk) `Notification` 레코드를 생성.

## 3. UI/UX 개선 (Dropdown Popup)

현재 종 모양 아이콘을 누르면 `/notifications` 페이지로 라우팅되던 방식을 폐기하고, 오버레이(Dropdown) 형태의 팝업으로 변경합니다.

- **위치**: 헤더의 종 모양 아이콘 바로 아래에 말풍선 형태로 드롭다운 표시
- **스타일**: 채팅 봇처럼 배경을 딤(Blur) 처리하거나 화면 전체를 덮지 않고, 단순히 다른 요소들 위에 떠 있는(Z-index) 깔끔한 팝업 메뉴 형태
- **기능**: 최신 알림 N개(예: 최대 10개) 리스트 표시, 스크롤 가능, 클릭 시 읽음 처리 및 이동, 하단에 "모두 읽음" 버튼 배치

## Proposed Changes

### Frontend Components

#### [MODIFY] `c:\Easyplex_AI\frontend\src\components\common\Header.tsx`
- 알림 버튼 클릭 시 `useNavigate('/notifications')` 라우팅을 제거합니다.
- 대신 `isNotificationOpen` 상태를 관리하여 드롭다운 UI 렌더링 여부를 토글합니다.
- `NotificationDropdown` 컴포넌트를 종 모양 아이콘 아래에 렌더링합니다. (또는 Header 내부에 직접 작성)

#### [NEW] `c:\Easyplex_AI\frontend\src\components\common\NotificationDropdown.tsx`
- 기존 `Notifications.tsx`에 있던 알림 리스트 렌더링 로직을 가져와 드롭다운 크기(예: width 320px)에 맞게 축소 및 최적화합니다.
- `NotificationContext`를 구독하여 `notifications` 리스트를 렌더링합니다.

#### [DELETE] `c:\Easyplex_AI\frontend\src\pages\shared\Notifications.tsx`
- 페이지 전환 방식이 폐기되므로 기존 전체화면 알림 페이지 컴포넌트를 삭제합니다.

#### [MODIFY] `c:\Easyplex_AI\frontend\src\App.tsx`
- `<Route path="/notifications" ... />` 라우트를 제거합니다.
- `<Route path="/student/notifications" ... />` 라우트 역시 필요하다면 제거합니다.

### Backend Updates

#### [MODIFY] `c:\Easyplex_AI\backend\app\api\v1\endpoints\notifications.py` (또는 각 도메인 서비스 로직)
- 새로운 5가지 유형 분류에 맞게 각 기능(과제 제출, 과제 업로드, 자료 업로드, Q&A 등)에서 알림을 생성할 때 올바른 `type`을 지정하도록 로직을 강화합니다.
- **Global 발송 기능**: `notification_service.py`에 전체 수강생을 대상으로 알림을 일괄 삽입하는 `create_global_notification` 헬퍼 함수를 추가합니다.

## Verification Plan

1. UI 확인: 다른 메뉴에 접근 중에 알림 아이콘을 눌렀을 때 페이지가 이동하지 않고 우측 상단에 알림 팝업이 부드럽게 나타나는지 확인합니다. 배경이 블러 처리되지 않고 다른 작업을 방해하지 않는지 확인합니다.
2. 기능 확인: [테스트] 버튼을 눌렀을 때 모든 5가지 상태(info, success, alert, message, warning) 아이콘이 올바르게 나타나는지 확인합니다.
3. 범위 확인: 백엔드에서 공지사항 생성 시 모든 학생에게, 과제 제출 시 본인에게만 알림이 쌓이는지 점검합니다.
