from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import settings
from app.core.security import create_access_token, verify_password
from app.api.deps import get_db, get_current_user
from app.models.auth import User, UserRole
from pydantic import BaseModel

router = APIRouter()

class Token(BaseModel):
    access_token: str
    token_type: str
    user_info: dict

class UserResponse(BaseModel):
    id: str
    username: str
    email: str
    full_name: str
    role: str

@router.post("/login", response_model=Token)
async def login_access_token(
    db: AsyncSession = Depends(get_db),
    form_data: OAuth2PasswordRequestForm = Depends()
) -> dict:
    """
    OAuth2 호환 토큰 로그인. 
    이메일(username 파라미터)과 비밀번호로 로그인하여 JWT를 발급합니다.
    """
    from app.models.student import Student

    if "@" in form_data.username:
        result = await db.execute(select(User).where(User.email == form_data.username))
        user = result.scalars().first()
    else:
        # 학번으로 로그인 시도 (student_number)
        stmt = select(User).join(Student, User.id == Student.user_id).where(Student.student_number == form_data.username)
        result = await db.execute(stmt)
        user = result.scalars().first()
    
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    elif not user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
        
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        subject=str(user.id), expires_delta=access_token_expires
    )
    
    role_val = user.role.value if hasattr(user.role, 'value') else str(user.role)
    role_map = {
        "TECHOPS": "admin",
        "EDUOPS": "ops",
        "OWNER": "owner",
        "INSTRUCTOR": "instructor",
        "STUDENT": "student"
    }
    frontend_role = role_map.get(role_val, role_val.lower())
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_info": {
            "id": str(user.id),
            "name": user.full_name,
            "email": user.email,
            "role": frontend_role
        }
    }

@router.get("/me", response_model=UserResponse)
async def read_users_me(
    current_user: User = Depends(get_current_user)
) -> dict:
    """
    현재 로그인된 사용자의 정보를 반환합니다.
    """
    role_val = current_user.role.value if hasattr(current_user.role, 'value') else str(current_user.role)
    role_map = {
        "TECHOPS": "admin",
        "EDUOPS": "ops",
        "OWNER": "owner",
        "INSTRUCTOR": "instructor",
        "STUDENT": "student"
    }
    frontend_role = role_map.get(role_val, role_val.lower())
    
    return {
        "id": str(current_user.id),
        "username": current_user.email, # username field does not exist, use email
        "email": current_user.email,
        "full_name": current_user.full_name,
        "role": frontend_role
    }
