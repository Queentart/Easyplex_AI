import asyncio
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db.session import SessionLocal
from app.models.executive import DashboardMetric, AuditLog, MetricCategory
from app.models.equipment import Equipment, EquipmentStatus
from app.models.tech_task import TechTask, TaskPriority, TaskStatus
import json

async def seed_dashboard_data(db: AsyncSession):
    # Check if data already exists
    result = await db.execute(select(DashboardMetric).limit(1))
    if result.scalars().first():
        print("대시보드 초기 데이터가 이미 존재합니다.")
        return

    print("대시보드 초기 데이터를 생성합니다...")

    # Executive Metrics
    metrics = [
        {"category": MetricCategory.EXECUTIVE, "key": "overall_profitability", "value": "24.5%", "trend": "up", "trend_value": "+2.1%", "subtitle": "+2.1% vs last quarter"},
        {"category": MetricCategory.EXECUTIVE, "key": "avg_placement_rate", "value": "88.2%", "trend": "up", "subtitle": "Target: 85%"},
        {"category": MetricCategory.EXECUTIVE, "key": "global_roi", "value": "142%", "trend": "up", "subtitle": "Exceeding projections"},
        {"category": MetricCategory.EDUOOP, "key": "active_batches", "value": "8", "trend": "up", "trend_value": "+2", "subtitle": "+2 this quarter"},
        {"category": MetricCategory.EDUOOP, "key": "avg_attendance", "value": "94.2%", "trend": "up", "subtitle": "Target: 90%"},
        {"category": MetricCategory.TECHOPS, "key": "cloud_infra_spend", "value": "$4,250", "trend": "up", "trend_value": "+12%", "subtitle": "Increase"},
        {"category": MetricCategory.TECHOPS, "key": "llm_token_usage", "value": "12.4M", "subtitle": "62% of quota"},
    ]
    
    for m in metrics:
        db.add(DashboardMetric(**m))

    # Audit Logs
    logs = [
        {"category": MetricCategory.EXECUTIVE, "message": "Admin login from 192.168.1.45", "level": "success"},
        {"category": MetricCategory.EXECUTIVE, "message": "Policy updated: Data Isolation enabled", "level": "info"},
        {"category": MetricCategory.EXECUTIVE, "message": "Failed login attempt from unknown IP", "level": "danger"},
    ]
    for log in logs:
        db.add(AuditLog(**log))

    # Equipment
    equipment = [
        {"device_id": "SV-001", "name": "Main Database Server", "type": "Server", "location": "Rack A", "status": EquipmentStatus.ONLINE, "uptime": "99.99%"},
        {"device_id": "RT-002", "name": "Core Router 1", "type": "Network", "location": "Rack B", "status": EquipmentStatus.WARNING, "uptime": "99.95%"},
        {"device_id": "SV-003", "name": "Backup Storage", "type": "Storage", "location": "Rack A", "status": EquipmentStatus.ONLINE, "uptime": "100%"},
    ]
    for eq in equipment:
        db.add(Equipment(**eq))

    # Tech Tasks
    tasks = [
        {"title": "Upgrade PostgreSQL version", "description": "Upgrade to v16 for vector support", "priority": TaskPriority.HIGH, "status": TaskStatus.PENDING},
        {"title": "Fix Network Latency", "description": "Investigate routing issues in Room A", "priority": TaskPriority.CRITICAL, "status": TaskStatus.IN_PROGRESS},
        {"title": "Deploy new Frontend", "description": "Deploy to Vercel", "priority": TaskPriority.MEDIUM, "status": TaskStatus.RESOLVED},
    ]
    for task in tasks:
        db.add(TechTask(**task))

    await db.commit()
    print("대시보드 초기 데이터 생성 완료!")

async def main():
    async with SessionLocal() as session:
        await seed_dashboard_data(session)

if __name__ == "__main__":
    asyncio.run(main())
