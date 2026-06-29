from sqlalchemy import Column, Integer, String, DateTime, Enum, Boolean, Text
from app.db.base_class import Base
from datetime import datetime, timezone
import enum

class EquipmentStatus(str, enum.Enum):
    ONLINE = "ONLINE"
    WARNING = "WARNING"
    OFFLINE = "OFFLINE"
    MAINTENANCE = "MAINTENANCE"

class Equipment(Base):
    """장비 관리 모델"""
    __tablename__ = "equipment"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String(100), unique=True, index=True, nullable=False)
    name = Column(String(200), nullable=False)
    type = Column(String(100), nullable=False) # Server, Router, Camera 등
    location = Column(String(100), nullable=True)
    status = Column(Enum(EquipmentStatus), default=EquipmentStatus.ONLINE, nullable=False)
    uptime = Column(String(50), nullable=True)
    last_ping = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    notes = Column(Text, nullable=True)