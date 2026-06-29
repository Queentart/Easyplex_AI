from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.notification import Notification, NotificationType
from app.models.auth import User, UserRole

async def create_notification(
    db: AsyncSession,
    user_id: int,
    title: str,
    message: str,
    type: NotificationType = NotificationType.INFO,
    link: str = None
) -> Notification:
    """
    새로운 알림을 생성하여 데이터베이스에 저장합니다.
    """
    notification = Notification(
        user_id=user_id,
        title=title,
        message=message,
        type=type,
        link=link
    )
    db.add(notification)
    await db.commit()
    await db.refresh(notification)
    return notification

async def create_global_notification(
    db: AsyncSession,
    title: str,
    message: str,
    type: NotificationType = NotificationType.INFO,
    link: str = None,
    target_role: UserRole = UserRole.STUDENT
) -> int:
    """
    특정 역할(기본값: STUDENT)을 가진 모든 사용자에게 알림을 일괄 발송합니다.
    """
    # 타겟 유저 조회
    user_res = await db.execute(select(User.id).where(User.role == target_role))
    user_ids = user_res.scalars().all()
    
    if not user_ids:
        return 0
        
    notifications = [
        Notification(
            user_id=uid,
            title=title,
            message=message,
            type=type,
            link=link
        )
        for uid in user_ids
    ]
    
    db.add_all(notifications)
    await db.commit()
    return len(notifications)

async def create_notification_by_name(
    db: AsyncSession,
    student_name: str,
    title: str,
    message: str,
    type: NotificationType = NotificationType.INFO,
    link: str = None
) -> bool:
    """
    이름(student_name)으로 사용자를 찾아 알림을 생성합니다.
    """
    user_res = await db.execute(select(User.id).where(User.full_name == student_name))
    user_id = user_res.scalars().first()
    
    if not user_id:
        return False
        
    await create_notification(
        db=db,
        user_id=user_id,
        title=title,
        message=message,
        type=type,
        link=link
    )
    return True
