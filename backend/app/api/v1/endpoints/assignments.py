from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from pydantic import BaseModel
from typing import List, Optional, Any
from datetime import datetime
import os
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from app.api.deps import get_db, get_current_user
from app.models.auth import User, UserRole
from app.models.assignment import AssignmentTask, Assignment
from app.models.student import Student
from app.core.llm import get_reasoning_llm
from langchain_core.messages import HumanMessage, SystemMessage
import json

router = APIRouter()

# --- Pydantic Schemas ---

class AssignmentTaskCreate(BaseModel):
    title: str
    description: str
    deadline: Optional[datetime] = None

# AssignmentSubmit is no longer used for the endpoint directly, but kept if needed for reference
class AssignmentSubmit(BaseModel):
    content: str

class AssignmentGradeReview(BaseModel):
    final_score: float
    final_feedback: Optional[str] = None

class GradingRequest(BaseModel):
    student_name: str
    assignment_title: str
    submission_content: str

class GradingResponse(BaseModel):
    score: int
    ai_confidence: str
    feedback: str

# --- API Endpoints ---

@router.get("/tasks")
async def get_assignment_tasks(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """모든 과제 목록을 조회합니다."""
    result = await db.execute(select(AssignmentTask).order_by(AssignmentTask.created_at.desc()))
    tasks = result.scalars().all()
    
    # 학생일 경우 제출 여부를 함께 반환할 수 있도록 확장 가능
    task_list = []
    for t in tasks:
        task_info = {
            "id": t.id,
            "title": t.title,
            "description": t.description,
            "deadline": t.deadline.isoformat() if t.deadline else None,
            "created_at": t.created_at.isoformat() if t.created_at else None,
        }
        
        # 수강생인 경우 본인의 제출 정보도 함께 쿼리
        if current_user.role == UserRole.STUDENT:
            # student_id 가져오기
            st_res = await db.execute(select(Student).where(Student.user_id == current_user.id))
            student = st_res.scalars().first()
            if student:
                sub_res = await db.execute(
                    select(Assignment).where(Assignment.task_id == t.id, Assignment.student_id == student.id)
                )
                submission = sub_res.scalars().first()
                if submission:
                    task_info["status"] = submission.status
                    task_info["submission_id"] = submission.id
                    task_info["final_score"] = submission.final_score
                    task_info["final_feedback"] = submission.final_feedback
                else:
                    task_info["status"] = "pending"
                    task_info["submission_id"] = None
                    task_info["final_score"] = None
                    task_info["final_feedback"] = None
            else:
                task_info["status"] = "pending"
                task_info["submission_id"] = None
                task_info["final_score"] = None
                task_info["final_feedback"] = None
        else:
            # 강사용의 경우 제출 수 등을 쿼리할 수 있으나 여기선 생략
            pass
            
        task_list.append(task_info)
        
    return task_list

@router.post("/tasks")
async def create_assignment_task(
    req: AssignmentTaskCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """새 과제를 등록합니다 (강사진만)"""
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.OWNER]:
        raise HTTPException(status_code=403, detail="Not enough permissions")
        
    task = AssignmentTask(
        title=req.title,
        description=req.description,
        deadline=req.deadline,
        created_by_id=current_user.id
    )
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return {"message": "Assignment created successfully", "task_id": task.id}

UPLOAD_DIR = "uploads/assignments"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/tasks/{task_id}/submit")
async def submit_assignment(
    task_id: int,
    content: str = Form(""),
    file: Optional[UploadFile] = File(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """학생이 과제를 제출합니다. (파일 및 텍스트 포함)"""
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(status_code=403, detail="Only students can submit assignments")
        
    st_res = await db.execute(select(Student).where(Student.user_id == current_user.id))
    student = st_res.scalars().first()
    if not student:
        raise HTTPException(status_code=400, detail="Student profile not found")
        
    task_res = await db.execute(select(AssignmentTask).where(AssignmentTask.id == task_id))
    task = task_res.scalars().first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
        
    # Check if deadline has passed. Assuming task.deadline is timezone naive UTC datetime
    if task.deadline and task.deadline < datetime.utcnow():
        raise HTTPException(status_code=400, detail="The deadline for this assignment has passed. Submissions are no longer accepted.")
        
    file_url = None
    file_name = None
    file_type = None
    file_size = None
    
    if file:
        file_name = file.filename
        file_type = file.content_type
        unique_id = str(uuid.uuid4())
        ext = os.path.splitext(file_name)[1] if file_name else ""
        save_name = f"{unique_id}{ext}"
        save_path = os.path.join(UPLOAD_DIR, save_name)
        
        content_bytes = await file.read()
        file_size = len(content_bytes)
        
        with open(save_path, "wb") as f:
            f.write(content_bytes)
            
        file_url = f"/api/v1/assignments/downloads/{save_name}"
        
    # 기존 제출 확인
    sub_res = await db.execute(select(Assignment).where(Assignment.task_id == task_id, Assignment.student_id == student.id))
    existing = sub_res.scalars().first()
    
    if existing:
        # 덮어쓰기
        existing.content = content
        if file:
            existing.file_url = file_url
            existing.file_name = file_name
            existing.file_type = file_type
            existing.file_size = file_size
        existing.submitted_at = datetime.utcnow()
        existing.status = "submitted"
        submission = existing
    else:
        submission = Assignment(
            task_id=task_id,
            student_id=student.id,
            title="Assignment Submission", # legacy
            content=content,
            file_url=file_url,
            file_name=file_name,
            file_type=file_type,
            file_size=file_size,
            status="submitted"
        )
        db.add(submission)
        
    await db.commit()
    await db.refresh(submission)
    return {"message": "Assignment submitted successfully", "submission_id": submission.id}


@router.get("/tasks/{task_id}/submissions")
async def get_task_submissions(
    task_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """특정 과제에 대한 제출 목록을 조회합니다 (강사 전용)"""
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.OWNER]:
        raise HTTPException(status_code=403, detail="Not enough permissions")
        
    # Join with Student and User to get student name
    stmt = select(Assignment, User).join(Student, Assignment.student_id == Student.id).join(User, Student.user_id == User.id).where(Assignment.task_id == task_id)
    result = await db.execute(stmt)
    rows = result.all()
    
    return [
        {
            "id": assignment.id,
            "student_name": user.full_name or user.email,
            "content": assignment.content,
            "file_url": assignment.file_url,
            "file_name": assignment.file_name,
            "submitted_at": assignment.submitted_at,
            "ai_score": assignment.ai_score,
            "ai_confidence": assignment.ai_confidence,
            "ai_feedback": assignment.ai_feedback,
            "final_score": assignment.final_score,
            "status": assignment.status
        }
        for assignment, user in rows
    ]

@router.post("/submissions/{submission_id}/grade")
async def finalize_grading(
    submission_id: int,
    req: AssignmentGradeReview,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """AI 채점 결과를 검토하고 최종 점수를 확정합니다."""
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.OWNER]:
        raise HTTPException(status_code=403, detail="Not enough permissions")
        
    sub_res = await db.execute(select(Assignment).where(Assignment.id == submission_id))
    submission = sub_res.scalars().first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")
        
    submission.final_score = req.final_score
    submission.final_feedback = req.final_feedback
    submission.status = "graded"
    
    await db.commit()
    return {"message": "Grading finalized successfully"}


class GradingRequest(BaseModel):
    student_name: str
    assignment_title: str
    submission_content: str
    file_url: Optional[str] = None
    file_name: Optional[str] = None

class GradingResponse(BaseModel):
    score: int
    ai_confidence: str
    feedback: str

@router.post("/generate-grading", response_model=GradingResponse)
async def generate_grading(
    req: GradingRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    학생의 과제 제출 내용 및 첨부파일을 기반으로 추론 특화 LLM을 사용해 자동 채점 결과를 반환합니다.
    """
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.OWNER]:
        raise HTTPException(status_code=403, detail="Not enough permissions")
        
    llm = get_reasoning_llm()
    
    system_prompt = SystemMessage(
        content=(
            "You are an expert AI teaching assistant grading assignments. "
            "Evaluate the student's submission carefully. "
            "You MUST respond ONLY with a valid JSON object with the following keys: "
            "'score' (integer 0-100), "
            "'ai_confidence' (string: 'High' or 'Low' depending on your certainty), "
            "and 'feedback' (string: 1-2 short sentences of constructive feedback). "
            "CRITICAL: The 'feedback' value MUST be written entirely in Korean (한국어). "
            "Do NOT wrap the JSON in markdown blocks (e.g. ```json). Just the raw JSON string."
        )
    )
    
    file_content = ""
    if req.file_url:
        # file_url is something like "/api/v1/assignments/downloads/{filename}"
        filename = req.file_url.split("/")[-1]
        file_path = os.path.join(UPLOAD_DIR, filename)
        
        from app.core.file_parser import parse_file_for_llm
        # 파일 파싱 진행
        parsed_text = parse_file_for_llm(file_path)
        file_content = f"\n\nAttached File ({req.file_name}):\n{parsed_text}"

    human_prompt = HumanMessage(
        content=f"Student: {req.student_name}\nAssignment: {req.assignment_title}\nText Submission: {req.submission_content}{file_content}"
    )
    
    response = await llm.ainvoke([system_prompt, human_prompt])
    
    try:
        content = response.content.strip()
        if content.startswith("```json"):
            content = content[7:-3].strip()
        elif content.startswith("```"):
            content = content[3:-3].strip()
            
        data = json.loads(content)
        return GradingResponse(
            score=int(data.get("score", 0)),
            ai_confidence=data.get("ai_confidence", "Low"),
            feedback=data.get("feedback", "No feedback provided.")
        )
    except Exception as e:
        return GradingResponse(
            score=0,
            ai_confidence="Low",
            feedback="Error generating grading. Please review manually."
        )

from fastapi.responses import FileResponse

@router.get("/downloads/{filename}")
async def download_assignment_file(filename: str):
    """제출된 과제 파일을 다운로드합니다."""
    file_path = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(file_path)
