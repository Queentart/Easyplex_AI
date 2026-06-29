# 강의 자료 업로드 실패 원인 분석 및 해결 방안

## 1. 문제 분석 (원인)
강사진과 멘토가 강의 자료를 업로드할 때 발생하는 오류를 분석한 결과, 권한(Permission) 문제가 아닌 **프론트엔드의 파일 전송(Axios) 설정 문제**로 확인되었습니다.

- **원인**: `frontend/src/api/materialApi.ts` 파일의 `uploadMaterial` 함수에서 파일을 전송할 때 `axios.post`의 헤더에 `'Content-Type': 'multipart/form-data'`를 강제로 명시하고 있습니다.
- **결과**: `axios`는 `FormData` 객체를 전송할 때 자동으로 파일 구분을 위한 `boundary` 문자열(예: `multipart/form-data; boundary=----WebKitFormBoundary...`)을 생성하여 헤더에 포함시킵니다. 하지만 개발자가 강제로 `Content-Type`을 지정해버리면 이 `boundary` 값이 누락되어, 백엔드(FastAPI)에서 전달받은 파일을 정상적으로 읽지(Parsing) 못하고 422 Unprocessable Entity 혹은 400 Bad Request 에러를 반환하게 됩니다. 이로 인해 업로드가 실패하는 것입니다.

## 2. 해결 방안 (Proposed Changes)

프론트엔드 API 호출 코드에서 수동으로 지정된 Content-Type 헤더를 제거하면 axios가 알맞게 boundary를 포함시켜 전송하게 되므로 정상적으로 업로드가 처리됩니다.

### Frontend API 수정

#### [MODIFY] [materialApi.ts](file:///c:/Easyplex_AI/frontend/src/api/materialApi.ts)
- `uploadMaterial` 함수의 axios 요청 헤더 부분에서 `'Content-Type': 'multipart/form-data'` 항목을 삭제합니다. (axios가 자체적으로 올바른 Content-Type과 Boundary를 설정하도록 위임)

## 3. 검증 계획 (Verification Plan)

- **자동/수동 테스트**: 파일 내용 수정 후, 프론트엔드 UI를 통해 실제로 강의 자료(pdf 등 임의의 파일) 업로드를 시도합니다.
- 정상적으로 로딩 인디케이터가 표시된 후 리스트에 새 자료가 반영되는지 확인합니다.

---

> [!NOTE]
> 해당 해결 방안이 적절하다고 생각되시면 **승인**해주시기 바랍니다. 승인 직후 바로 코드를 수정하여 업로드 에러를 해결하겠습니다.
