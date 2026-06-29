from typing import List, Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.api import deps
from app.schemas.curriculum import CurriculumStepResponse, CurriculumStepCreate, CurriculumStepUpdate
from app.crud.crud_curriculum import curriculum_step
from app.models.auth import User, UserRole
from fastapi import UploadFile, File
from app.services.ai.curriculum_parser import extract_text_from_file, parse_curriculum_text


router = APIRouter()

@router.get("/", response_model=List[CurriculumStepResponse])
async def read_curriculum_steps(
    db: AsyncSession = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
) -> Any:
    """
    모든 커리큘럼 단계를 조회합니다. (수강생, 강사, 운영팀 공통)
    """
    steps = await curriculum_step.get_multi(db, skip=skip, limit=limit)
    return steps

@router.post("/", response_model=CurriculumStepResponse)
async def create_curriculum_step(
    *,
    db: AsyncSession = Depends(deps.get_db),
    step_in: CurriculumStepCreate,
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    새로운 커리큘럼 단계를 생성합니다. (강사, 운영팀 전용)
    """
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.EDUOPS, UserRole.OWNER]:
        raise HTTPException(status_code=403, detail="Not enough permissions")
    
    step = await curriculum_step.create(db=db, obj_in=step_in)
    return step

@router.post("/upload", response_model=List[CurriculumStepCreate])
async def upload_and_parse_curriculum(
    *,
    file: UploadFile = File(...),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    운영팀에서 업로드한 PDF 또는 엑셀 파일을 분석하여 커리큘럼 로드맵 임시 데이터를 반환합니다. (DB에 즉시 저장하지 않음)
    """
    if current_user.role not in [UserRole.EDUOPS, UserRole.OWNER]:
        raise HTTPException(status_code=403, detail="Not enough permissions. EduOps only.")
        
    try:
        file_bytes = await file.read()
        text = await extract_text_from_file(file_bytes, file.filename)
        parsed_steps = await parse_curriculum_text(text)
        
        # Pydantic 모델로 변환 (Validation)
        validated_steps = []
        for step in parsed_steps:
            validated_steps.append(CurriculumStepCreate(**step))
            
        return validated_steps
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

@router.post("/batch", response_model=List[CurriculumStepResponse])
async def create_curriculum_steps_batch(
    *,
    db: AsyncSession = Depends(deps.get_db),
    steps_in: List[CurriculumStepCreate],
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    여러 커리큘럼 단계를 한 번에 생성합니다. (운영팀, 강사 전용)
    """
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.EDUOPS, UserRole.OWNER]:
        raise HTTPException(status_code=403, detail="Not enough permissions")
        
    created_steps = []
    for step_in in steps_in:
        step = await curriculum_step.create(db=db, obj_in=step_in)
        created_steps.append(step)
    return created_steps

@router.put("/{id}", response_model=CurriculumStepResponse)
async def update_curriculum_step(
    *,
    db: AsyncSession = Depends(deps.get_db),
    id: int,
    step_in: CurriculumStepUpdate,
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    기존 커리큘럼 단계를 업데이트합니다. (강사, 운영팀 전용)
    """
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.EDUOPS, UserRole.OWNER]:
        raise HTTPException(status_code=403, detail="Not enough permissions")
        
    step = await curriculum_step.get(db=db, id=id)
    if not step:
        raise HTTPException(status_code=404, detail="Curriculum step not found")
        
    step = await curriculum_step.update(db=db, db_obj=step, obj_in=step_in)
    return step

@router.delete("/{id}", response_model=CurriculumStepResponse)
async def delete_curriculum_step(
    *,
    db: AsyncSession = Depends(deps.get_db),
    id: int,
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    커리큘럼 단계를 삭제합니다. (강사, 운영팀 전용)
    """
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.EDUOPS, UserRole.OWNER]:
        raise HTTPException(status_code=403, detail="Not enough permissions")
        
    step = await curriculum_step.get(db=db, id=id)
    if not step:
        raise HTTPException(status_code=404, detail="Curriculum step not found")
        
    step = await curriculum_step.remove(db=db, id=id)
    return step
