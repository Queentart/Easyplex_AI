from fastapi import APIRouter, Body
from pydantic import BaseModel
import logging

# 기본 로거 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("CommunityAPI")

router = APIRouter()

class ReportRequest(BaseModel):
    type: str  # 'post' or 'comment'
    target_id: str
    reason: str

class PostUpdateRequest(BaseModel):
    content: str

@router.put("/{post_id}")
async def update_post(post_id: str, request: PostUpdateRequest):
    logger.info(f"Post {post_id} updated with new content.")
    return {"status": "success", "message": "Post updated successfully"}

@router.delete("/{post_id}")
async def delete_post(post_id: str):
    logger.info(f"Post {post_id} deleted.")
    return {"status": "success", "message": "Post deleted successfully"}

@router.post("/{post_id}/like")
async def like_post(post_id: str):
    # [시뮬레이션] 게시글 작성자에게 알림 발송
    logger.info(f"Notification sent to Post Author: Someone liked your post (ID: {post_id}).")
    return {"status": "success", "message": "Post liked successfully"}

@router.post("/{post_id}/comment")
async def add_comment(post_id: str):
    # [시뮬레이션] 게시글 작성자에게 알림 발송
    logger.info(f"Notification sent to Post Author: Someone commented on your post (ID: {post_id}).")
    return {"status": "success", "message": "Comment added successfully"}

@router.post("/comments/{comment_id}/like")
async def like_comment(comment_id: str):
    # [시뮬레이션] 댓글 작성자에게 알림 발송
    logger.info(f"Notification sent to Comment Author: Someone liked your comment (ID: {comment_id}).")
    return {"status": "success", "message": "Comment liked successfully"}

@router.post("/report")
async def report_content(request: ReportRequest):
    # [시뮬레이션] 운영팀(Ops)에게 신고 접수 및 알림 발송
    logger.warning(f"URGENT: Ops Team Alert - Inappropriate content reported! Type: {request.type}, Target ID: {request.target_id}, Reason: {request.reason}")
    return {"status": "success", "message": f"{request.type} reported successfully. Ops team will review it shortly."}