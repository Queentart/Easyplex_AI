from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.auth import User
from app.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    LoginResponse,
    LogoutRequest,
    MeResponse,
    RefreshRequest,
)
from app.schemas.common import ok
from app.services import auth as auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=dict)
async def login(
    body: LoginRequest,
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    ip = request.client.host if request.client else None
    result = await auth_service.login(body.email, body.password, db, ip_address=ip)
    return ok(result.model_dump())


@router.post("/refresh", response_model=dict)
async def refresh(
    body: RefreshRequest,
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    ip = request.client.host if request.client else None
    result = await auth_service.refresh(body.refresh_token, db, ip_address=ip)
    return ok(result.model_dump())


@router.post("/logout", response_model=dict)
async def logout(
    body: LogoutRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(get_current_user)],
):
    await auth_service.logout(body.refresh_token, db)
    return ok({"ok": True})


@router.get("/me", response_model=dict)
async def me(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    me_response = await auth_service.build_me_response(db, current_user)
    return ok(me_response.model_dump())


@router.post("/password/change", response_model=dict)
async def change_password(
    body: ChangePasswordRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await auth_service.change_password(
        current_user, body.current_password, body.new_password, db
    )
    return ok({"ok": True})
