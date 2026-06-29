# 수강생 참여율(출석) 기능 구현 계획

수강생 홈 화면의 "참여율" 블록에 대한 기능 구현 방안 및 더미 데이터 생성 계획입니다.

## 질문에 대한 답변 및 아키텍처 제안
1. **수강생 측에서 출석 체크를 하면 갱신해야 하나요?**
   - 네, 맞습니다. 수강생이 QR 코드 등을 통해 출석 체크를 하면 자동으로 출석(PRESENT) 또는 지각(LATE)으로 기록되어야 합니다.
2. **운영팀 측에서 쏴줘야(동기화해 줘야) 하나요?**
   - 이 부분도 필요합니다. 줌(Zoom)이나 고용24와 같은 외부 시스템의 실제 접속/수강 시간 데이터를 바탕으로 운영팀이 데이터를 동기화하거나 보정(수정)할 수 있어야 합니다.
3. **결론: 둘 다 가능해야 하나요?**
   - **하이브리드(Hybrid) 방식**이 가장 완벽합니다. 기본적으로는 시스템에서 수강생의 액션(QR 스캔)으로 출석을 기록하되, 운영팀이나 강사진이 언제든지 백오피스에서 수동으로 이를 덮어쓰거나 수정할 수 있는 권한과 API가 제공되어야 오류를 최소화할 수 있습니다.

## Proposed Changes

### 1. Database Model 수정
- 기존 `app.models.attendance.AttendanceStatus` Enum에 조퇴를 의미하는 `EARLY_LEAVE` 상태를 추가합니다. (기존: PRESENT, LATE, ABSENT, EXCUSED)

### 2. Backend API 구현
- **학생용 통계 조회 API**: `GET /api/v1/students/attendance/stats` 
  - 현재 로그인한 학생의 이번 달 Lates(지각), Absences(결석), Early Leaves(조퇴) 횟수를 카운트하고 전체 참여율(Rate)을 계산하여 반환합니다.
- **운영팀/강사용 출결 수정 API**: (이미 Ops 모델쪽에 일부 구현되어 있을 수 있으나, 필요시 보완) `PUT /api/v1/ops/attendance/{id}`
- **학생 QR 출석 API**: `POST /api/v1/students/attendance/check-in`

### 3. Frontend 연동
#### [MODIFY] [Home.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/Home.tsx)
- 하드코딩된 `attendanceStats` 모의 데이터 대신 새롭게 만든 `GET /api/v1/students/attendance/stats` API를 호출하여 실제 DB 데이터를 화면에 렌더링하도록 수정합니다.

### 4. Dummy Data 및 Alembic Migration
- Alembic Migration을 생성하여 `AttendanceStatus` Enum에 `EARLY_LEAVE`를 추가하는 스키마 변경을 반영합니다.
- `seed_attendance.py` 등의 시드 스크립트를 작성하고 실행(Docker 컨테이너 포함)하여, 이번 달 기준의 풍부한 더미 출결 데이터(지각 1회, 결석 0회 등 UI와 유사한 형태)를 삽입합니다.

## User Review Required
> [!IMPORTANT]
> 출결 데이터는 매일 1개의 레코드가 생성되는 구조로 더미 데이터를 삽입할 예정입니다. 
> 현재 접속한 달(예: 6월)을 기준으로 이번 달의 과거 날짜들에 대해 모두 더미 데이터를 생성해 두어도 괜찮으신가요?

## Verification Plan
1. Alembic 마이그레이션이 성공적으로 DB 스키마를 업데이트하는지 확인합니다.
2. 더미 데이터 스크립트 실행 후 DB에 출석 레코드가 생성되었는지 확인합니다.
3. 브라우저에서 수강생 Home 화면에 접속했을 때, 하드코딩된 데이터가 아닌 DB에 들어간 더미 데이터를 기반으로 **Lates, Absences, Early Leaves, Rate**가 정확하게 계산되어 표시되는지 확인합니다.
