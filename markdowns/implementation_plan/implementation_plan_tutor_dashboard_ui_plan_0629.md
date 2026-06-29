# 보조강사/멘토(Tutor) 맞춤형 대시보드 구현 플랜

주강사(Instructor)와 보조강사/멘토(Tutor)는 역할과 주 업무가 다르므로, `/instructor` 경로에 진입 시 로그인한 사용자의 권한(`role`)에 따라 맞춤형 대시보드 뷰를 제공하도록 구조를 개편합니다.

멘토의 주요 업무는 **학생과의 직접적인 소통(상담, 질문 답변) 및 멘토링 일지 작성**에 집중되어 있으므로 이를 최상단 우선순위로 둡니다.

## User Review Required

> [!IMPORTANT]
> 아래 제안된 멘토 대시보드의 **우선순위(크기 및 강조 기준)**가 실제 멘토의 업무 중요도와 부합하는지 확인 부탁드립니다. 주강사와 달리 '과제 채점'보다 **'멘토링 일지 작성 현황'**을 상단 High Priority로 끌어올렸습니다.

## Open Questions

> [!WARNING]
> 현재 멘토 전용 모의 데이터로 사용할 **"멘토링 예정 일정(Upcoming Mentoring Sessions)"**이나 **"최근 답변한 질문 목록"** 등의 데이터가 조금 부족할 수 있습니다. 멘토 대시보드 렌더링 시점에 시각적 풍부함을 더하기 위해 `instructor.ts`에 멘토 전용 더미 데이터를 추가해도 괜찮을까요?

## Proposed Changes

### 1. 컴포넌트 구조 분리 (`InstructorDashboard.tsx`)
기존의 `InstructorDashboard.tsx`에서 로그인한 유저의 역할(`role`)을 판별하여 뷰를 분기합니다.

- `role === 'instructor'` -> `<InstructorDashboardView />` 렌더링 (방금 구현한 주강사용 뷰)
- `role === 'tutor'` -> `<TutorDashboardView />` 렌더링 (신규 구현할 멘토용 뷰)

### 2. 멘토(Tutor) 전용 대시보드 UI 레이아웃 설계 (`TutorDashboardView.tsx`)
CSS Grid 레이아웃(`.instructor-dashboard-grid`)을 재사용하되, 카드 배치와 크기를 멘토의 업무에 맞게 재구성합니다.

#### High Priority (최상단, 가장 큰 영역, 강조 색상 - Primary/Warning/Success)
- **학생 상담 알림 (Student Counseling)**: 멘토가 배정받은 집중 관리 대상 학생이나 예정된 1:1 멘토링 세션을 크게 노출.
- **학습 질문 게시판 (Learning Questions)**: 멘토가 답변을 달아야 할 미해결 기술 질문들을 상단에 배치하여 빠른 대응 유도.
- **멘토링 일지 (Mentoring Logs)**: 멘토의 필수 업무인 일지 제출 현황(작성 대기 중인 세션, 최근 승인된 일지 등)을 대형 카드로 배치.

#### Medium Priority (중단 영역, 기본 카드 크기)
- **과제 (Assignments)**: 주강사를 보조하여 1차 피드백이나 코드 리뷰(Peer Review)를 진행해야 하는 과제 목록.
- **강의 자료 관리 (Course Materials)**: 최근 등록된 강의 자료를 확인하여 멘토링에 참고할 수 있도록 목록 제공.

#### Low Priority (하단 영역, Quick Links)
- **실시간 스트리밍 링크 (Class Streams)**: 보조 진행자로 참여할 수 있는 링크.
- **학습 커리큘럼 로드맵 (Curriculum Roadmap)**: 전체 과정 확인용 퀵 링크.

### 3. 모의 데이터(Dummy Data) 분리/추가 (`instructor.ts`)
- `tutorMentoringSessions`: 멘토 전용 다가오는 멘토링 세션 데이터.
- `tutorPendingLogs`: 작성이 필요한 멘토링 일지 대기열 데이터.

### 4. 스타일링 업데이트 (`Instructor.css`)
- 주강사용 CSS 클래스(`.priority-high` 등)를 공유하여 디자인 일관성(Aesthetics)을 유지하되, 멘토 대시보드에 필요한 특정 강조 포인트(예: `.card-highlight-success`)를 추가합니다.

## Verification Plan

### Automated Tests
- TypeScript 컴파일러를 통해 `TutorDashboardView` 컴포넌트 분리 과정에서의 Props 타입 오류 및 누락 방지.

### Manual Verification
- 권한이 `tutor`인 사용자 정보로 로그인(또는 강제 목업 유저 설정)하여 `/instructor` 진입.
- 주강사용 뷰 대신 **멘토 전용 대시보드 뷰**가 정상적으로 나타나는지 확인.
- 멘토링 일지 및 질문 게시판이 상단 High Priority 영역에 정상 노출되는지 점검.
