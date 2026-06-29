# Profile Dropdown Menu Implementation Plan

사용자 프로필(아바타)을 클릭했을 때 마이 페이지, 설정, 로그아웃 등의 기능을 포함한 드롭다운 메뉴를 팝업 형태로 띄우는 기능의 구현 계획입니다. 알림 팝업과 유사한 구조를 가지되, 내용은 메뉴 리스트 형태로 구성합니다.

## User Review Required
> [!NOTE]
> 해당 드롭다운은 UI 구성만 먼저 구현하게 됩니다. "마이 페이지 이동"이나 "설정", "로그아웃"을 눌렀을 때 실제로 이동할 라우팅 주소나 인증 로직이 아직 연결되지 않은 상태라면, 클릭 시 임시로 알림(Alert)이 뜨거나 로그만 남기도록 구현할 예정입니다. 이후 백엔드/라우팅이 준비되면 연결해 주세요.

## Proposed Changes

### Frontend Components

#### [NEW] [ProfileDropdown.tsx](file:///c:/Easyplex_AI/frontend/src/components/common/ProfileDropdown.tsx)
- 알림 센터(`NotificationDropdown.tsx`)와 유사한 팝업 형태의 컴포넌트 생성.
- `isOpen`과 `onClose` props를 받아서 렌더링 제어.
- `useEffect`와 `useRef`를 사용하여 팝업 외부 클릭 시 팝업이 닫히도록(`handleClickOutside`) 구현.
- 내용 구성:
  - 사용자 정보 요약 (이름/이메일 등 - 임시 더미 데이터 사용)
  - 마이 페이지 이동 버튼 (`person` 아이콘)
  - 설정 버튼 (`settings` 아이콘)
  - 로그아웃 버튼 (`logout` 아이콘)
- CSS 인라인 스타일 또는 클래스를 통해 메뉴 아이템들에 Hover 효과 부여.

#### [MODIFY] [Header.tsx](file:///c:/Easyplex_AI/frontend/src/components/common/Header.tsx)
- 프로필 드롭다운의 상태 관리를 위한 `isProfileOpen` 상태(State) 추가.
- `header__avatar` 영역을 클릭 가능하도록 클릭 이벤트 핸들러 부착.
- 아바타 요소를 감싸는 부모 `div`에 `position: 'relative'` 속성을 주어, 드롭다운 메뉴가 아바타 하단에 절대 위치(`absolute`)로 배치되도록 수정.
- 새로 만든 `ProfileDropdown` 컴포넌트 임포트 및 렌더링 추가.

## Verification Plan

### Manual Verification
1. 브라우저에서 대시보드 화면 렌더링 확인.
2. 헤더 우측의 `S` (또는 사용자 이니셜) 프로필 아바타를 클릭.
3. 드롭다운 팝업이 부드럽게 나타나며, 내부에 프로필 정보, 마이 페이지, 설정, 로그아웃 버튼이 있는지 확인.
4. 메뉴 아이템에 마우스를 올렸을 때 호버 효과가 적용되는지 확인.
5. 메뉴 바깥 빈 공간을 클릭했을 때 드롭다운 메뉴가 정상적으로 닫히는지 확인.
