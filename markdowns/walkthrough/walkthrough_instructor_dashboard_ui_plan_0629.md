# 주강사 대시보드 개편 완료 안내

요청하신 **주강사(Instructor) 통합 대시보드**의 UI 레이아웃 개편과 우선순위 기반 시각화 작업이 모두 완료되었습니다.

## 핵심 변경 내용

### 1. 업무 우선순위를 반영한 UI 구조 재배치 ([InstructorDashboard.tsx](file:///c:/Easyplex_AI/frontend/src/pages/instructor/InstructorDashboard.tsx))
기존에 단순 통계 타일들이 나열되던 상단을 주강사의 핵심 액션 위주로 개편했습니다.

- **High Priority (최상단, 강조 카드)**
  - **학습 질문 게시판**: 미답변 질문 리스트가 가장 먼저 보이도록 배치했습니다. 특히 `Urgent(긴급)` 속성이 있는 질문은 붉은색 배경과 텍스트로 강하게 시선을 끌도록 처리했습니다.
  - **과제 현황**: 남은 채점 건수를 브랜드 포인트 컬러(Primary)로 크게 표시하고, 최근 마감된 과제들의 제출/채점 비율을 한눈에 확인할 수 있습니다.
  - **학생 상담 알림**: AI가 `High` 긴급도로 추천한 멘토링 개입 필요 학생 리스트를 띄우고, 좌측에 붉은색 라인(Border)을 추가해 심각성을 강조했습니다.

- **Medium Priority (중단 영역)**
  - **학습 일지 현황**: 최근 제출된 일지의 상태를 표시합니다. 리뷰가 필요한 일지는 `warning` 뱃지로 표시됩니다.
  - **최근 업로드된 강의 자료**: 새롭게 추가된 강의 자료들의 종류(PDF, Video 등)와 업로드 일자를 모아 보여줍니다.

- **Low Priority (하단 영역)**
  - **Quick Links**: 실시간 스트리밍 접속과 전체 커리큘럼 편집 화면으로 넘어갈 수 있는 아기자기한 버튼 형태의 바로가기를 하단에 배치했습니다.

### 2. 가상 데이터(Dummy Data) 주입 ([instructor.ts](file:///c:/Easyplex_AI/frontend/src/data/instructor.ts))
대시보드에서 다채로운 화면을 렌더링하기 위해 다음 데이터를 추가했습니다.
- `pendingQuestions`: 급한 질문과 일반 질문 포함
- `recentMaterials`: 최근 등록된 강의 보조 자료들
- `recentLogs`: 보조강사 및 본인이 작성한 일지 내역

### 3. 반응형 스타일링 추가 ([Instructor.css](file:///c:/Easyplex_AI/frontend/src/pages/instructor/Instructor.css))
- 각 카드의 중요도에 맞춰 상단 테두리 선의 색상(Warning, Primary, Danger)이 다르게 나타나도록 `.card-highlight` 클래스와 CSS 가상 요소를 적용했습니다.
- 마우스를 올렸을 때 자연스럽게 떠오르는 호버(Hover) 애니메이션을 추가하여 앱을 사용할 때 좀 더 생동감(Dynamic Aesthetic)이 느껴지도록 구현했습니다.

## 테스트 방법
1. 로컬 개발 서버(`npm run dev`) 실행
2. 강사 계정으로 로그인 후 **대시보드(`/instructor`)** 접속
3. 우선순위에 따른 카드 크기와 붉은색/주황색의 경고성 알림들이 시각적으로 잘 와닿는지 확인해 주세요!

> [!TIP]
> 카드 위에 마우스를 올려보시면 가벼운 애니메이션과 그림자 효과가 있어 좀 더 프리미엄 앱 같은 느낌을 받으실 수 있습니다. 색감 조정이 필요하시다면 언제든 피드백 주세요.
