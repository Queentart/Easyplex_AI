# 고화질 자체 생성 QR 코드 기반 출석 체크 구현 계획

기존에 운영팀에서 배포하여 화질이 저하되거나 인식 오류가 잦았던 이미지 기반 QR 코드를 대체하여, 프론트엔드 자체적으로 스캔 시 오류가 없는 **고화질 벡터(SVG) 형식의 QR 코드를 생성**하는 기능을 추가합니다.

## User Review Required

> [!IMPORTANT]
> 이 기능 추가를 위해서는 프론트엔드단에 QR 코드 생성 라이브러리(`qrcode.react`)의 추가 설치가 필요합니다. 

## Open Questions

> [!WARNING]
> QR 코드를 스캔했을 때 인식되어야 하는 **정확한 데이터 값(Value) 형식**이 정해져 있나요?
> (예: `https://easyplex.ai/attendance/check?student=24-001`, 또는 고유 문자열 토큰 등)
> 확정된 포맷이 없다면 우선 학생의 학번(Student ID)과 오늘 날짜가 포함된 식별자 형태로 임시 구현하겠습니다.

## Proposed Changes

### 1. 라이브러리 설치
프론트엔드 프로젝트(`/frontend`)에 고화질 QR을 네이티브하게 그려주는 라이브러리인 `qrcode.react`를 설치합니다.

### 2. Frontend Components 업데이트

#### [MODIFY] Home.tsx (src/pages/student/Home.tsx)
- 출석 체크 블록(`qr-widget` div)에 `onClick` 이벤트를 추가하여 모달이 뜨도록 연결합니다.
- `Modal` 컴포넌트를 불러와 화면 중앙에 QR 코드가 노출되도록 팝업 UI를 구현합니다.
- 학생의 학번 또는 식별자 정보를 기반으로 QR 코드 라이브러리를 사용하여 실시간 렌더링되도록 합니다.

#### [NEW] AttendanceQRModal.tsx (src/components/common/AttendanceQRModal.tsx) (선택 사항)
- 혹은 모달 크기와 스타일링을 캡슐화하기 위해 전용 모달 컴포넌트를 생성하여 `Home.tsx` 코드가 너무 길어지는 것을 방지할 수 있습니다.

## Verification Plan

### Manual Verification
1. 학생 계정(`24-001`)으로 로그인 후 `Home` 탭으로 이동.
2. 상단의 출석 체크 영역을 클릭.
3. 화면 중앙에 선명하게 깨지지 않는 고화질 QR 코드가 나타나는지 모바일/웹 뷰에서 확인.
4. 실제 스마트폰 기본 카메라나 QR 스캐너 앱을 통해 스캔하여 지정한 텍스트 또는 URL이 정상적으로 인식되는지 확인.
