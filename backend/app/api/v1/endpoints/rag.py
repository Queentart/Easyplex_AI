from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from app.db.session import SessionLocal
from app.core.llm import get_embeddings
from app.models.counseling import CounselingLog
from typing import List

router = APIRouter()

async def get_db():
    async with SessionLocal() as session:
        yield session

class EmbedRequest(BaseModel):
    student_id: int
    topic: str
    notes: str

class EmbedResponse(BaseModel):
    success: bool
    log_id: int
    vector_dimension: int

class SearchRequest(BaseModel):
    query: str
    top_k: int = 3

class SearchResult(BaseModel):
    log_id: int
    student_id: int
    topic: str
    notes: str
    distance: float

@router.post("/embed", response_model=EmbedResponse)
async def embed_counseling_log(req: EmbedRequest, db: AsyncSession = Depends(get_db)):
    """
    상담 내용을 벡터화하여 DB에 저장합니다.
    (nomic-embed-text 모델 등 사용)
    """
    embeddings = get_embeddings()
    
    # 텍스트 임베딩 생성
    try:
        vector = await embeddings.aembed_query(req.notes)
    except AttributeError:
        vector = embeddings.embed_query(req.notes)
        
    # 벡터 저장
    new_log = CounselingLog(
        student_id=req.student_id,
        topic=req.topic,
        notes=req.notes,
        embedding=vector
    )
    db.add(new_log)
    await db.commit()
    await db.refresh(new_log)
    
    return EmbedResponse(success=True, log_id=new_log.id, vector_dimension=len(vector))

@router.post("/search", response_model=List[SearchResult])
async def search_counseling_log(req: SearchRequest, db: AsyncSession = Depends(get_db)):
    """
    pgvector 확장을 사용하여 질문과 유사한 상담 기록을 검색합니다.
    (Cosine Distance <=> 연산자 사용)
    """
    embeddings = get_embeddings()
    try:
        query_vector = await embeddings.aembed_query(req.query)
    except AttributeError:
        query_vector = embeddings.embed_query(req.query)
        
    # postgres pgvector format string
    vector_str = "[" + ",".join(map(str, query_vector)) + "]"
        
    # ARRAY를 vector 타입으로 변환 후 코사인 거리 계산
    sql = text('''
        SELECT id, student_id, topic, notes,
               (embedding::vector) <=> (:query_vector::vector) as distance
        FROM counseling_logs
        WHERE embedding IS NOT NULL
        ORDER BY distance ASC
        LIMIT :top_k
    ''')
    
    result = await db.execute(sql, {
        "query_vector": vector_str,
        "top_k": req.top_k
    })
    
    rows = result.fetchall()
    
    search_results = []
    for row in rows:
        search_results.append(SearchResult(
            log_id=row.id,
            student_id=row.student_id,
            topic=row.topic or "",
            notes=row.notes,
            distance=float(row.distance)
        ))
        
    return search_results
