from fastapi import APIRouter
from pydantic import BaseModel
from app.core.llm import get_llm
from langchain_core.messages import HumanMessage, SystemMessage

router = APIRouter()

class CounselingRequest(BaseModel):
    student_name: str
    issue: str

class CounselingResponse(BaseModel):
    ai_suggestion: str

@router.post("/generate-suggestion", response_model=CounselingResponse)
async def generate_counseling_suggestion(req: CounselingRequest):
    """
    학생 이름과 식별된 문제를 기반으로 강사에게 필요한 피드백 제안을 AI가 생성합니다.
    """
    llm = get_llm()
    
    system_prompt = SystemMessage(
        content=(
            "You are an expert academic counselor AI. "
            "Given a student's name and their identified issue, provide a short, "
            "actionable, and empathetic counseling suggestion for the instructor to use. "
            "Limit your response to 1-2 sentences."
        )
    )
    human_prompt = HumanMessage(content=f"Student Name: {req.student_name}\nIssue: {req.issue}")
    
    response = await llm.ainvoke([system_prompt, human_prompt])
    
    return CounselingResponse(ai_suggestion=response.content.strip())
