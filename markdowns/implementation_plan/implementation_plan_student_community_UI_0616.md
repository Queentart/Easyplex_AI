# Student Community Tab Improvements

This document outlines the plan to significantly improve the Student Community tab, adding post details, comment viewing, reporting functionality, and a notification system for interactions.

## Goal
Improve the Community tab by allowing users to view post details, interact with posts (like/comment), report inappropriate content, and trigger targeted notifications for post and comment authors.

## Open Questions
- Do you want the "Report" feature to just be a mock UI showing a "Report Submitted" toast message, or do you need a specific backend admin page for the Ops team to review these reports right now? (The plan currently includes a backend API to receive the report, but no new admin UI to view them).
- Should the "Comments Modal" close automatically when navigating to the Post Detail page? (Assumed yes).

## Proposed Changes

### Frontend (React)

#### [MODIFY] `src/types/index.ts`
- Extend `CommunityPost` interface to include `isLiked: boolean` and `commentsList: Comment[]`.
- Add `Comment` interface (`id`, `author`, `content`, `timeAgo`, `likes`, `isLiked`).

#### [MODIFY] `src/data/student.ts`
- Add mock `commentsList` data to existing `communityPosts` to demonstrate the new UI.

#### [MODIFY] `src/pages/student/Community.tsx`
- Implement local state for posts to allow instant toggling of "Like" status.
- Add a "Report" (신고) icon button to each post.
- Clicking the comment icon opens a new `CommentsModal`.
- Clicking the post body navigates to `/student/community/:postId`.

#### [NEW] `src/components/common/CommentsModal.tsx`
- A reusable popup modal to display a post's comments.
- Includes a "Report" button for each comment.
- Includes a "View Post" (게시글 보기) button at the bottom right that navigates to the detailed post page.

#### [NEW] `src/pages/student/PostDetail.tsx`
- A dedicated page to view the full post.
- Displays the post content, like/comment counts, and the list of comments.
- Includes a text input to write a new comment (UI only or mocks backend call).
- Includes "Report" functionality for the post and its comments.

#### [MODIFY] `src/App.tsx`
- Register the new route: `/student/community/:postId` mapping to `PostDetail`.

---

### Backend (FastAPI)

#### [NEW] `backend/app/api/v1/endpoints/community.py`
- `POST /{post_id}/like`: Toggles like status. Logs a mock notification: *"Notification sent to Post Author: Someone liked your post."*
- `POST /{post_id}/comment`: Adds a comment. Logs a mock notification: *"Notification sent to Post Author: Someone commented on your post."*
- `POST /comments/{comment_id}/like`: Likes a comment. Logs a mock notification: *"Notification sent to Comment Author: Someone liked your comment."*
- `POST /{post_id}/comments/{comment_id}/reply`: Replies to a comment. Logs a mock notification: *"Notification sent to Comment Author: Someone replied to your comment."*
- `POST /report`: Accepts a report payload (type: post or comment, id, reason). Logs the report for the Ops team to review.

#### [MODIFY] `backend/app/main.py`
- Include the new `community` router in the main API router.

## Verification Plan
### Manual Verification
1. Open the Student Community tab.
2. Click the "Like" button on a post and verify it toggles and updates the count.
3. Click the "Comment" button and verify the `CommentsModal` appears showing existing comments.
4. Click "View Post" in the modal or click the post body to navigate to `PostDetail.tsx`.
5. Inside `PostDetail.tsx`, verify the layout, comment list, and the ability to click "Report" on a post or comment.
6. Check the backend server logs to verify that mock Notifications are correctly targeted at either the Post Author or the Comment Author depending on the action.
