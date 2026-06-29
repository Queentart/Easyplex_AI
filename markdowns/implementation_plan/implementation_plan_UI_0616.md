# 강사 및 멘토 페이지 UI 구성 계획

현재 `CourseMaterials`, `TrainingLogs`, `MentoringLogs` 페이지가 기본 Tailwind 컨테이너로만 이루어져 있어 좌측 사이드바가 연동되지 않고 있으며, 디자인 퀄리티 또한 낮습니다. 이를 `DesktopLayout`과 EasyPlex 프리미엄 CSS 토큰을 사용하여 세련된 프리미엄 UI로 재작성합니다.

## Proposed Changes

### 프론트엔드 (UI 컴포넌트 재구성)

#### [MODIFY] [CourseMaterials.tsx](file:///c:/Easyplex_AI/frontend/src/pages/instructor/CourseMaterials.tsx)
- `DesktopLayout` 컴포넌트를 연동하여 사이드바와 상단 헤더가 정상 표시되도록 수정.
- **디자인 구성:** 
  - 상단: 드래그 앤 드롭을 지원하는 모던한 파일 업로드 영역 (Glassmorphism 효과 및 점선 테두리 마이크로 애니메이션)
  - 하단: 파일 유형(PDF, Excel 등) 아이콘과 업로드 일시, 용량 등이 정리된 우아한 데이터 테이블 카드. 다운로드 및 삭제 버튼 추가.

#### [MODIFY] [TrainingLogs.tsx](file:///c:/Easyplex_AI/frontend/src/pages/instructor/TrainingLogs.tsx)
- 주강사용 학습 일지 페이지.
- `DesktopLayout` 연동 (`allowedRoles=['instructor']`에 의해 주강사만 접근 가능).
- **디자인 구성:**
  - 상단: 오늘의 학습 요약 및 특이사항을 빠르게 작성할 수 있는 세련된 텍스트 에디터 느낌의 입력 폼.
  - 하단: 날짜별로 정렬된 타임라인(Timeline) 형식의 과거 학습 일지 목록. 각 일지는 카드 형태로 부드러운 그림자와 호버 이펙트 적용.

#### [MODIFY] [MentoringLogs.tsx](file:///c:/Easyplex_AI/frontend/src/pages/instructor/MentoringLogs.tsx)
- 멘토용 멘토링 일지 페이지.
- `DesktopLayout` 연동 (`allowedRoles=['tutor']`에 의해 멘토만 접근 가능).
- **디자인 구성:**
  - 좌우 분할(Split) 레이아웃:
    - **좌측:** 현재 멘토가 담당하고 있는 수강생 리스트 사이드패널 (아바타, 상태 배지 등 표시).
    - **우측:** 선택된 수강생의 멘토링 히스토리 피드 및 새로운 멘토링 내용을 입력하는 채팅창/로그창 형태의 UI.

## Verification Plan
1. `instructor@easyplex.com`으로 로그인 후 **강의 자료 관리** 및 **학습 일지** 메뉴 진입, 프리미엄 UI 렌더링 확인.
2. `tutor@easyplex.com`으로 로그인 후 **강의 자료 관리** 및 **멘토링 일지** 메뉴 진입, 훈련 일지가 노출되지 않는 점과 멘토링 일지 전용 UI 렌더링 확인.
