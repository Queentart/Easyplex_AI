# 기술지원팀(TechOps) 대시보드 개편 플랜

현재 기술지원팀의 대시보드(`TechTeamMgmt.tsx`)는 시스템 상태(Uptime, Latency 등)를 나열하는 데 그치고 있어, 기술팀의 실제 주요 업무인 **장비 신청**, **학생 계정 관리**, **스트리밍 관리** 등을 직관적으로 파악하고 처리하기 어렵습니다.

이를 해결하기 위해 기술팀의 업무 중요도(우선순위)에 따라 UI 크기와 색상을 차등 배치하는 형태의 맞춤형 대시보드로 개편합니다.

## User Review Required

> [!IMPORTANT]
> 아래 제안된 기술팀 대시보드의 **업무 우선순위 배치**가 실제 운영 환경과 맞는지 확인 부탁드립니다. 특히 시스템 인프라 및 장비 상태를 최상단으로 올리고 계정 관련 이슈를 묶어 관리하도록 제안했습니다.

## Open Questions

> [!WARNING]
> 현재 `techops.ts`에 일부 모의 데이터가 있으나, **스트리밍 관리**와 관련된 구체적인 상태 데이터(스트리밍 지연 시간, 현재 활성화된 스트리밍 방 개수 등)가 부족합니다. 구현 시 해당 항목에 대한 모의(Dummy) 데이터를 추가로 생성하여 대시보드에 연동해도 괜찮을까요?

## Proposed Changes

### 1. UI 구조 재배치 및 우선순위 시각화 (`TechTeamMgmt.tsx`)
CSS Grid 또는 Tailwind CSS를 활용하여 카드의 크기와 배치, 그리고 상단 보더(Border) 색상을 활용한 시각적 중요도 구분을 적용합니다.

#### High Priority (최상단 영역, 강조 색상 적용)
- **장비 상태 및 유지보수 알림 (Equipment & Infrastructure)**: 
  - `Warning` 또는 `Needs Repair` 상태인 장비를 붉은색(`Danger`) 알림 뱃지와 함께 가장 크게 노출합니다.
  - 장비 수리/교체 신청(Equipment Request) 대기열을 바로 확인할 수 있게 만듭니다.
- **긴급 지원 티켓 (Urgent Tickets)**: 
  - 학생 및 계정 관리 중 발생한 비밀번호 초기화, 접속 불가 등 시스템 접근과 관련된 즉각적인 조치가 필요한 티켓 목록을 붉은색 테두리(`card-highlight-danger`) 카드로 표시합니다.

#### Medium Priority (중단 영역)
- **실시간 스트리밍 모니터링 (Stream Management)**: 
  - 현재 송출 중인 스트리밍 서버의 지연 시간(Latency) 및 대역폭(Bandwidth) 상태를 요약하여 보여줍니다 (`Info/Primary` 색상).
- **시스템 상태 및 계정 동기화 (System Health & Accounts)**:
  - 전체 시스템 Uptime과 더불어 최근 일일 계정 동기화(Daily Operations) 로그를 콤팩트한 리스트로 배치합니다.

#### Low Priority (하단 영역, Quick Links)
- 장비 신규 신청, 수동 계정 생성, 스트리밍 테스트 방 개설 등 자주 사용하는 기능을 빠르게 진입할 수 있는 **바로가기(Quick Links)** 버튼을 둥근 버튼 형태로 제공합니다.

### 2. 모의 데이터 확충 (`data/techops.ts`)
기존 데이터에 다음 항목들을 추가하거나 보완합니다.
- `streamHealth`: 스트리밍 서버 상태(방 제목, 상태, 버퍼링 여부 등)
- `urgentTickets`: 긴급 학생/계정 관련 문의(비밀번호 리셋 등)

### 3. 공통 CSS 활용 또는 스타일 추가
`Instructor.css`에서 구현했던 `.card-highlight` 관련 클래스(색상 띠 애니메이션 및 호버 효과 등)를 기술팀 대시보드에도 동일하게 적용하여 통일감 있고 인터랙티브한(Dynamic Aesthetic) 프리미엄 UI를 구현합니다.

## Verification Plan

### Automated Tests
- 리팩토링 중 데이터 속성 매핑(`data?.equipment` -> 새로 추가할 더미 데이터 구조)에 오류가 없는지 TypeScript 컴파일러 확인.

### Manual Verification
- 권한이 `admin`인 계정으로 `/techops` 에 접근하여 개편된 대시보드가 정상 렌더링되는지 확인.
- 긴급 티켓 및 장애 발생 장비가 의도한 색상(Danger/Warning)으로 즉시 눈에 띄는지 시각적 검증 수행.
