from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.auth import AuditLog, User
from app.models.board import Board, Comment, Post
from app.models.organization import InstructorCohort
from app.schemas.board import (
    AuthorIdentityOut,
    BoardCreate,
    BoardOut,
    BoardUpdate,
    CommentCreate,
    CommentOut,
    CommentUpdate,
    PostCreate,
    PostOut,
    PostUpdate,
)


async def list_boards(
    db: AsyncSession,
    current_user: User,
    cohort_id: Optional[int] = None,
    board_type: Optional[str] = None,
) -> list[BoardOut]:
    query = select(Board).where(Board.is_active == True)

    # Cohort scoping by role. Staff (admin_ops / instructor) have no personal
    # cohort_id, so the old "cohort_id == current_user.cohort_id" base filter
    # (ANDed) hid every cohort board from them. Scope by role instead:
    #   - admin_ops : all institution boards (optionally narrowed by cohort_id)
    #   - instructor: institution-wide + their assigned cohorts (or the passed cohort_id)
    #   - student   : institution-wide + their own cohort
    if current_user.role == "admin_ops":
        if cohort_id:
            query = query.where(
                or_(Board.cohort_id == None, Board.cohort_id == cohort_id)
            )
        # else: no cohort restriction — ops sees all boards.
    elif current_user.role == "instructor":
        if cohort_id:
            query = query.where(
                or_(Board.cohort_id == None, Board.cohort_id == cohort_id)
            )
        else:
            assigned = select(InstructorCohort.cohort_id).where(
                InstructorCohort.instructor_id == current_user.id
            )
            query = query.where(
                or_(Board.cohort_id == None, Board.cohort_id.in_(assigned))
            )
    else:
        query = query.where(
            or_(Board.cohort_id == None, Board.cohort_id == current_user.cohort_id)
        )
        if cohort_id:
            query = query.where(
                or_(Board.cohort_id == None, Board.cohort_id == cohort_id)
            )
    if board_type:
        query = query.where(Board.type == board_type)

    result = await db.execute(query.order_by(Board.sort_order))
    return [BoardOut.model_validate(b) for b in result.scalars().all()]


async def create_board(db: AsyncSession, data: BoardCreate, current_user: User) -> BoardOut:
    board = Board(**data.model_dump(), created_by=current_user.id)
    db.add(board)
    await db.commit()
    await db.refresh(board)
    return BoardOut.model_validate(board)


async def get_board(db: AsyncSession, board_id: int) -> BoardOut:
    result = await db.execute(select(Board).where(Board.id == board_id))
    board = result.scalar_one_or_none()
    if board is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "게시판을 찾을 수 없습니다."})
    return BoardOut.model_validate(board)


async def update_board(
    db: AsyncSession, board_id: int, data: BoardUpdate, current_user: User
) -> BoardOut:
    result = await db.execute(select(Board).where(Board.id == board_id))
    board = result.scalar_one_or_none()
    if board is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "게시판을 찾을 수 없습니다."})

    if current_user.role != "admin_ops" and board.created_by != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(board, field, value)
    await db.commit()
    await db.refresh(board)
    return BoardOut.model_validate(board)


async def delete_board(db: AsyncSession, board_id: int, current_user: User) -> None:
    result = await db.execute(select(Board).where(Board.id == board_id))
    board = result.scalar_one_or_none()
    if board is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "게시판을 찾을 수 없습니다."})

    if current_user.role != "admin_ops" and board.created_by != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    board.is_active = False
    await db.commit()


async def list_posts(
    db: AsyncSession,
    current_user: User,
    board_id: Optional[int] = None,
    search: Optional[str] = None,
    author_id: Optional[int] = None,
    page: int = 1,
    size: int = 20,
) -> tuple[list[PostOut], int]:
    query = select(Post).where(Post.deleted_at == None)
    if board_id:
        query = query.where(Post.board_id == board_id)
    if search:
        query = query.where(
            or_(Post.title.ilike(f"%{search}%"), Post.content.ilike(f"%{search}%"))
        )
    if author_id:
        query = query.where(Post.author_id == author_id)

    if current_user.role == "student":
        query = query.where(
            or_(Post.is_private == False, Post.author_id == current_user.id)
        )

    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar_one()

    result = await db.execute(
        query.order_by(Post.is_pinned.desc(), Post.created_at.desc())
        .offset((page - 1) * size)
        .limit(size)
    )
    posts = result.scalars().all()
    return [PostOut.model_validate(p) for p in posts], total


