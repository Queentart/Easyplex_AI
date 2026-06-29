# EduOps 대시보드 추가 및 UI/기능 구현 플랜

운영팀(EduOps) 측의 주요 관리 요소들을 한눈에 파악할 수 있는 핵심적인 대시보드 페이지를 신규 추가/복원하고, 메뉴의 최상단에 배치합니다. 대시보드의 요소들은 중요도에 따라 시각적 계층(크기, 색상, 배치 등)을 다르게 하여 설계됩니다.

## User Review Required

> [!IMPORTANT]
> 아래 제안된 대시보드의 **우선순위(크기 및 강조 기준)**가 실제 운영팀의 업무 중요도와 부합하는지 확인 부탁드립니다.
> 기존에 `/eduops` 경로가 '학생 관리' 페이지로 연결되어 있었으나, 이를 '대시보드'로 변경하고 '학생 관리'는 `/eduops/students`로 이동하는 라우팅 변경이 포함되어 있습니다.

## Open Questions

> [!WARNING]
> 1. 문의사항 및 공지사항, 강의 일지 등 일부 모의(Dummy) 데이터가 공용 데이터 파일(`eduops.ts`)에 없는 경우 대시보드용 요약 데이터를 새로 정의해야 합니다. 이 부분에 대한 하드코딩 데이터를 임의로 생성해도 될까요?
> 2. 대시보드의 주요 색상 테마를 브랜드 컬러(예: Primary color) 외에 경고/주의를 나타내는 색상(Red/Orange)을 적극 활용하여 강조할 부분(예: 출석 경고, 미해결 문의)을 시각적으로 돋보이게 설계해도 괜찮을까요?

## Proposed Changes

### 1. 라우팅 및 좌측 메뉴 업데이트 (Frontend Data & App)
좌측 사이드바 메뉴의 최상단에 대시보드를 추가하고 기존 경로를 수정합니다.

#### [MODIFY] [eduops.ts](file:///c:/Easyplex_AI/frontend/src/data/eduops.ts)
- `opsMenu` 배열의 첫 번째 항목으로 `{ id: 'dashboard', label: '대시보드', icon: 'dashboard', path: '/eduops' }` 추가.
- 기존 '학생 관리' 메뉴의 `path`를 `/eduops/students`로 변경.
- 대시보드에 쓰일 추가 통계용 Dummy Data(예: 미답변 문의 수, 최근 공지사항, 데이터 동기화 이슈 요약 등) 정의.

#### [MODIFY] [App.tsx](file:///c:/Easyplex_AI/frontend/src/App.tsx)
- `Route path="/eduops"`를 신규 생성할 `EduOpsDashboard` 컴포넌트와 매핑.
- `Route path="/eduops/students"`를 기존 `StudentMgmt` 컴포넌트와 매핑하도록 라우팅 수정.

### 2. UI 설계 및 신규 컴포넌트 구현 (Frontend Pages)
우선순위에 따라 카드의 크기(Grid Column Span), 폰트 크기, 색상을 달리하여 대시보드 UI를 구성합니다.

#### [NEW] EduOpsDashboard.tsx (경로: `c:/Easyplex_AI/frontend/src/pages/eduops/EduOpsDashboard.tsx`)
CSS Grid 레이아웃을 사용하여 아래와 같이 계층화된 대시보드를 구현합니다.

- **High Priority (최상단, 가장 큰 영역, 강조 색상 적용)**
  - **학생 관리 요약 (Student Management):** 전체 활성 학생 수, 출석 주의/경고 대상자 수, 최근 상담 로그 등을 큰 카드 형태(Grid 전체 너비 활용)로 배치. 출석 경고 등은 붉은색/주황색 계열로 강조.
  - **문의 및 공지사항 (Inquiries & Announcements):** 미해결 문의 사항 수, 최신 중요 공지사항을 한눈에 볼 수 있도록 상단 쪽에 중대형 카드로 배치.

- **Medium Priority (중단, 기본 카드 크기)**
  - **데이터 동기화 (Data Sync):** 최근 동기화 시간 및 데이터 불일치(Mismatch) 발생 건수 등을 표시. 이슈 발생 시 아이콘과 함께 시각적 경고 뱃지 제공.
  - **AI 자동화 (AI Automation):** 최근 Flagged된 쿼리 건수 또는 생성된 리포트 상태 요약 표시.
  - **강의 자료 및 일지 (Lecture Logs):** 최근 등록된 강의 일지 요약 리스트.

- **Low Priority (하단, 작은 버튼 및 링크 형태)**
  - **실시간 강의 링크, 학습 커리큘럼 로드맵, 운영팀 설정:** 상세 내용을 대시보드에 직접 띄우기보다는, 빠르게 해당 메뉴로 이동할 수 있는 바로가기 버튼(Quick Links) 형태로 하단에 콤팩트하게 배치.

#### [MODIFY] [EduOps.css](file:///c:/Easyplex_AI/frontend/src/pages/eduops/EduOps.css)
- 대시보드용 CSS Grid 클래스(예: `.eduops-dashboard-grid`) 및 우선순위에 따른 카드 변형 스타일(`.card-high-priority`, `.card-medium-priority`, `.card-quick-links`) 추가.

## Verification Plan

### Automated Tests
- TypeScript 컴파일러와 ESLint를 통해 라우팅 변경 및 신규 컴포넌트에 타입/구문 오류가 없는지 확인. (`npm run build` 또는 컴파일러 피드백 활용)

### Manual Verification
- 운영팀(EduOps) 권한으로 로그인 후 `/eduops` (대시보드) 접속.
- 왼쪽 사이드바 최상단에 '대시보드' 메뉴가 정상적으로 표시되고 활성화되는지 확인.
- 우선순위에 따른 UI 크기/색상 강조가 의도대로 반영되었는지 시각적 확인.
- 하위 메뉴(학생 관리 등) 링크가 정상적으로 라우팅되는지 확인.
