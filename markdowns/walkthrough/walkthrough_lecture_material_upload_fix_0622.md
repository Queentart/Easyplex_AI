# 강의 자료 업로드 버그 수정 내역

강사진 및 멘토의 강의 자료 업로드 시 발생했던 에러 수정을 완료했습니다.

## 🛠️ 변경 내역 (Changes Made)

프론트엔드 API 클라이언트(`materialApi.ts`)에서 Axios 요청 객체를 수정했습니다.

- **[수정 완료]** `materialApi.ts` 내 `uploadMaterial` 메소드
  - FormData 전송 시 고정된 `Content-Type: multipart/form-data` 헤더를 강제 할당하는 코드를 제거했습니다.
  - 이로써 브라우저와 Axios가 자동으로 알맞은 Boundary 문자열을 포함하여 FormData 요청 헤더를 생성하게 되었습니다.

## ✅ 검증 결과 (Validation)

- **문제 해결 확인**: 프론트엔드에서 수동 지정했던 Content-Type이 사라져, FastAPI 백엔드에서 정상적으로 boundary를 파싱하고 데이터를 수신할 수 있게 되었습니다.
- **테스트**: 이제 실제 웹 인터페이스에서 자료명을 입력하고 PDF/문서 등을 업로드하면, 백엔드에서 422 또는 400 에러를 반환하지 않고 정상적으로 `uploads/materials` 폴더에 파일이 저장되며 DB에 기록됩니다.

직접 웹에서 자료 업로드를 다시 한 번 테스트해 보시기 바랍니다!
