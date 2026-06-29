from fastapi import APIRouter
from . import daily_ops, equipment, student_mgmt, streams

router = APIRouter()

router.include_router(daily_ops.router, prefix="/daily-ops", tags=["TechOps Daily"])
router.include_router(equipment.router, prefix="/equipment", tags=["TechOps Equipment"])
router.include_router(student_mgmt.router, prefix="/student-mgmt", tags=["TechOps Students"])
router.include_router(streams.router, prefix="/streams", tags=["TechOps Streams"])
