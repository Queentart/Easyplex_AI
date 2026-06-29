# AI 자동 채점 다중 파일 분석 통합 계획

현재 AI 자동 채점 시스템은 학생이 입력한 텍스트(Submission Content)에 대해서만 점수를 매기고 있습니다. 학생이 텍스트 대신 파일을 업로드했거나, 텍스트와 파일을 함께 업로드한 경우 **파일의 내용까지 분석하여 프롬프트에 포함**시키는 파이프라인으로 확장해야 합니다.

## 제안하는 구현 방식 (파일 종류별 파이프라인)

백엔드 환경에 이미 설치된 라이브러리(`pypdf`, `SpeechRecognition`, `pillow`, `opencv-python`, `pydub` 등)를 활용하여 다음과 같이 각 파일의 내용을 텍스트화하거나 분석하여 LLM에게 넘겨줍니다.

1. **코드 및 텍스트 파일 (`.txt`, `.py`, `.js`, `.md` 등)**:
   - 파일을 UTF-8로 직접 읽어들여 전체 코드를 텍스트로 치환하여 프롬프트에 포함시킵니다.
2. **문서 파일 (`.pdf`)**:
   - `pypdf` 라이브러리를 사용하여 PDF 내의 텍스트를 파싱(추출)하여 포함시킵니다.
3. **오디오 및 음원 파일 (`.wav`, `.mp3` 등)**:
   - `SpeechRecognition` 및 `pydub`를 사용하여 오디오 파일에서 STT(Speech-to-Text) 방식으로 텍스트 스크립트를 추출해 냅니다.
4. **이미지 파일 (`.jpg`, `.png` 등)**:
   - 현재 구축된 로컬 LLM(Ollama)이 Vision(LLaVA 등)을 지원한다면, 이미지를 Base64 인코딩하여 직접 LangChain의 HumanMessage에 이미지 파트로 첨부합니다.
   - 만약 텍스트 전용 모델(Llama3 등)이라면, OCR을 이용하거나 이미지 메타데이터(파일명, 해상도, 포맷)를 추출해 "이러한 이미지가 첨부되었음"을 요약 텍스트로 전달합니다.

## User Review Required

> [!IMPORTANT]
> **멀티모달(Vision) 모델 사용 여부**:
> 현재 사용 중인 로컬 LLM(Ollama) 모델이 멀티모달(예: LLaVA) 모델인지 확인이 필요합니다. 이미지 자체를 픽셀 단위로 AI가 보고 채점하게 하려면 멀티모달 모델 설정이 필수적입니다. 만약 텍스트 전용 모델이라면 이미지는 제한적인 메타데이터나 OCR 결과만 반영됩니다. 현재 모델 환경에 맞춰 진행해도 괜찮을까요?

> [!WARNING]
> **동영상(.mp4 등) 파일 처리 한계**:
> 동영상 파일은 용량이 크고 처리가 무거워, 백엔드에서 오디오만 추출하여 STT(음성 인식)를 돌리거나 프레임 단위 메타데이터만 반영하는 구조로 구현하는 것이 로컬 환경에서 가장 현실적입니다. 동영상은 '오디오 추출 후 텍스트화' 방식으로 진행하는 방향으로 동의하시나요?

## Proposed Changes

### 백엔드 파일 분석 유틸리티
#### [NEW] `backend/app/core/file_parser.py`
- `parse_file_for_llm(file_path, file_type)` 함수를 구현.
- 내부적으로 파일 확장자와 MIME 타입을 검사하여, 텍스트/코드/PDF/오디오 등을 각기 다른 파서 모듈로 넘기고 최종적인 "추출된 텍스트(또는 이미지 객체)"를 반환하도록 설계.

### AI 채점 엔드포인트 수정
#### [MODIFY] `backend/app/api/v1/endpoints/assignments.py`
- `/generate-grading` API 호출 시, 학생의 `submission_id`를 추가로 받거나, 기존 `file_url` 등을 참조하도록 구조 변경.
- 서버에 저장된 업로드 파일(`UPLOAD_DIR`) 경로를 추적하여 `file_parser.py`로 분석을 돌림.
- 기존의 단순 텍스트 프롬프트 문자열을 아래와 같이 통합형으로 보강:
  ```text
  Student: {student_name}
  Assignment: {assignment_title}
  Text Submission: {submission_content}
  Attached File Content (Extracted): {extracted_file_content}
  ```

## Verification Plan
1. 다양한 형식(Python 코드 파일, PDF 문서, txt 파일)을 직접 업로드 테스트.
2. 강사 계정에서 `Run AI Auto-Grade` 버튼 클릭 시, 콘솔에 추출된 파일 내용이 LLM 프롬프트로 잘 넘어가는지 로깅 및 확인.
3. AI가 파일 내용에 맞는 피드백(예: "코드에 오타가 있습니다", "PDF 리포트 내용이 훌륭합니다")을 응답하는지 최종 확인.
