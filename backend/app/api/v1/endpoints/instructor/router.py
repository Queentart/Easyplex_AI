from fastapi import APIRouter
from . import materials, logs, chat, questions

router = APIRouter()

router.include_router(materials.router, prefix="/materials", tags=["Instructor Materials"])
router.include_router(logs.router, prefix="/logs", tags=["Instructor Logs"])
router.include_router(chat.router, prefix="/chat", tags=["Instructor Chat"])
router.include_router(questions.router, prefix="/questions", tags=["Instructor Questions"])
