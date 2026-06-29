# 수강생 전용 설정 모달 구현

## 작업 요약
수강생 전용 홈(Home) 페이지에서 설정 톱니바퀴 버튼을 누르면 팝업 모달 형태로 설정 메뉴가 뜨도록 기능을 구현 완료했습니다.

## 주요 변경 사항

### 1. 설정 팝업 컴포넌트 추가
- **[SettingsModal.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/components/SettingsModal.tsx) 신규 제작**
- 모바일 및 PC 환경에서 어색하지 않게 화면 아래에서 위로 올라오는 카드(Bottom Sheet) 형태의 모달을 디자인했습니다.
- 내부에는 수강생 프로필 요약, 알림 설정(채팅 알림음 등), 다크 모드 토글, 로그아웃 기능 등이 깔끔하게 포함되었습니다.

### 2. 홈 화면 연동
- **[Home.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/Home.tsx)**
- 상단 헤더에 있는 기존 톱니바퀴 아이콘에 `onClick` 이벤트를 부여했습니다.
- 해당 버튼 클릭 시 상태(isSettingsOpen)가 변경되며 모달 컴포넌트가 나타납니다. 모달 바깥 배경을 누르거나 X 버튼을 누르면 부드럽게 닫힙니다.

### 3. 스타일링
- **[Student.css](file:///c:/Easyplex_AI/frontend/src/pages/student/Student.css)**
- 반투명한 검은색 오버레이 레이어, 바텀 시트 형태의 라운드 디자인 및 슬라이드업(`slideUp`) 애니메이션을 추가하여 매우 프리미엄하고 모던한 모달 경험을 제공합니다.

## 결과 및 테스트
홈 화면에서 톱니바퀴 버튼을 클릭하여 새로운 설정 모달을 직접 테스트해보실 수 있습니다! 채팅 알림음 제어와 같은 설정 버튼이 동작하며, 로그아웃 버튼 클릭 시 즉시 권한이 초기화되고 홈으로 이동합니다.
