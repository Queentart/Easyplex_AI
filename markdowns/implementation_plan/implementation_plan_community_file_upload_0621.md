# 커뮤니티 글쓰기 기능 구현 (모달 및 파일 업로드)

수강생 커뮤니티(자유 게시판)에서 학생들이 자유롭게 글을 작성하고 다양한 파일을 첨부할 수 있는 기능을 구현합니다. 보안 상의 이유로 소스코드 파일 업로드는 엄격히 제한됩니다.

## User Review Required
> [!IMPORTANT]
> - 글쓰기 버튼의 위치: 페이스북/트위터처럼 **피드 최상단에 "새로운 글을 작성해보세요..." 텍스트가 있는 흰색 버튼 카드**를 배치하는 형태를 제안합니다. 우측 하단의 플로팅 버튼(FAB)은 현재 AI 챗봇이 사용 중이므로 이 방식이 가장 모바일 친화적입니다. 이 방식이 괜찮으신지 확인 부탁드립니다.
> - 허용/차단 파일 기준: `js, ts, py, java, c, cpp, html, css, json, sh, bat, exe` 등 실행 가능한 코드/스크립트 확장자를 명시적으로 차단하며, 그 외 이미지, 동영상, 음원, 일반 문서(pdf, doc, xls 등)는 모두 허용할 예정입니다. 

## Proposed Changes

### [NEW] `frontend/src/pages/student/components/CreatePostModal.tsx`
새로운 글쓰기 전용 모달(팝업) 컴포넌트를 생성합니다.
- **UI:** Tailwind CSS v4를 활용하여 화면 중앙에 나타나는 깔끔한 다이얼로그 모달 구현.
- **내용 입력:** 본문 작성을 위한 넉넉한 `textarea` 영역.
- **파일 업로드 기능:** `<input type="file" multiple>`을 활용한 네이티브 파일 선택 기능 연동.
- **아이콘:** Google Material Icons를 사용하여 파일 첨부(attach_file), 이미지(image), 비디오(movie), 오디오(audiotrack) 등을 직관적으로 표현.
- **유효성 검사 로직 (보안):** 
  - 파일 선택 시 JavaScript 로직 내에서 확장자를 검사합니다.
  - 코드 파일 확장자(예: `.py`, `.js`, `.java` 등)가 감지되면 브라우저 `alert`를 띄우고 파일 목록에서 제외합니다.
  - 업로드 허용 MIME 타입: `image/*, video/*, audio/*, application/*` (코드 제외).

### [MODIFY] `frontend/src/pages/student/Community.tsx`
- **글쓰기 버튼 추가:** 피드 최상단 영역에 글쓰기 모달을 띄우는 가로형 버튼 추가.
- **상태 관리:** `isCreateModalOpen` 상태를 추가하여 모달의 렌더링 제어.
- **글 등록 로직:** `CreatePostModal`에서 작성한 내용을 전달받아, 상단 상태 `posts` 배열의 맨 앞에 새로운 `CommunityPost` 객체를 추가하여 실시간으로 피드에 보이게 처리.

## Verification Plan
### Manual Verification
1. 커뮤니티 페이지 상단에 글쓰기 버튼이 예쁘게 노출되는지 확인.
2. 버튼 클릭 시 모달이 정상적으로 나타나고, X 버튼이나 배경을 누르면 닫히는지 확인.
3. 텍스트 입력 후 정상적으로 피드 맨 위에 글이 등록되는지 확인.
4. **보안 테스트:** `.py` 혹은 `.js` 등 코드 확장자를 가진 파일을 첨부 시도 시 경고창이 뜨며 첨부가 차단되는지 확인. 이미지 파일(`.jpg`, `.png`) 첨부 시 정상적으로 목록에 나타나는지 확인.
