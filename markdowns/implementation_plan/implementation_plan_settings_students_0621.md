# 수강생 전용 설정 모달 구현

수강생 페이지에서 공통적으로 접근 가능한 설정 기능(알림 제어, 환경 설정, 시스템 옵션)을 모달(팝업) 형태로 제공합니다.

## User Review Required

> [!IMPORTANT]
> - 현재 `Home.tsx`의 헤더에 있는 '설정(톱니바퀴)' 아이콘을 누르면 모달이 뜨도록 연결할 예정입니다. 혹시 `Home` 외에도 다른 페이지(예: Classroom, Assignment)에서도 상단 헤더에 설정 아이콘을 띄우길 원하시는지 확인이 필요합니다.
> - "채팅 알림음" 설정이나 "다크 모드" 설정의 경우, 실제 전역 상태(Context/Redux 등)나 localStorage와 연동해야 완벽히 동작합니다. 이번 구현에서는 UI 토글과 컴포넌트 내부 상태(또는 localStorage)를 1차적으로 연결해두는 방향으로 진행해도 될까요?

## Proposed Changes

### 1. 설정 모달 컴포넌트 생성

설정 팝업을 담당할 재사용 가능한 모달 컴포넌트를 생성합니다.

#### [NEW] [SettingsModal.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/components/SettingsModal.tsx)
- 기능: 
  - `isOpen`, `onClose` props를 통해 모달 열기/닫기 제어
  - **알림 설정**: 채팅 알림음(Sound), 주요 활동 푸시 알림
  - **프로필 설정**: 비밀번호 변경, 연락처 정보 수정 (모달 내부 진입점 버튼)
  - **환경 설정**: 다크 모드 (추후 전역 연동 고려)
  - **기타**: 이용약관, 로그아웃 버튼 (`useAuth`의 `logout` 연동)
- 스타일: 모달 오버레이(Backdrop) 및 팝업 카드 UI (기존 앱 디자인 시스템 반영)

### 2. 메인 페이지 연동

기존 `Home.tsx`에서 설정 모달을 열고 닫을 수 있도록 상태 및 렌더링을 추가합니다.

#### [MODIFY] [Home.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/Home.tsx)
- 변경 사항:
  - `isSettingsOpen` 상태 추가
  - `headerExtraIcons={[{ icon: 'settings', onClick: () => setIsSettingsOpen(true) }]}` 로 수정
  - JSX 하단에 `<SettingsModal isOpen={isSettingsOpen} onClose={() => setIsSettingsOpen(false)} />` 추가

### 3. 스타일시트 반영

설정 모달 전용 스타일 혹은 기존 `Student.css`에 모달 관련 스타일 추가.

#### [MODIFY] [Student.css](file:///c:/Easyplex_AI/frontend/src/pages/student/Student.css)
- 변경 사항:
  - `.settings-modal-overlay`, `.settings-modal-content` 등 설정 모달에 필요한 위치 지정, 애니메이션 및 반응형 CSS 추가.

## Verification Plan

### Manual Verification
- 수강생 계정으로 로그인 후 `Home` 페이지 상단의 톱니바퀴 아이콘 클릭
- 팝업이 부드럽게 노출되는지 확인 (오버레이 및 모달 카드 디자인)
- 내부 토글 버튼(알림, 다크모드 등) 클릭 시 상태가 잘 변환되는지 테스트
- **로그아웃** 버튼 클릭 시 정상적으로 세션이 종료되고 로그인 화면으로 리다이렉트되는지 확인
