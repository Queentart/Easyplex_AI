import os
from langchain_ollama import ChatOllama, OllamaEmbeddings
from app.core.config import settings

def get_llm(model_name: str = None, temperature: float = 0.0) -> ChatOllama:
    """
    Ollama 기반 Chat 모델 인스턴스를 반환합니다.
    기본값으로 settings.LLM_MAIN_MODEL을 사용하며, 
    keep_alive=0 파라미터를 강제 적용하여 응답 완료 후 즉시 VRAM에서 모델을 해제합니다.
    """
    target_model = model_name or settings.LLM_MAIN_MODEL
    
    return ChatOllama(
        base_url=settings.OLLAMA_BASE_URL,
        model=target_model,
        temperature=temperature,
        keep_alive=0
    )

def get_reasoning_llm(temperature: float = 0.0) -> ChatOllama:
    """
    깊은 추론이 필요한 작업(예: 채점 논리, 복잡한 상담 분석)을 위한 모델(DeepSeek 등)을 반환합니다.
    """
    return get_llm(model_name=settings.LLM_REASONING_MODEL, temperature=temperature)

def get_embeddings() -> OllamaEmbeddings:
    """
    RAG용 벡터 임베딩 추출을 위한 모델 인스턴스를 반환합니다.
    """
    return OllamaEmbeddings(
        base_url=settings.OLLAMA_BASE_URL,
        model=settings.LLM_EMBEDDING_MODEL,
        # 최신 langchain-ollama에서는 Embeddings에도 keep_alive 전달이 가능한 경우가 많지만, 
        # API 오류가 나면 제외해야 할 수도 있습니다. 우선 적용해봅니다.
    )
