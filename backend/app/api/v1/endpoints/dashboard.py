from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Any, Dict, List

from app.api.deps import get_db, require_role
from app.models.auth import UserRole, User
from app.models.executive import DashboardMetric, AuditLog, MetricCategory
from app.models.equipment import Equipment
from app.models.tech_task import TechTask

router = APIRouter()

@router.get("/executive", response_model=Dict[str, Any])
async def get_executive_dashboard(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role([UserRole.OWNER, UserRole.TECHOPS, UserRole.EDUOPS, UserRole.INSTRUCTOR]))
) -> Any:
    """
    임원진(Owner 등)을 위한 대시보드 데이터를 반환합니다.
    """
    # 1. Metrics 가져오기
    metrics_result = await db.execute(select(DashboardMetric))
    metrics_db = metrics_result.scalars().all()
    
    # 2. Audit Logs 가져오기
    logs_result = await db.execute(select(AuditLog).order_by(AuditLog.created_at.desc()).limit(5))
    audit_logs = logs_result.scalars().all()
    
    # 변환: 프론트엔드 포맷에 맞게 조립
    kpi_cards = []
    for m in metrics_db:
        if m.category == MetricCategory.EXECUTIVE:
            kpi_cards.append({
                "id": m.key,
                "title": m.key.replace("_", " ").upper(),
                "value": m.value,
                "subtitle": m.subtitle,
                "trend": m.trend,
                "trendValue": m.trend_value
            })
            
    logs_data = []
    for log in audit_logs:
        logs_data.append({
            "id": f"log-{log.id}",
            "message": log.message,
            "icon": "info",
            "iconColor": f"var(--color-{log.level})",
            "time": log.created_at.strftime("%Y-%m-%d %H:%M:%S")
        })

    return {
        "kpiCards": kpi_cards,
        "auditLogs": logs_data,
        # 추가적인 수익률 추세 등은 현재 하드코딩되거나 추가 모델 확장이 필요함 (예제 목적상 일부만 연동)
    }

@router.get("/techops", response_model=Dict[str, Any])
async def get_techops_dashboard(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role([UserRole.OWNER, UserRole.TECHOPS]))
) -> Any:
    """
    TechOps 관리자를 위한 대시보드 데이터를 반환합니다.
    """
    # Metrics
    metrics_result = await db.execute(select(DashboardMetric).where(DashboardMetric.category == MetricCategory.TECHOPS))
    metrics_db = metrics_result.scalars().all()
    
    # Equipment
    equipment_result = await db.execute(select(Equipment))
    equipments = equipment_result.scalars().all()
    
    # Tasks
    tasks_result = await db.execute(select(TechTask))
    tasks = tasks_result.scalars().all()
    
    cost_cards = []
    for m in metrics_db:
        cost_cards.append({
            "title": m.key.replace("_", " ").upper(),
            "value": m.value,
            "change": m.trend_value,
            "progressLabel": m.subtitle
        })
        
    equipment_data = []
    for eq in equipments:
        equipment_data.append({
            "id": eq.device_id,
            "name": eq.name,
            "type": eq.type,
            "location": eq.location,
            "status": str(eq.status.value).lower(),
            "uptime": eq.uptime
        })
        
    tasks_data = []
    for t in tasks:
        tasks_data.append({
            "id": f"task-{t.id}",
            "title": t.title,
            "priority": str(t.priority.value).lower(),
            "status": str(t.status.value).lower(),
            "assignee": t.assignee.full_name if t.assignee else "Unassigned"
        })

    return {
        "costCards": cost_cards,
        "equipment": equipment_data,
        "tasks": tasks_data
    }
