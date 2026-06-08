from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


def create_error_response(code: str, message: str, details=None) -> dict:
    err: dict = {"code": code, "message": message}
    if details:
        err["details"] = details
    return {"data": None, "meta": {}, "error": err}


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(request: Request, exc: RequestValidationError):
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content=create_error_response(
                "VALIDATION_ERROR",
                "입력값이 올바르지 않습니다.",
                exc.errors(),
            ),
        )

    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException):
        if isinstance(exc.detail, dict):
            content = {"data": None, "meta": {}, "error": exc.detail}
        else:
            content = create_error_response("ERROR", str(exc.detail))
        return JSONResponse(status_code=exc.status_code, content=content)

    @app.exception_handler(Exception)
    async def generic_error_handler(request: Request, exc: Exception):
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=create_error_response("INTERNAL_ERROR", "서버 오류가 발생했습니다."),
        )
