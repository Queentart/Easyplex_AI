from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
from datetime import datetime
from pydantic import BaseModel
from app.api.deps import get_db, get_current_user
from app.models.auth import User, UserRole
from app.models.instructor_models import CourseMaterial, TrainingLog, MentoringLog

router = APIRouter()

def check_ops_access(current_user: User):
    if current_user.role != UserRole.EDUOPS:
        raise HTTPException(status_code=403, detail="Not enough permissions. EduOps role required.")

# Pydantic Models for Response
class MaterialResponse(BaseModel):
    id: int
    title: str
    uploaded_by: str
    created_at: datetime

    class Config:
        from_attributes = True

class TrainingLogResponse(BaseModel):
    id: int
    title: str
    content: str
    instructor: str
    date: datetime

    class Config:
        from_attributes = True

class MentoringLogResponse(BaseModel):
    id: int
    title: str
    content: str
    tutor: str
    student: str | None
    date: datetime

    class Config:
        from_attributes = True

@router.get("/materials", response_model=List[MaterialResponse])
async def get_all_materials(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    check_ops_access(current_user)
    result = await db.execute(select(CourseMaterial).order_by(CourseMaterial.created_at.desc()))
    materials = result.scalars().all()
    
    response = []
    for m in materials:
        user_result = await db.execute(select(User).filter(User.id == m.uploaded_by_id))
        user = user_result.scalar_one_or_none()
        response.append(MaterialResponse(
            id=m.id,
            title=m.title,
            uploaded_by=user.full_name if user else "Unknown",
            created_at=m.created_at
        ))
    return response

@router.get("/training", response_model=List[TrainingLogResponse])
async def get_all_training_logs(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    check_ops_access(current_user)
    result = await db.execute(select(TrainingLog).order_by(TrainingLog.date.desc()))
    logs = result.scalars().all()
    
    response = []
    for log in logs:
        instructor_result = await db.execute(select(User).filter(User.id == log.instructor_id))
        instructor = instructor_result.scalar_one_or_none()
        response.append(TrainingLogResponse(
            id=log.id,
            title=log.title,
            content=log.content,
            instructor=instructor.full_name if instructor else "Unknown",
            date=log.date
        ))
    return response

@router.get("/mentoring", response_model=List[MentoringLogResponse])
async def get_all_mentoring_logs(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    check_ops_access(current_user)
    result = await db.execute(select(MentoringLog).order_by(MentoringLog.date.desc()))
    logs = result.scalars().all()
    
    response = []
    for log in logs:
        tutor_result = await db.execute(select(User).filter(User.id == log.tutor_id))
        tutor = tutor_result.scalar_one_or_none()
        
        student = None
        if log.student_id:
            student_result = await db.execute(select(User).filter(User.id == log.student_id))
            student = student_result.scalar_one_or_none()
            
        response.append(MentoringLogResponse(
            id=log.id,
            title=log.title,
            content=log.content,
            tutor=tutor.full_name if tutor else "Unknown",
            student=student.full_name if student else "N/A",
            date=log.date
        ))
    return response
