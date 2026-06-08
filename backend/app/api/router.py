from fastapi import APIRouter

from app.api.v1 import (
    ai_agent,
    assignments,
    attendance,
    auth,
    boards,
    chat,
    classes,
    cohorts,
    courses,
    files,
    inquiries,
    leave_requests,
    licenses,
    notifications,
    posts,
    users,
)

api_router = APIRouter()

# Phase 3
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(cohorts.router)

# Phase 4
api_router.include_router(attendance.router)
api_router.include_router(boards.router)
api_router.include_router(posts.router)
api_router.include_router(assignments.router)

# Phase 5
api_router.include_router(leave_requests.router)
api_router.include_router(inquiries.router)
api_router.include_router(licenses.router)
api_router.include_router(classes.router)
api_router.include_router(courses.router)

# Phase 6
api_router.include_router(notifications.router)
api_router.include_router(chat.router)
api_router.include_router(ai_agent.router)

# Utilities
api_router.include_router(files.router)
