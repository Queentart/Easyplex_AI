# Announcement Attachment Fix & Modal Implementation Plan

## 1. Goal Description
현재 수강생 화면(Classroom)의 공지사항 첨부파일을 클릭했을 때 발생하는 `Not Found` 오류를 해결하고, 공지사항을 클릭하면 상세 내용을 볼 수 있는 모달(팝업) 창을 구현합니다. 또한 첨부파일 클릭 시 브라우저에서 바로 열리지 않고 다운로드가 진행되도록 개선합니다.

## 2. 원인 분석
- **Not Found 오류 원인**: 백엔드에서 정적 파일을 서빙하는 경로(main.py)는 `backend/uploads`를 가리키고 있으나, 파일을 저장하는 로직(announcements.py)은 `backend/app/uploads`를 가리키고 있어서 경로 불일치가 발생했습니다.

## 3. Proposed Changes

### Backend
#### [MODIFY] [announcements.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/ops/announcements.py)
- 파일 저장 시 사용되는 `base_dir` 경로 계산 로직을 수정하여 정확히 `backend/uploads/announcements`에 저장되도록 수정합니다.
- 기존에 잘못된 경로(`backend/app/uploads/announcements`)에 저장되어 있던 파일들은 올바른 폴더로 이동시킵니다.

### Frontend
#### [MODIFY] [Classroom.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/Classroom.tsx)
- 공지사항 아이템에 `onClick` 이벤트를 추가하여 클릭 시 선택된 공지사항 데이터를 상태(`selectedAnnouncement`)로 관리합니다.
- 선택된 공지사항이 있을 경우 화면 중앙에 모달(팝업)을 띄워 상세 내용과 첨부파일을 표시합니다.
- 첨부파일 링크에 `download` 속성을 추가하고, 필요한 경우 Blob 형태로 가져와 강제 다운로드를 유도하는 로직을 적용하여 첨부파일 다운로드가 실행되도록 합니다.

## 4. User Review Required
> [!IMPORTANT]
> 백엔드 파일 경로 구조 변경 및 프론트엔드 모달 UI 추가가 포함되어 있습니다. 제안된 계획이 요구사항에 맞는지 확인 후 승인해주시면 작업을 시작하겠습니다!
