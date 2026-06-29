# TechOps 스트리밍 및 VOD 관리 연동 플랜

기술지원팀(TechOps)이 `Streaming Management` 페이지에서 라이브 스트리밍을 관리할 뿐만 아니라, 이전 강의(VOD) 목록을 직접 업로드, 수정하고 이 내역이 수강생 화면에 실시간으로 반영되도록 개선합니다.

## User Review Required

> [!IMPORTANT]
> - 기술팀이 라이브 송출을 **[송출 종료(Archive)]** 할 때, 자동으로 해당 영상을 VOD 리스트에 추가하도록 메커니즘을 설계했습니다. 이때 주차(Week) 배정은 시스템이 '가장 최근 주차'로 자동 할당하되, 기술팀이 사후에 자유롭게 수정할 수 있도록 하는 방향이 괜찮으실까요?

## Open Questions

> [!WARNING]
> - 영상 플랫폼 링크 처리: "유튜브 링크가 잘렸을 경우 비메오 링크가 대신 들어감"이라는 요구사항에 따라, VOD 데이터 구조를 유튜브/비메오 두 개의 URL을 모두 입력받을 수 있게 변경하려고 합니다. 수강생이 VOD를 클릭할 때는 유튜브 링크를 최우선으로 열고, 유튜브 링크가 비어있으면 비메오 링크를 열어주도록 구현하면 될까요?

## Proposed Changes

### 1. `vodService.ts` (신규 생성)
- 현재 정적 파일(`data/student.ts`)에 박혀있는 `recordedLectures` 데이터를 브라우저 `localStorage` 기반으로 동기화하는 서비스 클래스(`vodService.ts`)를 구축합니다.
- VOD 목록 조회, 추가, 수정, 삭제 기능을 제공합니다.

### 2. 기술팀 `StreamMgmt.tsx` 개편
- **Archive(종료) 메커니즘 연동**: 
  - 진행 중인 라이브의 `[송출 종료 처리]` 버튼 클릭 시, 해당 영상의 제목, YouTube/Vimeo 링크를 가져와 자동으로 `vodService`에 새로운 VOD로 등록합니다.
- **VOD 관리자 패널 추가**:
  - 화면 하단에 **"과거 강의(VOD) 및 아카이브 관리"** 섹션을 신설합니다.
  - VOD 목록(주차별, 일별)을 테이블 또는 리스트 형태로 보여주고, 각 영상의 주차(Week), 제목, 유튜브 링크, 비메오 링크를 수정하거나 새로 업로드할 수 있는 폼을 제공합니다.

### 3. 수강생 뷰 연동 (`Home.tsx`, `Classroom.tsx`, `WeeklyVODBlock.tsx`)
- 기존에 정적 데이터를 바라보던 구조를 `vodService.getVODs()`를 호출하도록 변경합니다.
- 기술팀이 `StreamMgmt.tsx`에서 데이터를 수정하면 `storage` 이벤트를 발생시켜 수강생 측 VOD 블록이 새로고침 없이 실시간으로 리렌더링(갱신)되도록 만듭니다.
- `WeeklyVODBlock` 컴포넌트 내에서 개별 영상을 클릭했을 때, `youtubeUrl`이 존재하면 우선 실행하고, 없으면 백업인 `vimeoUrl`로 연결하는 Fallback(대체) 로직을 적용합니다.

## Verification Plan

### Automated Tests
- TypeScript 에러 검증 (새로운 VOD 타입 속성: `youtubeUrl`, `vimeoUrl` 적용에 따른 타입 미스매치 점검).

### Manual Verification
- 기술팀 계정으로 접속하여 `StreamMgmt` 화면에서 새 VOD 추가 및 주차(Week) 지정.
- 브라우저 새 탭에서 학생 계정으로 접속하여 방금 추가한 VOD가 올바른 주차 블록에 들어가는지, 썸네일은 갱신되는지 실시간 확인.
- VOD 수정에서 유튜브 링크를 삭제하고 비메오 링크만 남겼을 때, 수강생 화면에서 클릭 시 비메오로 올바르게 Fallback 연결되는지 검증.
