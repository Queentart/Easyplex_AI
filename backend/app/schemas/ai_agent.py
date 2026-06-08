from __future__ import annotations

from typing import Optional

from pydantic import BaseModel


class AiQueryRequest(BaseModel):
    query: str
    session_id: Optional[str] = None
    stream: bool = False


class AiQueryResponse(BaseModel):
    answer: str
    tools_used: list[dict]
    references: list[dict]
    session_id: Optional[str]
    latency_ms: int
