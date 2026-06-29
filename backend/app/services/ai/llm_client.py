from langchain_ollama import ChatOllama
from app.core.config import settings

def get_llm(model_name: str = None, temperature: float = 0.0) -> ChatOllama:
    """
    LangChain의 ChatOllama 클라이언트를 초기화하여 반환합니다.
    - 모델명은 매개변수가 없으면 settings.LLM_MAIN_MODEL을 사용합니다.
    - VRAM 메모리 부족 문제를 방지하기 위해 작업 완료 즉시 모델을 언로드(keep_alive=0)하도록 강제합니다.
    """
    target_model = model_name or settings.LLM_MAIN_MODEL
    
    # keep_alive: 0 을 통해 모델 추론 후 VRAM에서 즉시 해제
    return ChatOllama(
        base_url=settings.OLLAMA_BASE_URL,
        model=target_model,
        temperature=temperature,
        keep_alive=0  # <- 중요: OOM 방지 및 메모리 효율성 보장
    )
