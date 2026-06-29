# TechOps Dashboard Integration Task List

- [x] 1. `opsLogService` 통합 로깅 시스템 구축 (로컬스토리지 기반)
- [x] 2. `StreamMgmt.tsx` 연동
  - [x] VOD 신규 등록 및 수정 시 `opsLogService`에 자동 로깅 처리
- [x] 3. `EquipmentMgmt.tsx` 연동
  - [x] 장비 상태(Pending/Shipped 등) 변경 시 `opsLogService`에 자동 로깅 처리
- [x] 4. 대시보드(`TechTeamMgmt.tsx`) UI 컴포넌트 실시간 데이터 바인딩
  - [x] 장비 알림 블록: `easyplex_equipment_requests` 스토리지 데이터 바인딩 (Pending/최신순)
  - [x] 스트리밍 모니터링 블록: `vodService.getVODs()` 데이터 바인딩 (최신 업로드 VOD)
  - [x] 시스템 로그 블록: `opsLogService` 통합 로그 데이터 바인딩
  - [x] 긴급 시스템 지원 블록: 백엔드 API (`/api/v1/tech/student-mgmt/tickets`) 호출 및 연동
- [x] 5. 수동 테스트 및 에러 검수 (Verification)
