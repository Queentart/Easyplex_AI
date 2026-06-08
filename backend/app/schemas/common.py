from typing import Any, Generic, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class PaginationMeta(BaseModel):
    page: int
    size: int
    total: int


class ApiResponse(BaseModel, Generic[T]):
    data: T | None = None
    meta: dict = {}
    error: dict | None = None


def ok(data: Any, meta: dict | None = None) -> dict:
    return {"data": data, "meta": meta or {}, "error": None}


def paginated(data: Any, page: int, size: int, total: int) -> dict:
    return {
        "data": data,
        "meta": {"page": page, "size": size, "total": total},
        "error": None,
    }
