from __future__ import annotations

import time
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.auth import User
from app.models.ai import AiAgentQuery
from app.schemas.ai_agent import AiQueryRequest, AiQueryResponse
from app.schemas.common import ok, paginated

router = APIRouter(prefix="/ai-agent", tags=["ai-agent"])


@router.post("/query", response_model=dict)
async def query(
    body: AiQueryRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    start = time.monotonic()

    answer = (
        f"'{body.query}'에 대한 답변입니다. (AI Agent 연동 전 플레이스홀더 응답)"
    )
    latency_ms = int((time.monotonic() - start) * 1000)

    log = AiAgentQuery(
        user_id=current_user.id,
        query_text=body.query,
        response_text=answer,
        tools_called=[],
        latency_ms=latency_ms,
        status="success",
    )
    db.add(log)
    await db.commit()

    return ok(
        AiQueryResponse(
            answer=answer,
            tools_used=[],
            references=[],
            session_id=body.session_id,
            latency_ms=latency_ms,
        ).model_dump()
    )


@router.post("/query/stream")
async def query_stream(
    body: AiQueryRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    async def event_generator():
        answer = f"'{body.query}'에 대한 스트리밍 응답입니다."
        for word in answer.split():
            yield f"event: token\ndata: {{\"text\": \"{word} \"}}\n\n"
        yield 'event: done\ndata: {"tools_used": []}\n\n'

    return StreamingResponse(event_generator(), media_type="text/event-stream")


@router.get("/history", response_model=dict)
async def get_history(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    page: int = 1,
    size: int = 20,
):
    from sqlalchemy import func, select
    query = select(AiAgentQuery)

    if current_user.role != "admin_ops":
        query = query.where(AiAgentQuery.user_id == current_user.id)

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.offset((page - 1) * size).limit(size).order_by(AiAgentQuery.created_at.desc())
    )
    queries = result.scalars().all()
    return paginated(
        [
            {
                "id": q.id,
                "query_text": q.query_text,
                "status": q.status,
                "latency_ms": q.latency_ms,
                "created_at": q.created_at.isoformat(),
            }
            for q in queries
        ],
        page,
        size,
        total,
    )


@router.get("/tools", response_model=dict)
async def list_tools(_: Annotated[User, Depends(get_current_user)]):
    return ok([
        {"name": "get_attendance_summary", "description": "출결 통계 조회"},
        {"name": "get_assignment_status", "description": "과제 제출 현황 조회"},
        {"name": "get_cohort_members", "description": "기수 수강생 목록 조회"},
    ])
