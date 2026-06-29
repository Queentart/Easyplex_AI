# 참여율(출석) 기능 구현 완료

요청하신 "참여율" 블록에 대한 실제 DB 연동 및 더미 데이터 삽입 작업을 모두 완료했습니다.

## 주요 작업 내역
1. **[Alembic Migration](file:///c:/Easyplex_AI/backend/alembic/versions/f162003d3927_add_early_leave_to_attendancestatus.py)**: 기존의 출결 상태(PRESENT, LATE, ABSENT) 외에 프론트엔드의 화면에 맞게 "조퇴(EARLY_LEAVE)" 상태를 PostgreSQL `AttendanceStatus` Enum 에 추가했습니다.
2. **[백엔드 API 구현](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/student/attendance.py)**: `GET /api/v1/students/attendance/stats` 엔드포인트를 신규 생성하여, 접속한 학생의 이번 달 지각, 결석, 조퇴 횟수 및 전체 출석률(%)을 동적으로 계산하도록 로직을 구현했습니다.
3. **[더미 데이터 시딩](file:///c:/Easyplex_AI/backend/seed_attendance.py)**: 이번 달(6월) 1일부터 현재까지의 출결 데이터를 자동으로 생성해주는 스크립트를 작성하여 Docker 컨테이너 내에서 실행했습니다. 이로 인해 학생별로 지각, 결석, 조퇴 등이 포함된 현실적인 더미 데이터가 DB에 적재되었습니다.
4. **[프론트엔드 연동](file:///c:/Easyplex_AI/frontend/src/pages/student/Home.tsx)**: 수강생 홈 화면에서 기존의 하드코딩된 모의 데이터를 버리고, 방금 만든 통계 API를 직접 호출하여 실제 통계가 반영되도록 수정했습니다. 출석률(Rate)에 따라 80% 이상이면 `Safe(초록색)`, 미만이면 `Warning(빨간색)`으로 동적 UI를 적용했습니다.

## 확인 방법
수강생 계정으로 로그인한 뒤, `Home` 화면의 중간쯤 있는 **"참여율"** 블록을 확인해 보세요. 지각, 결석, 조퇴 카운트와 참여율이 실제 더미 데이터베이스의 수치 기반으로 렌더링되고 있을 것입니다.
