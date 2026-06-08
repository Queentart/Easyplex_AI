from typing import Annotated, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user, require_roles
from app.models.auth import User
from app.schemas.board import CommentCreate, CommentUpdate, PinRequest, PostCreate, PostUpdate
from app.schemas.common import ok, paginated
from app.services import board as board_service

router = APIRouter(tags=["posts"])


@router.get("/posts", response_model=dict)
async def list_posts(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    board_id: Optional[int] = None,
    search: Optional[str] = None,
    author_id: Optional[int] = None,
    page: int = 1,
    size: int = 20,
):
    posts, total = await board_service.list_posts(
        db, current_user, board_id=board_id, search=search,
        author_id=author_id, page=page, size=size,
    )
    return paginated([p.model_dump() for p in posts], page, size, total)


@router.post("/posts", response_model=dict)
async def create_post(
    body: PostCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    post = await board_service.create_post(db, body, current_user)
    return ok(post.model_dump())


@router.get("/posts/{post_id}", response_model=dict)
async def get_post(
    post_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    post = await board_service.get_post(db, post_id, current_user)
    return ok(post.model_dump())


@router.patch("/posts/{post_id}", response_model=dict)
async def update_post(
    post_id: int,
    body: PostUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    post = await board_service.update_post(db, post_id, body, current_user)
    return ok(post.model_dump())


@router.delete("/posts/{post_id}", response_model=dict)
async def delete_post(
    post_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await board_service.delete_post(db, post_id, current_user)
    return ok({"ok": True})


@router.post("/posts/{post_id}/pin", response_model=dict)
async def pin_post(
    post_id: int,
    body: PinRequest,
    _: Annotated[User, Depends(require_roles("admin_ops", "instructor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    post = await board_service.toggle_pin(db, post_id, body.pinned)
    return ok(post.model_dump())


@router.get("/posts/{post_id}/comments", response_model=dict)
async def list_comments(
    post_id: int,
    _: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    comments = await board_service.list_comments(db, post_id)
    return ok([c.model_dump() for c in comments])


@router.post("/posts/{post_id}/comments", response_model=dict)
async def create_comment(
    post_id: int,
    body: CommentCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    comment = await board_service.create_comment(db, post_id, body, current_user)
    return ok(comment.model_dump())


@router.patch("/comments/{comment_id}", response_model=dict)
async def update_comment(
    comment_id: int,
    body: CommentUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    comment = await board_service.update_comment(db, comment_id, body, current_user)
    return ok(comment.model_dump())


@router.delete("/comments/{comment_id}", response_model=dict)
async def delete_comment(
    comment_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await board_service.delete_comment(db, comment_id, current_user)
    return ok({"ok": True})


@router.get("/posts/{post_id}/author-identity", response_model=dict)
async def get_author_identity(
    post_id: int,
    reason: str = Query(min_length=1),
    current_user: Annotated[User, Depends(require_roles("admin_ops"))] = None,
    db: Annotated[AsyncSession, Depends(get_db)] = None,
):
    identity = await board_service.get_author_identity(db, post_id, reason, current_user)
    return ok(identity.model_dump())
