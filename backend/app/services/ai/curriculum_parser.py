import json
import logging
from typing import List, Dict, Any
from io import BytesIO
import pypdf
import pandas as pd
from app.core.llm import get_llm
from langchain_core.messages import SystemMessage, HumanMessage

logger = logging.getLogger(__name__)

async def extract_text_from_file(file_bytes: bytes, filename: str) -> str:
    """Extracts raw text from PDF or Excel file."""
    text = ""
    if filename.endswith(".pdf"):
        try:
            reader = pypdf.PdfReader(BytesIO(file_bytes))
            for page in reader.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
        except Exception as e:
            logger.error(f"Failed to parse PDF: {e}")
            raise ValueError(f"PDF 파싱 중 오류가 발생했습니다: {str(e)}")
            
    elif filename.endswith((".xlsx", ".xls")):
        try:
            # 엑셀의 모든 시트를 읽어서 텍스트로 합침
            df_dict = pd.read_excel(BytesIO(file_bytes), sheet_name=None)
            for sheet_name, df in df_dict.items():
                text += f"--- Sheet: {sheet_name} ---\n"
                # 엑셀 병합 셀(Merged Cells) 해결: 누락된 값(NaN)을 이전 행의 값으로 채움(Forward Fill)
                df = df.ffill()
                # 남은 NaN 값을 빈 문자열로 처리
                text += df.fillna("").to_string(index=False) + "\n\n"
        except Exception as e:
            logger.error(f"Failed to parse Excel: {e}")
            raise ValueError(f"엑셀 파일 파싱 중 오류가 발생했습니다: {str(e)}")
    else:
        raise ValueError("지원하지 않는 파일 형식입니다. PDF 또는 Excel 파일을 업로드해주세요.")
        
    return text

async def parse_curriculum_text(text: str) -> List[Dict[str, Any]]:
    """Uses LLM to convert raw text into a list of Curriculum steps."""
    llm = get_llm(temperature=0.0)
    
    prompt = """
당신은 교육 커리큘럼 분석 AI입니다.
주어진 텍스트(강의 계획서, 커리큘럼 로드맵 등)를 분석하여 커리큘럼 단계를 JSON 배열(List) 형태로 추출해주세요.

[추출 규칙]
1. 각 단계는 다음 필드를 가져야 합니다.
   - title (문자열): 과목명 혹은 커리큘럼 단계 이름
   - status (문자열): 'upcoming', 'current', 'completed' 중 하나 (기본값은 'upcoming')
   - starts_date (문자열): 시작 일자. 기간(예: 2026.01.08 ~ 2026.01.21)이 주어지면 반드시 **시작일**(2026.01.08)을 추출하세요. 
   - progress (숫자): 진행률 0~100 (기본값은 0)
   - display_order (숫자): 텍스트에 나타난 순서대로 1, 2, 3... (1부터 시작)
2. **중요(날짜 상속):** 여러 개의 하위 주제가 동일한 기간 그룹에 속해 있다면, 모든 하위 주제의 starts_date를 해당 그룹의 시작일로 동일하게 지정하세요. 절대 '미정'으로 남겨두지 마세요.
3. 오직 JSON 형식의 데이터만 출력해야 합니다. 마크다운 코드블록(```json 등)은 허용되나, 그 외의 설명이나 텍스트는 절대 포함하지 마세요.

[결과 예시]
[
  {
    "title": "오리엔테이션",
    "status": "upcoming",
    "starts_date": "2026.03.31",
    "progress": 0,
    "display_order": 1
  },
  {
    "title": "AI 리터러시",
    "status": "upcoming",
    "starts_date": "2026.04.01",
    "progress": 0,
    "display_order": 2
  }
]
"""
    
    messages = [
        SystemMessage(content=prompt),
        HumanMessage(content=f"다음 텍스트를 분석해주세요:\n\n{text[:15000]}") # 너무 길면 잘리므로 적절히 제한
    ]
    
    from app.core.config import settings
    
    try:
        response = await llm.ainvoke(messages)
        content = response.content.strip()
    except Exception as e:
        logger.error(f"LLM Invoke Error: {e}")
        raise ValueError(f"AI 모델 추론 중 오류가 발생했습니다. 로컬 LLM 서버(Ollama)가 실행 중이고 '{settings.LLM_MAIN_MODEL}' 모델이 설치되어 있는지 확인해주세요. (상세 에러: {str(e)})")
    
    # JSON 파싱 시도
    # 마크다운 블록 제거
    if content.startswith("```json"):
        content = content[7:]
    if content.startswith("```"):
        content = content[3:]
    if content.endswith("```"):
        content = content[:-3]
        
    content = content.strip()
    
    # JSON 앞뒤에 쓰레기값이 있을 경우 찾기
    start_idx = content.find('[')
    end_idx = content.rfind(']')
    
    if start_idx != -1 and end_idx != -1:
        content = content[start_idx:end_idx+1]
        
    try:
        steps = json.loads(content)
        if not isinstance(steps, list):
            raise ValueError("LLM 응답이 배열 형식이 아닙니다.")
            
        # [알고리즘 기반 후처리] 누락된 시작일을 이전 단계의 날짜로 채워넣음
        last_valid_date = "미정"
        for step in steps:
            current_date = step.get("starts_date", "")
            if current_date and current_date != "미정" and current_date.strip() != "":
                last_valid_date = current_date
            else:
                step["starts_date"] = last_valid_date
                
        return steps
    except json.JSONDecodeError as e:
        logger.error(f"JSON Parsing Error: {e}\nRaw Content:\n{content}")
        raise ValueError("AI 응답을 JSON으로 변환하는 데 실패했습니다.")
