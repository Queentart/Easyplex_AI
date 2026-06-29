# 주강사(Instructor) 통합 대시보드 UI/기능 개편 플랜

주강사(Main Instructor)의 핵심 업무 흐름을 반영하여, 학생과의 소통 및 성적/상담 관리 등 가장 중요한 요소가 눈에 띄도록 대시보드 레이아웃을 계층적으로 재설계합니다.

## User Review Required

> [!IMPORTANT]
> 아래 제안된 대시보드의 **우선순위(크기 및 강조 기준)**가 실제 주강사의 업무 중요도와 부합하는지 확인 부탁드립니다. 특히 '학습 질문 게시판', '학생 상담', '과제'를 최우선 순위로 배치했습니다.

## Open Questions

> [!WARNING]
> 현재 대시보드 연동용 모의 데이터(`instructor.ts`)에 **학습 질문 게시판의 미답변 질문 목록**이나 **최근 업로드된 강의 자료**, **학습 일지 요약** 데이터가 부족합니다. 이 부분을 채우기 위해 가상의 더미(Dummy) 데이터를 추가로 생성하여 화면에 렌더링해도 괜찮을까요?

## Proposed Changes

### 1. 라우팅 및 사이드바 메뉴 (현행 유지)
- 기존의 좌측 메뉴(`instructorMenuItems`) 항목과 경로는 유지하며, 주강사용 권한에 맞춰 접근 가능하도록 설정되어 있는 현재 구조를 활용합니다.

### 2. UI 설계 및 신규 컴포넌트 레이아웃 (`InstructorDashboard.tsx`)
CSS Grid 레이아웃을 적용하여 다음과 같이 중요도별로 크기와 배치를 달리합니다.

#### [MODIFY] [InstructorDashboard.tsx](file:///c:/Easyplex_AI/frontend/src/pages/instructor/InstructorDashboard.tsx)
기존의 통계 나열식 대시보드를 계층적 구조로 개편합니다.

- **High Priority (최상단, 가장 큰 영역, 시각적 강조 - Red/Orange/Primary Color)**
  - **학습 질문 게시판 (Learning Questions)**: 미답변 질문 목록을 리스트업. 넓은 영역을 할당하여 바로 내용을 확인하고 답변 창으로 이동할 수 있도록 함. (주의 색상 뱃지 활용)
  - **과제 (Assignments)**: 채점해야 할 과제 수, AI 자동 채점 완료 내역, 마감 임박 과제 등을 돋보이는 통계 수치와 리스트로 배치.
  - **학생 상담 (Student Counseling)**: AI가 위험군으로 식별하여 상담을 제안한 학생 목록(Urgency: High)을 붉은색 계열로 띄워 즉각적인 조치를 유도.

- **Medium Priority (중단 영역, 기본 카드 크기 - 일반/무채색 계열)**
  - **학습 일지 (Training Logs)**: 최근 등록된 학습 일지 현황 표시.
  - **강의 자료 관리 (Course Materials)**: 최근 등록된 강의 자료 또는 다음 차시를 위해 업로드해야 할 자료 상태.

- **Low Priority (하단 영역, 아이콘 기반의 Quick Links 버튼 형태)**
  - **실시간 스트리밍 링크 (Class Streams)**: 클릭 즉시 방송 메뉴로 넘어가는 빠른 버튼.
  - **학습 커리큘럼 로드맵 (Curriculum Roadmap)**: 전체 커리큘럼 현황으로 넘어가는 빠른 이동 버튼.

### 3. 모의 데이터(Dummy Data) 추가 (`instructor.ts`)
#### [MODIFY] [instructor.ts](file:///c:/Easyplex_AI/frontend/src/data/instructor.ts)
대시보드 표현을 위해 아래 데이터 구조를 추가/확장합니다.
- `pendingQuestions`: 학습 질문 게시판의 미해결 질문 리스트 데이터 추가
- `recentMaterials`: 최근 업로드된 강의 자료 리스트 데이터 추가
- `recentLogs`: 최근 작성된 학습 일지 요약 데이터 추가

### 4. 스타일링 업데이트 (`Instructor.css`)
#### [MODIFY] [Instructor.css](file:///c:/Easyplex_AI/frontend/src/pages/instructor/Instructor.css)
- `.instructor-dashboard-grid` 클래스 추가
- 우선순위에 따른 시각적 차등을 주기 위한 CSS 클래스(예: `.priority-high`, `.priority-medium`, `.quick-links-panel`, `.danger-alert` 등) 추가 정의.

## Verification Plan

### Automated Tests
- 타입스크립트 및 ESLint를 활용하여 새롭게 추가되는 Dummy Data 타입과 `InstructorDashboard` 컴포넌트 내 참조 오류가 없는지 확인.

### Manual Verification
- 주강사(Instructor) 계정으로 로그인 후 대시보드(`/instructor`) 진입.
- 설계된 우선순위대로 UI 컴포넌트(질문 게시판, 상담, 과제)가 상단에 강조되어 노출되는지 시각적으로 점검.
- 카드 내의 'View All' 또는 바로가기 버튼을 눌렀을 때 각 서브 메뉴 페이지로 정상 라우팅되는지 확인.
