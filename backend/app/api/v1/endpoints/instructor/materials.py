from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List, Any, Optional
import os
import uuid
import shutil

from app.api.deps import get_db, get_current_user
from app.models.auth import User, UserRole
from app.models.instructor_models import CourseMaterial

router = APIRouter()

@router.get("", response_model=List[Any])
async def get_materials(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 모두 읽을 수 있게 허용 (강사, 멘토, 수강생 등)
    result = await db.execute(select(CourseMaterial).order_by(CourseMaterial.created_at.desc()))
    materials = result.scalars().all()
    
    return [
        {
            "id": m.id, 
            "title": m.title, 
            "description": m.description, 
            "file_name": m.file_name,
            "file_type": m.file_type,
            "file_size": m.file_size,
            "file_url": m.file_url, 
            "uploaded_by_id": m.uploaded_by_id,
            "created_at": m.created_at.isoformat() if m.created_at else None
        } 
        for m in materials
    ]

@router.post("")
async def upload_material(
    title: str = Form(...),
    description: Optional[str] = Form(""),
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 강사와 멘토만 업로드 가능
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.OWNER]:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    # 파일 저장 디렉토리 (backend/uploads/materials)
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))))
    upload_dir = os.path.join(base_dir, "uploads", "materials")
    os.makedirs(upload_dir, exist_ok=True)
    
    file_ext = os.path.splitext(file.filename)[1] if file.filename else ""
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(upload_dir, unique_filename)
    
    file_size = 0
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        file_size = os.path.getsize(file_path)
        
    # 확장자에서 점 제거하여 file_type 설정, 없으면 unknown
    file_type = file_ext.replace(".", "").lower() if file_ext else "unknown"
    # 프론트엔드 서빙 URL
    file_url = f"/uploads/materials/{unique_filename}"

    material = CourseMaterial(
        title=title, 
        description=description, 
        file_name=file.filename,
        file_type=file_type,
        file_size=file_size,
        file_url=file_url, 
        uploaded_by_id=current_user.id
    )
    db.add(material)
    await db.commit()
    await db.refresh(material)
    
    return {
        "message": "Material uploaded successfully", 
        "id": material.id,
        "title": material.title,
        "file_url": material.file_url
    }

@router.delete("/{material_id}")
async def delete_material(
    material_id: int, 
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role not in [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.OWNER]:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    result = await db.execute(select(CourseMaterial).filter(CourseMaterial.id == material_id))
    material = result.scalar_one_or_none()
    if not material:
        raise HTTPException(status_code=404, detail="Material not found")
    
    # 실제 파일 삭제 로직
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))))
    if material.file_url:
        filename = material.file_url.split("/")[-1]
        file_path = os.path.join(base_dir, "uploads", "materials", filename)
        if os.path.exists(file_path):
            os.remove(file_path)
            
    await db.delete(material)
    await db.commit()
    return {"message": "Material deleted successfully"}