async def create_post(db: AsyncSession, data: PostCreate, current_user: User) -> PostOut:
    board_result = await db.execute(select(Board).where(Board.id == data.board_id))
    board = board_result.scalar_one_or_none()
    if board is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "게시판을 찾을 수 없습니다."})
    if data.is_anonymous and not board.allow_anonymous:
        raise HTTPException(status_code=422, detail={"code": "ANONYMOUS_NOT_ALLOWED", "message": "이 게시판은 익명 작성을 허용하지 않습니다."})

    post = Post(**data.model_dump(), author_id=current_user.id)
    db.add(post)
    await db.commit()
    await db.refresh(post)
    return PostOut.model_validate(post)


async def get_post(db: AsyncSession, post_id: int, current_user: User) -> PostOut:
    result = await db.execute(
        select(Post).where(Post.id == post_id, Post.deleted_at == None)
    )
    post = result.scalar_one_or_none()
    if post is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "게시글을 찾을 수 없습니다."})

    if post.is_private and current_user.role == "student" and post.author_id != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "비밀글은 작성자만 조회 가능합니다."})

    post.view_count += 1
    await db.commit()
    await db.refresh(post)
    return PostOut.model_validate(post)


async def update_post(
    db: AsyncSession, post_id: int, data: PostUpdate, current_user: User
) -> PostOut:
    result = await db.execute(
        select(Post).where(Post.id == post_id, Post.deleted_at == None)
    )
    post = result.scalar_one_or_none()
    if post is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "게시글을 찾을 수 없습니다."})

    if current_user.role != "admin_ops" and post.author_id != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(post, field, value)
    await db.commit()
    await db.refresh(post)
    return PostOut.model_validate(post)


async def delete_post(db: AsyncSession, post_id: int, current_user: User) -> None:
    result = await db.execute(
        select(Post).where(Post.id == post_id, Post.deleted_at == None)
    )
    post = result.scalar_one_or_none()
    if post is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "게시글을 찾을 수 없습니다."})

    if current_user.role != "admin_ops" and post.author_id != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    post.deleted_at = datetime.now(timezone.utc)
    await db.commit()


async def toggle_pin(db: AsyncSession, post_id: int, pinned: bool) -> PostOut:
    result = await db.execute(
        select(Post).where(Post.id == post_id, Post.deleted_at == None)
    )
    post = result.scalar_one_or_none()
    if post is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "게시글을 찾을 수 없습니다."})
    post.is_pinned = pinned
    await db.commit()
    await db.refresh(post)
    return PostOut.model_validate(post)


async def list_comments(db: AsyncSession, post_id: int) -> list[CommentOut]:
    result = await db.execute(
        select(Comment).where(
            Comment.post_id == post_id, Comment.deleted_at == None
        ).order_by(Comment.created_at)
    )
    return [CommentOut.model_validate(c) for c in result.scalars().all()]


async def create_comment(
    db: AsyncSession, post_id: int, data: CommentCreate, current_user: User
) -> CommentOut:
    comment = Comment(
        post_id=post_id,
        submission_id=None,
        author_id=current_user.id,
        **data.model_dump(),
    )
    db.add(comment)
    await db.commit()
    await db.refresh(comment)
    return CommentOut.model_validate(comment)


async def update_comment(
    db: AsyncSession, comment_id: int, data: CommentUpdate, current_user: User
) -> CommentOut:
    result = await db.execute(
        select(Comment).where(Comment.id == comment_id, Comment.deleted_at == None)
    )
    comment = result.scalar_one_or_none()
    if comment is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "댓글을 찾을 수 없습니다."})

    if current_user.role != "admin_ops" and comment.author_id != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    comment.content = data.content
    await db.commit()
    await db.refresh(comment)
    return CommentOut.model_validate(comment)


async def delete_comment(db: AsyncSession, comment_id: int, current_user: User) -> None:
    result = await db.execute(
        select(Comment).where(Comment.id == comment_id, Comment.deleted_at == None)
    )
    comment = result.scalar_one_or_none()
    if comment is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "댓글을 찾을 수 없습니다."})

    if current_user.role != "admin_ops" and comment.author_id != current_user.id:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "접근 권한이 없습니다."})

    comment.deleted_at = datetime.now(timezone.utc)
    await db.commit()


async def get_author_identity(
    db: AsyncSession, post_id: int, reason: str, current_user: User
) -> AuthorIdentityOut:
    result = await db.execute(select(Post).where(Post.id == post_id))
    post = result.scalar_one_or_none()
    if post is None:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "게시글을 찾을 수 없습니다."})

    author_result = await db.execute(select(User).where(User.id == post.author_id))
    author = author_result.scalar_one()

    log = AuditLog(
        actor_id=current_user.id,
        action="anonymous_identity.read",
        target_type="post",
        target_id=post_id,
        after_data={"reason": reason, "post_author_id": post.author_id},
        created_at=datetime.now(timezone.utc),
    )
    db.add(log)
    await db.commit()

    return AuthorIdentityOut(
        author_id=author.id,
        author_name=author.name,
        created_at=post.created_at,
    )
