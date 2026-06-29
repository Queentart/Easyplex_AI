# Assignments (과제 관리 및 AI 채점) 기능 구현 계획

제안해주신 **"모달(팝업)을 적극 활용하여 페이지 전환 시간을 단축하고 사용자 경험(UX)을 개선하는 방식"에 전적으로 동의합니다.**
과제 작성, 제출, 채점 등의 작업은 컨텍스트 흐름을 끊지 않고 현재 목록을 보면서 팝업 창에서 빠르게 처리하는 것이 현대적이고 효율적인 UI/UX 패턴입니다.

이에 맞춰 다음과 같이 모달 기반의 UI와 기능 개선, 그리고 백엔드 시스템(DB 및 API) 구축 계획을 제안합니다.

## 1. UI 구성 및 모달(팝업) 설계

### 👩‍🎓 수강생 측 UI (`student/Assignments.tsx`)
- **[과제 내용 보기 및 제출 모달]**
  - **트리거**: "Start Assignment" 또는 "View Details" 버튼 클릭
  - **기능**: 페이지 이동 없이 화면 중앙에 모달이 뜨고, 과제의 상세 내용(지시문, 기한 등)을 표시합니다.
  - **제출 폼**: 텍스트 에디터 또는 텍스트 영역을 모달 하단에 배치하여 과제 내용을 작성하고 "Submit" 버튼을 누르면 즉시 백엔드로 전송되며, 창이 닫히고 상태가 'submitted'로 자동 업데이트됩니다.

### 👨‍🏫 강사진 측 UI (`instructor/AssignmentsGrading.tsx`)
- **[새 과제 등록 모달 (New Assignment)]**
  - **트리거**: 상단의 "New Assignment" 버튼 클릭
  - **기능**: 과제 제목, 설명, 제출 기한(Deadline)을 입력하는 모달 창. 등록 완료 시 'Active Assignments' 목록에 즉시 반영.
- **[AI 채점 및 수동 검토 모달 (Grading Review)]**
  - **트리거**: 학생 제출물 목록에서 "Auto-Grade" 또는 상세 보기 버튼 클릭
  - **기능**: 학생이 제출한 **원본 내용**과 LLM이 분석한 **AI 예측 점수 및 피드백**을 모달 안에서 나란히 보여줍니다.
  - **액션**: 강사가 AI 피드백을 읽어본 후 필요시 점수나 코멘트를 수정하고 "Approve(최종 확정)" 버튼을 눌러 점수를 DB에 반영합니다.

## 2. 백엔드(DB & API) 연동 및 구조 개선

현재 `assignments.py` API는 LLM을 호출해 점수만 반환(`generate-grading`)할 뿐, 실제 과제(Task)와 제출물(Submission)을 저장하는 구조가 미비합니다. 이를 위해 데이터베이스와 API를 구축합니다.

### 🗄️ 데이터베이스 모델링 (`models/assignment.py`)
1. **`AssignmentTask` (새로 생성)**
   - 강사가 등록한 과제의 정보 (제목, 설명, 기한, 생성자 ID 등)
2. **`Assignment` (기존 모델 업데이트)**
   - 학생의 제출물 데이터. 새로 만든 `AssignmentTask`를 참조하는 `task_id` 외래키를 추가합니다.

### 🌐 API 엔드포인트 구축
- `GET /api/v1/assignments/` : 수강생/강사용 과제 목록 조회
- `POST /api/v1/instructor/assignments/` : 새 과제 생성 (강사 전용)
- `POST /api/v1/student/assignments/{task_id}/submit` : 과제 제출 (수강생 전용)
- `GET /api/v1/instructor/assignments/{task_id}/submissions` : 해당 과제의 학생별 제출 현황 및 채점 결과 목록
- `POST /api/v1/instructor/assignments/submissions/{submission_id}/grade` : 채점 결과 최종 반영 (AI 결과를 토대로 수동 확정)

## 3. 작업 순서 (Action Plan)

1. **Backend DB Migration**: `assignment.py` 모델 수정 및 Alembic 마이그레이션 실행.
2. **Backend API**: 과제 생성, 제출, 조회, 채점 반영 CRUD 엔드포인트 구현.
3. **Frontend UI**: 공통 Modal 컴포넌트 추가(또는 구현).
4. **Frontend 연동**: 수강생용 제출 모달 및 강사용 생성/채점 모달 UI 작업 후 API 연동.

---

> [!NOTE]
> 모달 기반 UX 제안은 매우 훌륭한 방향입니다! 
> 위 계획된 데이터 구조 및 API 명세, 모달의 기능 흐름에 동의하시면 **승인(Approve)**을 눌러주세요. 즉시 데이터베이스 모델링부터 코딩을 시작하겠습니다.
