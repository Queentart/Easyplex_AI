from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List, Any
from app.api.deps import get_db
from app.models.instructor_models import TrainingLog, MentoringLog

router = APIRouter()

@router.get("/training", response_model=List[Any])
async def get_training_logs(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(TrainingLog))
    logs = result.scalars().all()
    return [{"id": l.id, "instructor_id": l.instructor_id, "title": l.title, "content": l.content, "date": l.date} for l in logs]

@router.post("/training")
async def create_training_log(title: str, content: str, instructor_id: int, db: AsyncSession = Depends(get_db)):
    log = TrainingLog(title=title, content=content, instructor_id=instructor_id)
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return {"message": "Training log created", "id": log.id}

@router.get("/mentoring", response_model=List[Any])
async def get_mentoring_logs(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(MentoringLog))
    logs = result.scalars().all()
    return [{"id": l.id, "tutor_id": l.tutor_id, "student_id": l.student_id, "title": l.title, "content": l.content, "date": l.date} for l in logs]

@router.post("/mentoring")
async def create_mentoring_log(title: str, content: str, tutor_id: int, student_id: int = None, db: AsyncSession = Depends(get_db)):
    log = MentoringLog(title=title, content=content, tutor_id=tutor_id, student_id=student_id)
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return {"message": "Mentoring log created", "id": log.id}
