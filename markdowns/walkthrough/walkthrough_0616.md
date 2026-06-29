# 강사 및 멘토(Tutor) 기능 구현 완료 안내

요청하신 강사/멘토 기능 구현 및 빈 파일 정리를 성공적으로 마쳤습니다.

## 1. 백엔드 및 DB 정리 내용
- **역할 및 모델 추가**: `auth.py`의 `UserRole`에 `TUTOR`를 추가하고, `instructor_models.py`를 새로 만들어 **CourseMaterial(강의 자료)**, **TrainingLog(주강사용 훈련일지)**, **MentoringLog(멘토링일지)**, **ChatMessage(채팅 메시지)** 스키마를 정의했습니다.
- **API 연동**: `backend/app/api/v1/endpoints/instructor` 내부에 방치되었던 빈 파일들을 제거하고, 대신 `materials.py`, `logs.py`, `chat.py`, `router.py`를 작성하여 `main.py`에 연동했습니다. (운영팀(EDUOPS)에서 일지 조회가 가능하도록 API 형태 구성 완료)
- **더미 데이터 삽입**: `seed_data.py`를 실행하여 PostgreSQL 데이터베이스에 `instructor@test.com` (주강사) 및 `tutor@test.com` (멘토) 임시 계정을 추가했습니다.

## 2. 프론트엔드 적용 내용
- **사이드바 분기 처리**: `Sidebar.tsx`에서 로그인된 사용자의 역할(`user.role`)과 각 메뉴에 지정된 `allowedRoles`를 대조하여, 주강사 로그인 시 **[학습 일지]**만 보이고, 멘토 로그인 시 **[멘토링 일지]**만 보이도록 동적 렌더링 로직을 추가했습니다.
- **공통 기능**: `강의 자료 관리` 메뉴를 사이드바에 공통으로 추가하고, `CourseMaterials.tsx` 페이지를 생성했습니다.
- **글로벌 채팅 패널 (Drawer)**: `DesktopLayout.tsx` 우측 하단에 떠 있는 채팅 플로팅 버튼을 추가했습니다. 이를 클릭하면 우측에서 슬라이드 되어 나오는 `ChatDrawer.tsx`가 열려, 강사님이 다른 업무 창(예: 채점 페이지)을 닫지 않은 채 수강생과 쉽게 대화할 수 있도록 설계했습니다.

## 3. 검증 방법
- `cd frontend && npm run dev` 및 `cd backend && python -m uvicorn app.main:app --reload` 를 통해 서버를 실행해 보세요.
- 프론트엔드 라우트(`/instructor`, `/instructor/materials` 등)에서 사이드바 변경점과 우측 하단의 채팅 버튼 동작을 확인할 수 있습니다.
