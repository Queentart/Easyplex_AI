# Admin 프로필 및 설정 메뉴 연동 계획

수강생 페이지에 구현된 설정 모달창을 강사진, 운영팀, 기술팀, 오너 등 모든 관리자들도 동일하게 사용할 수 있도록 공통 컴포넌트로 분리하고 `DesktopLayout`에 연동하는 작업 계획입니다.

## Proposed Changes

### 1. SettingsModal 컴포넌트 공통화 및 동적 데이터 연동
- **위치 이동**: `src/pages/student/components/SettingsModal.tsx` -> `src/components/common/SettingsModal.tsx`로 이동하여 모든 페이지에서 접근 가능하도록 합니다.
- **사용자 정보 연동**: 기존에 하드코딩 되어 있던 "김이지", "AI 1기 수강생" 정보를 `AuthContext`의 `useAuth()`를 통해 로그인된 현재 관리자의 실제 이름(`user.name`), 이메일(`user.email`), 권한(`user.role`) 정보로 동적 렌더링되게 수정합니다.

### 2. DesktopLayout.tsx 수정 (관리자 공통 레이아웃)
#### [MODIFY] [DesktopLayout.tsx](file:///c:/Easyplex_AI/frontend/src/components/layout/DesktopLayout.tsx)
- `isSettingsOpen` 상태를 추가합니다.
- `<Header>`에 넘겨주는 `extraIcons` 배열의 가장 앞에 **톱니바퀴(설정) 아이콘**을 강제로 추가하여, 관리자 대시보드라면 어느 페이지든 우측 상단에 톱니바퀴가 보이도록 구성합니다.
- `DesktopLayout` 최하단에 `<SettingsModal isOpen={isSettingsOpen} onClose={() => setIsSettingsOpen(false)} />`를 렌더링합니다.

### 3. 기존 수강생 페이지 Import 경로 업데이트
#### [MODIFY] [Home.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/Home.tsx)
- `SettingsModal`의 임포트 경로를 새로운 공통 폴더 경로로 업데이트합니다.

## User Review Required
> [!NOTE]
> `SettingsModal`이 모든 사용자용 공통 모달로 변경되면서 내부의 "수강생" 전용 프로필 텍스트들이 동적 데이터로 변경됩니다. 디자인 틀은 그대로 유지됩니다.

## Verification Plan
1. `SettingsModal.tsx`를 이동하고 기존 `Home.tsx`에서 에러가 없는지 확인.
2. 강사 대시보드나 운영팀 화면 등 `DesktopLayout`을 사용하는 페이지에 접속.
3. 우측 상단 종 버튼 왼쪽에 **톱니바퀴 아이콘**이 생겼는지 확인.
4. 톱니바퀴 아이콘 또는 **아바타(프로필) > 설정**을 눌렀을 때, 현재 로그인된 관리자의 이름이 나타나는 설정 모달이 뜨는지 확인.
