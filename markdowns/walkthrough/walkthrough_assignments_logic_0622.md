# 과제(Assignments) 모달 기반 시스템 워크스루

제안하신 "모달 중심의 효율적인 화면 이동 단축" 플랜에 따라 데이터베이스 변경부터 프론트엔드 모달 UI 연동까지 모두 마무리되었습니다. 이제 강사와 수강생 모두 직관적으로 팝업창(모달)을 통해 과제 업무를 수행할 수 있습니다.

## 주요 변경 사항

### 🗄️ 백엔드 (Database & API)
1. **과제 모델 생성 및 업데이트**:
   - `assignment_tasks` 데이터베이스 테이블을 추가하여, 강사진이 생성하는 **문제 정의**를 체계적으로 관리합니다.
   - 기존의 `assignments` 테이블은 **학생의 제출물(Submission)**으로 활용되며, 각각이 어떤 `assignment_tasks`에 속하는지(`task_id`) 연결하였습니다.
   - `alembic`을 통해 Docker 내부의 PostgreSQL 데이터베이스로 스키마 마이그레이션까지 정상 반영되었습니다.
2. **API 연동 (`/api/v1/assignments`)**:
   - `/tasks`: 과제 조회 및 생성 (강사는 생성, 수강생은 목록 조회)
   - `/tasks/{task_id}/submit`: 수강생 전용 과제 제출 처리
   - `/tasks/{task_id}/submissions`: 강사용 제출 현황 조회
   - `/generate-grading`: LangChain LLM 기반 채점 진행
   - `/submissions/{submission_id}/grade`: AI 예측 점수 참고 후 최종 점수(Final Score) 확정

### 👨‍🏫 강사진(Instructor & Mentor) 워크플로우
- **새 과제 등록 모달**: 우측 상단의 `+ New Assignment`를 클릭하면 모달 창이 열립니다. 제목, 설명, 기한을 적고 추가하면 즉시 "Active Assignments" 목록에 반영됩니다.
- **제출 현황 확인**: 과제 리스트 우측의 `View Submissions` 버튼을 누르면 해당 과제를 제출한 학생 목록으로 하단 테이블이 전환됩니다.
- **AI 채점 및 검토 모달**: 
  - 학생 목록에서 `Review & Grade`를 클릭하면 해당 학생의 제출 내용이 모달로 뜹니다.
  - 모달 안의 `Run AI Auto-Grade` 버튼을 클릭하여 백엔드 LLM 모델에 채점을 요청합니다.
  - 예측된 점수와 확신도(Confidence), 피드백을 확인하고, 필요 시 `Final Score`와 `Final Feedback`을 수정한 뒤 `Approve & Save Grade`를 누르면 학생의 점수가 최종 반영됩니다.

### 👩‍🎓 수강생(Student) 워크플로우
- **과제 작성 및 제출 모달**: 과제 목록에서 `Start Assignment` (제출 전) 또는 `Edit Submission` (제출 후) 버튼을 클릭합니다.
- 과제 설명과 제출 에디터 창이 모달 안에 나란히 뜹니다. 
- 내용을 텍스트 영역에 적고 하단의 `Submit Assignment` 버튼을 누르면, 화면 깜빡임 없이 즉각적으로 상태가 `submitted`로 갱신됩니다.

> [!TIP]
> 이제 페이징 처리 없이 한 페이지 내에서 빠르게 과제를 내고, 내역을 보며, 여러 학생의 제출물을 연속으로 모달 팝업으로 불러와 연속 채점을 할 수 있게 되었습니다. 테스트를 위해 강사 계정으로 로그인하셔서 우측 상단 `+ New Assignment` 로 과제를 먼저 생성해 보세요!
