from sqlalchemy import Column, Integer, String, Float, DateTime, Enum, Boolean
from app.db.base_class import Base
from datetime import datetime, timezone
import enum

class MetricCategory(str, enum.Enum):
    EXECUTIVE = "EXECUTIVE"
    EDUOOP = "EDUOOP"
    TECHOPS = "TECHOPS"

class DashboardMetric(Base):
    """대시보드 KPI 및 상태 지표를 저장하는 모델"""
    __tablename__ = "dashboard_metrics"

    id = Column(Integer, primary_key=True, index=True)
    category = Column(Enum(MetricCategory), nullable=False)
    key = Column(String(100), unique=True, index=True, nullable=False)
    value = Column(String(255), nullable=False) # 문자열로 저장하되, 프론트에서 파싱
    trend = Column(String(50), nullable=True) # "up", "down", "neutral"
    trend_value = Column(String(50), nullable=True)
    subtitle = Column(String(255), nullable=True)
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

class AuditLog(Base):
    """감사 로그 및 시스템 로그"""
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    category = Column(Enum(MetricCategory), nullable=False)
    message = Column(String(500), nullable=False)
    level = Column(String(50), nullable=False, default="info") # info, warning, danger, success
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))