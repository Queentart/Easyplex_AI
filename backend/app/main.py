from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.core.config import settings
from app.core.exceptions import register_exception_handlers
from app.utils.s3 import ensure_bucket

app = FastAPI(
    title="동아AI랩 교육 운영 플랫폼",
    version="0.1.0",
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
    redirect_slashes=False,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.debug else ["https://dongaai.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

register_exception_handlers(app)

app.include_router(api_router, prefix="/api/v1")


@app.on_event("startup")
async def _ensure_s3_bucket() -> None:
    # Bootstrap the object-storage bucket so presign uploads work on a fresh
    # environment. A MinIO hiccup must not crash startup.
    try:
        ensure_bucket()
    except Exception as exc:  # noqa: BLE001 - best-effort bootstrap
        print(f"[startup] ensure_bucket failed (non-fatal): {exc}")


@app.get("/health", tags=["system"])
async def health():
    return {"status": "ok"}
