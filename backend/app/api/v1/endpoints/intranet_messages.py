from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import or_

from app.api import deps
from app.models.auth import User, UserRole
from app.models.intranet_message import IntranetMessage
from app.schemas.intranet_message import IntranetMessageCreate, IntranetMessageOut

router = APIRouter()

def get_allowed_receivers(role: UserRole) -> List[UserRole]:
    """각 역할별로 보낼 수 있는 대상 역할 목록을 반환합니다."""
    if role == UserRole.INSTRUCTOR:
        return [UserRole.TUTOR, UserRole.EDUOPS, UserRole.TECHOPS, UserRole.OWNER]
    elif role == UserRole.TUTOR:
        return [UserRole.INSTRUCTOR, UserRole.EDUOPS, UserRole.TECHOPS, UserRole.TUTOR]
    elif role == UserRole.EDUOPS:
        return [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.TECHOPS, UserRole.OWNER]
    elif role == UserRole.TECHOPS:
        return [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.EDUOPS, UserRole.OWNER]
    elif role == UserRole.OWNER:
        return [UserRole.INSTRUCTOR, UserRole.TUTOR, UserRole.EDUOPS, UserRole.TECHOPS]
    return []

@router.post("/", response_model=IntranetMessageOut)
async def create_intranet_message(
    *,
    db: AsyncSession = Depends(deps.get_db),
    msg_in: IntranetMessageCreate,
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    사내 인트라넷 메세지를 전송합니다.
    자신의 권한에 따라 허용된 수신자(Role)에게만 보낼 수 있습니다.
    """
    # 수강생은 사내 인트라넷 사용 불가
    if current_user.role == UserRole.STUDENT:
        raise HTTPException(status_code=403, detail="학생은 사내 인트라넷 메세지를 사용할 수 없습니다.")

    allowed_receivers = get_allowed_receivers(current_user.role)
    if msg_in.receiver_role not in allowed_receivers:
        raise HTTPException(
            status_code=403,
            detail=f"{current_user.role.value} 역할은 {msg_in.receiver_role.value} 역할에게 메세지를 보낼 수 없습니다."
        )

    db_msg = IntranetMessage(
        sender_id=current_user.id,
        receiver_role=msg_in.receiver_role,
        content=msg_in.content,
        cohort_name=msg_in.cohort_name,
    )
    db.add(db_msg)
    await db.commit()
    await db.refresh(db_msg)
    
    # 송신자 이름 매핑을 위해 수동 할당
    return IntranetMessageOut(
        id=db_msg.id,
        sender_id=db_msg.sender_id,
        sender_name=current_user.full_name or current_user.email,
        receiver_role=db_msg.receiver_role,
        content=db_msg.content,
        cohort_name=db_msg.cohort_name,
        created_at=db_msg.created_at
    )

@router.get("/", response_model=List[IntranetMessageOut])
async def read_intranet_messages(
    db: AsyncSession = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    현재 사용자가 볼 수 있는 메세지 목록을 조회합니다.
    자신이 보낸 메세지와 자신의 역할을 수신자로 하는 메세지가 포함됩니다.
    """
    if current_user.role == UserRole.STUDENT:
        raise HTTPException(status_code=403, detail="학생은 사내 인트라넷 메세지를 조회할 수 없습니다.")

    # 자신이 보낸 것이거나, 수신자가 자신의 역할인 메세지 조회
    # 삭제되지 않은(deleted_at IS NULL) 메세지만 조회 (추후 1개월 룰 적용)
    stmt = (
        select(IntranetMessage)
        .options(selectinload(IntranetMessage.sender))
        .where(
            IntranetMessage.deleted_at.is_(None),
            or_(
                IntranetMessage.sender_id == current_user.id,
                IntranetMessage.receiver_role == current_user.role
            )
        )
        .order_by(IntranetMessage.created_at.asc())
        .offset(skip)
        .limit(limit)
    )
    
    result = await db.execute(stmt)
    messages = result.scalars().all()
    
    out_messages = []
    for msg in messages:
        out_messages.append(
            IntranetMessageOut(
                id=msg.id,
                sender_id=msg.sender_id,
                sender_name=msg.sender.full_name or msg.sender.email if msg.sender else "Unknown",
                receiver_role=msg.receiver_role,
                content=msg.content,
                cohort_name=msg.cohort_name,
                created_at=msg.created_at
            )
        )
        
    return out_messages
