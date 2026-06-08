from typing import Annotated, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_roles
from app.models.auth import User
from app.schemas.board import BoardCreate, BoardUpdate
from app.schemas.common import ok
from app.services import board as board_service

router = APIRouter(prefix="/boards", tags=["boards"])


@router.get("/", response_model=dict)
async def list_boards(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    cohort_id: Optional[int] = None,
    type: Optional[str] = None,
):
    boards = await board_service.list_boards(db, current_user, cohort_id, type)
    return ok([b.model_dump() for b in boards])


@router.post("/", response_model=dict)
async def create_board(
    body: BoardCreate,
    current_user: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    board = await board_service.create_board(db, body, current_user)
    return ok(board.model_dump())


@router.get("/{board_id}", response_model=dict)
async def get_board(
    board_id: int,
    _: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    board = await board_service.get_board(db, board_id)
    return ok(board.model_dump())


@router.patch("/{board_id}", response_model=dict)
async def update_board(
    board_id: int,
    body: BoardUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    board = await board_service.update_board(db, board_id, body, current_user)
    return ok(board.model_dump())


@router.delete("/{board_id}", response_model=dict)
async def delete_board(
    board_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await board_service.delete_board(db, board_id, current_user)
    return ok({"ok": True})
