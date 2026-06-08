from typing import Annotated, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.deps import get_current_user
from app.models.auth import User
from app.schemas.common import ok
from app.utils.s3 import (
    generate_presigned_download_url,
    generate_presigned_upload_url,
)

router = APIRouter(prefix="/files", tags=["files"])

PURPOSE_PATHS = {
    "assignment_submission": "submissions",
    "assignment_attachment": "assignments",
    "leave_evidence": "evidences",
    "post_attachment": "posts",
    "chat_attachment": "chat",
    "recording": "recordings",
    "course_video": "course_videos",
    "profile_image": "profiles",
}


class PresignRequest(BaseModel):
    purpose: str
    context: dict = {}
    file_name: str
    content_type: str


class DownloadUrlRequest(BaseModel):
    file_key: str
    download: bool = False
    filename: Optional[str] = None


@router.post("/presign", response_model=dict)
async def presign_upload(
    body: PresignRequest,
    current_user: Annotated[User, Depends(get_current_user)],
):
    folder = PURPOSE_PATHS.get(body.purpose, "misc")
    import uuid
    key = f"{folder}/{current_user.institution_id}/{uuid.uuid4()}/{body.file_name}"
    url = generate_presigned_upload_url(key, content_type=body.content_type)
    return ok({"upload_url": url, "file_key": key})


@router.post("/download-url", response_model=dict)
async def download_url(
    body: DownloadUrlRequest,
    _: Annotated[User, Depends(get_current_user)],
):
    """Returns a short-lived presigned GET URL for viewing/downloading a stored
    file (e.g. rendering chat image attachments). Set ``download=True`` to get a
    URL that forces an attachment download (e.g. course video download button);
    the default inline behavior is unchanged."""
    url = generate_presigned_download_url(
        body.file_key, download=body.download, filename=body.filename
    )
    return ok({"url": url, "file_key": body.file_key})
