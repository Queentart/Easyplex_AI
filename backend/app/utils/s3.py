import urllib.parse

import boto3
from botocore.exceptions import ClientError

from app.core.config import settings


def get_s3_client():
    kwargs: dict = {
        "region_name": settings.aws_region,
        "aws_access_key_id": settings.aws_access_key_id,
        "aws_secret_access_key": settings.aws_secret_access_key,
    }
    if settings.aws_endpoint_url:
        kwargs["endpoint_url"] = settings.aws_endpoint_url
    return boto3.client("s3", **kwargs)


def generate_presigned_upload_url(
    file_key: str,
    content_type: str,
    expires_in: int = 300,
) -> str:
    client = get_s3_client()
    return client.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": settings.aws_s3_bucket,
            "Key": file_key,
            "ContentType": content_type,
        },
        ExpiresIn=expires_in,
    )


def generate_presigned_download_url(
    file_key: str,
    expires_in: int = 3600,
    download: bool = False,
    filename: str | None = None,
) -> str:
    client = get_s3_client()
    params: dict = {
        "Bucket": settings.aws_s3_bucket,
        "Key": file_key,
    }
    if download:
        # Force the browser to download (attachment) instead of inline rendering.
        # RFC 5987 encoding avoids header injection / breakage from quotes,
        # CRLF, or non-ASCII (e.g. Korean) characters in the filename.
        disposition = "attachment"
        if filename:
            safe = urllib.parse.quote(filename, safe="")
            disposition = f"attachment; filename*=UTF-8''{safe}"
        params["ResponseContentDisposition"] = disposition
    return client.generate_presigned_url(
        "get_object",
        Params=params,
        ExpiresIn=expires_in,
    )


def delete_object(file_key: str) -> None:
    client = get_s3_client()
    client.delete_object(Bucket=settings.aws_s3_bucket, Key=file_key)


def ensure_bucket() -> None:
    """Ensure the configured S3/MinIO bucket exists, creating it if missing.

    Called once on app startup. New environments (and MinIO instances that lost
    their state) may not have the bucket yet; without it every presign-based
    upload (assignments, posts, course videos, ...) silently fails on PUT.
    """
    client = get_s3_client()
    bucket = settings.aws_s3_bucket
    try:
        client.head_bucket(Bucket=bucket)
    except ClientError as e:
        # Only create on "not found" — a 403/auth error means the bucket exists
        # (or credentials are wrong), and blindly creating would mask the cause.
        code = str(e.response.get("Error", {}).get("Code", ""))
        if code in ("404", "NoSuchBucket", "NotFound"):
            client.create_bucket(Bucket=bucket)
        else:
            raise
