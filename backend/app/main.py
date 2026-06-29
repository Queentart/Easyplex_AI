from fastapi import FastAPI, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
import sys
import os
import asyncio

from alembic import command
from alembic.config import Config as AlembicConfig

from app.core.config import settings
from app.db.session import check_database_connection
from app.db.redis_client import redis_client
from app.api.v1.endpoints import auth, dashboard

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def run_migrations():
    """
    서버 시작 시 Alembic 마이그레이션을 자동으로 실행하여 DB 스키마를 최신 상태로 유지합니다.
    """
    # [수정] 비동기 루프(FastAPI Lifespan) 내에서 동기 Alembic 마이그레이션을 
    # 스레드로 돌릴 때 asyncpg와 충돌하여 서버 시작이 멈추는 데드락 현상이 발생합니다.
    # 따라서 자동 마이그레이션을 비활성화하고, 터미널에서 직접 실행하도록 우회합니다.
    return
    try:
        logger.info("Alembic 마이그레이션 자동 실행을 시작합니다...")
        # 현재 디렉터리를 기준으로 alembic.ini 경로 설정
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        alembic_cfg_path = os.path.join(base_dir, "alembic.ini")
        alembic_cfg = AlembicConfig(alembic_cfg_path)
        
        # migration 디렉터리가 루트를 기준으로 올바르게 설정되도록
        alembic_cfg.set_main_option("script_location", os.path.join(base_dir, "alembic"))
        
        # alembic upgrade head 실행
        command.upgrade(alembic_cfg, "head")
        logger.info("Alembic 마이그레이션 적용 완료.")
    except Exception as e:
        logger.error(f"Alembic 마이그레이션 실행 중 오류 발생: {e}")
        # 마이그레이션 실패 시 서버 구동 중지
        sys.exit(1)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI 서버 시작과 종료 시 실행될 수명주기(Lifespan) 이벤트입니다.
    - 서버 시작: DB 연결 확인, 벡터 확장 확인, Redis 연결, Alembic 마이그레이션 적용
    - 서버 종료: Redis 자원 해제 등
    """
    logger.info("=== 백엔드 서버 초기화를 시작합니다 ===")
    
    # 1. Redis 연결
    redis_connected = await redis_client.connect()
    if not redis_connected:
        logger.warning("Redis 연결에 실패했습니다. 캐싱 없이 동작할 수 있습니다.")

    # 2. PostgreSQL 연결 및 pgvector 확장 확인
    db_connected = await check_database_connection()
    if not db_connected:
        logger.error("데이터베이스 연결에 실패하여 서버를 시작할 수 없습니다.")
        sys.exit(1)

    # 동기 함수이므로 별도의 스레드에서 실행하여 이벤트 루프 충돌을 방지합니다.
    await asyncio.to_thread(run_migrations)
    
    logger.info("=== 백엔드 서버 초기화 완료 ===")
    
    yield  # 애플리케이션 실행
    
    # --- 서버 종료 시 로직 ---
    logger.info("=== 백엔드 서버 종료 중... 자원을 반환합니다 ===")
    await redis_client.close()

# FastAPI 인스턴스 생성
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

from fastapi.staticfiles import StaticFiles

# CORS 설정 (프론트엔드 통신 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 실제 배포 시 특정 도메인으로 제한 필요
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 정적 파일 호스팅 (첨부파일 다운로드 등)
import os
base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
uploads_dir = os.path.join(base_dir, "uploads")
os.makedirs(uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=uploads_dir), name="uploads")

@app.get("/")
async def root():
    return {"message": "Welcome to EasyPlex AI Backend API"}

@app.get("/health")
async def health_check():
    """서버 및 데이터베이스 상태를 확인하는 엔드포인트"""
    # 간단한 Redis 테스트용 get (실제 캐싱 사용 예시)
    redis_status = "connected" if redis_client.redis else "disconnected"
    return {
        "status": "ok",
        "redis": redis_status,
        "database": "connected"
    }

# 기능별 라우터 연동
api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(dashboard.router, prefix="/dashboard", tags=["Dashboard"])

from app.api.v1.endpoints import counseling, assignments, rag, ai
from app.api.v1.endpoints.instructor import router as instructor_router
from app.api.v1.endpoints.ops import logs as ops_logs
from app.api.v1.endpoints.ops import inquiries as ops_inquiries
from app.api.v1.endpoints.tech import router as tech_router
from app.api.v1.endpoints.student import community as student_community
from app.api.v1.endpoints.student import support as student_support

from app.api.v1.endpoints.ops import announcements as ops_announcements
from app.api.v1.endpoints.student import announcements as student_announcements
from app.api.v1.endpoints.student import attendance as student_attendance
from app.api.v1.endpoints import curriculum
from app.api.v1.endpoints import notifications
from app.api.v1.endpoints import intranet_messages

api_router.include_router(counseling.router, prefix="/counseling", tags=["Counseling"])
api_router.include_router(assignments.router, prefix="/assignments", tags=["Assignments"])
api_router.include_router(rag.router, prefix="/rag", tags=["RAG"])
api_router.include_router(ai.router, prefix="/ai", tags=["AI Agents"])
api_router.include_router(instructor_router.router, prefix="/instructor", tags=["Instructor"])
api_router.include_router(ops_logs.router, prefix="/ops/logs", tags=["Ops"])
api_router.include_router(ops_inquiries.router, prefix="/ops/inquiries", tags=["Ops Inquiries"])
api_router.include_router(ops_announcements.router, prefix="/ops/announcements", tags=["Ops Announcements"])
api_router.include_router(tech_router.router, prefix="/tech", tags=["TechOps"])
api_router.include_router(student_community.router, prefix="/student/community", tags=["Student Community"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])
api_router.include_router(student_support.router, prefix="/student/support", tags=["Student Support"])
api_router.include_router(student_announcements.router, prefix="/student/announcements", tags=["Student Announcements"])
api_router.include_router(student_attendance.router, prefix="/student/attendance", tags=["Student Attendance"])
api_router.include_router(curriculum.router, prefix="/curriculum", tags=["Curriculum"])
api_router.include_router(intranet_messages.router, prefix="/intranet-messages", tags=["Intranet Messages"])

app.include_router(api_router, prefix=settings.API_V1_STR)

