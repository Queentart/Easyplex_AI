# 기술팀 대시보드(TechOps Center) 데이터 연동 플랜

현재 기술팀의 메인 대시보드(`TechTeamMgmt.tsx`)는 더미 데이터(하드코딩)에 의존하고 있어, 실제 기술팀 관리 페이지에서 일어나는 업로드 및 상호작용 데이터가 반영되지 않고 있습니다. 대시보드의 본질적인 목적에 맞게, 각 관리 페이지의 실제 데이터 소스와 대시보드를 완벽히 동기화하는 작업을 진행합니다.

## User Review Required

> [!IMPORTANT]
>
> - **스트리밍 상태 모니터링**: 기존 더미 데이터는 "Live Stream" 상태를 보여주고 있었으나, 실제 기술팀은 VOD를 업로드/수정하는 업무를 수행 중입니다. 대시보드의 해당 블록을 **[최근 업로드된 VOD 목록 및 상태]** 를 보여주는 형태로 변경해도 괜찮으실까요?
> - **시스템 로그(Daily Ops) 추적**: 기술팀이 장비 상태를 변경하거나, 새로운 VOD를 업로드할 때마다 자동으로 로그가 기록되는 통합 로깅 시스템(Local Storage 기반)을 신설하여 대시보드에 띄우려 합니다. 동의하시나요?

## Proposed Changes

### 1. 장비 알림 (Equipment) 영역 동기화
- **현재**: `equipmentList` (서버 인프라 더미 데이터)
- **변경**: `EquipmentMgmt.tsx`에서 실제 관리 중인 **"학생 장비 신청 내역"**(`easyplex_equipment_requests` 로컬 스토리지)을 불러오도록 연동합니다.
- **표시 로직**: 상태가 `Pending`(승인 대기)인 최신 요청들을 우선적으로 렌더링하여 업무 누락을 방지합니다.

### 2. 긴급 시스템 지원 (Tickets) 영역 동기화
- **현재**: `urgentTickets` (하드코딩)
- **변경**: `StudentsMgmt.tsx`에서 사용하는 **백엔드 API(`GET /api/v1/tech/student-mgmt/tickets`)** 를 대시보드에서도 동일하게 호출(React Query 혹은 fetch)하여 실제 접수된 학생들의 문의/장애 티켓을 렌더링합니다.
- **표시 로직**: 전체 티켓 중 상태가 `Open`이거나 우선순위가 높은(`Critical`, `High`) 티켓 위주로 필터링하여 노출합니다.

### 3. 스트리밍 관리 (Streams) 영역 동기화
- **현재**: `streamHealth` (가상의 라이브 룸 상태)
- **변경**: `StreamMgmt.tsx`에서 사용하는 `vodService.getVODs()`를 호출하여, 기술팀이 **가장 최근에 업로드 및 수정한 VOD(지난 강의) 데이터 3~4건**을 대시보드에 최신순으로 띄웁니다.

### 4. 통합 시스템 로그 (Daily Ops Logs) 구축
- **신규 로직**: `src/api/opsLogService.ts`를 생성하여 통합 로그 기록을 담당하게 합니다.
- 기술팀이 1) 새 VOD를 등록하거나 수정했을 때, 2) 장비 신청 상태를 업데이트했을 때 해당 서비스 객체에 로그를 남깁니다.
- 대시보드의 **시스템 로그(Daily Ops)** 블록은 이 `opsLogService`의 최신 로그 배열을 구독(Subscribe)하여 실시간으로 현황을 렌더링합니다.

## Verification Plan

### Automated Tests
- 모든 연동 시 타입 에러(TypeScript)가 발생하지 않도록 컴포넌트 인터페이스 수정 및 빌드 체크.

### Manual Verification
- `StreamMgmt` 탭에서 신규 VOD를 추가한 뒤, 대시보드로 돌아왔을 때 스트리밍 블록과 로그 블록에 해당 변경 내역이 즉시 반영되는지 확인.
- `EquipmentMgmt` 탭에서 장비 신청 상태를 변경했을 때 대시보드의 장비 알림 블록이 실시간으로 갱신되는지 확인.
- 백엔드가 켜져 있는 상태에서 대시보드의 시스템 지원(Tickets) 블록에 실제 DB의 티켓이 렌더링되는지 점검.
