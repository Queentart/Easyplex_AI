# TechOps VOD 편집 폼 모달(Modal) UI 개편 플랜

기술팀 대시보드 하단에 위치한 VOD(과거 강의) 추가 및 수정 폼을 모달(팝업) UI 형식으로 개편하여 사용자 경험을 향상시킵니다.

## User Review Required

> [!IMPORTANT]
> - VOD 수정 모달 내부에 기존에 없던 **[삭제(Delete)]** 버튼을 추가해 드리려고 합니다. (실수로 잘못 등록한 VOD 등을 지우기 위함) 해당 기능 추가에 동의하시나요?

## Open Questions

> [!WARNING]
> - 모달 UI의 디자인은 시스템 전체적인 트렌드에 맞추어 `backdrop-blur`(배경 블러 처리) 및 라운딩된 카드(`rounded-2xl`) 디자인을 채택할 예정입니다. 특별히 원하시는 색상 톤이나 아이콘 형태가 있다면 말씀해 주세요.

## Proposed Changes

### 1. `StreamMgmt.tsx` 렌더링 구조 변경
- 현재 `Card` 컴포넌트 하단에 인라인(Inline)으로 렌더링되던 `{showVodForm && ( ... )}` 부분을 제거합니다.
- 대신 화면 전체를 덮는 `fixed` 포지션의 모달 레이어를 추가합니다.

### 2. 모달(Modal) 컴포넌트 마크업
- **Overlay**: `fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm` 클래스를 사용하여 배경을 어둡게 하고 포커스를 모달로 집중시킵니다.
- **Container**: `bg-white w-full max-w-lg rounded-2xl shadow-2xl p-6` 형태로 세련된 팝업 컨테이너를 제작합니다.
- **Header**: Google Material Icons(`close`)를 활용한 닫기 버튼을 우측 상단에 배치합니다.
- **Form**: 기존의 입력 필드(Week, Title, YouTube URL, Vimeo URL)를 모달 안에 적절한 그리드 간격으로 재배치합니다.

### 3. 기능 연동 및 에러 방지 처리
- `Save` 버튼 클릭 시 기존의 `saveVod` 함수를 호출하여 브라우저 로컬스토리지 및 수강생 화면에 실시간 동기화되는 로직은 그대로 유지합니다.
- 팝업 닫기 시 모든 상태(State)가 올바르게 초기화되도록 로직을 점검합니다.
- 작업 완료 후, 이전에 발생했던 렌더링 에러나 타입/문법 에러가 없는지 자체 검수(Self-Correction)를 진행하여 완벽히 구동되는 상태로 제공하겠습니다.

## Verification Plan

### Automated Tests
- 코드 작성 후 타입스크립트 문법(Oxc/Vite 빌드) 검수.

### Manual Verification
- `StreamMgmt` 화면에서 "Add New VOD" 및 테이블의 "Edit" 버튼 클릭 시 모달이 정상적으로 나타나는지 확인.
- 백드롭(배경) 클릭이나 "닫기" 아이콘 클릭 시 모달이 닫히는지 확인.
- 모달 내 폼 저장 시 실시간으로 VOD 목록이 갱신되는지 점검.
