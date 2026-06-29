# Instructor Q&A System - Implementation Walkthrough

The Instructor Q&A system has been fully deployed! Students can now send categorized learning questions, and both Instructors and Mentors have a dedicated, synchronized dashboard to manage and reply to them.

## 1. Database Integration
- **New Model**: `InstructorTicket` was added to `instructor_models.py`, utilizing identical fields to EduOps (`id`, `student_name`, `message`, `status`, `reply`, `replied_by`, `created_at`, `replied_at`) to enable a robust, threaded question-and-answer workflow.
- **Migration**: The backend database was successfully synchronized to include the new `instructor_tickets` table via SQLAlchemy schema creation.

## 2. API Endpoints
- **Student Messaging Endpoint**: The logic in `support.py` (`mode == "instructor"`) now automatically creates a new `InstructorTicket` when a category is specified (e.g., `[학습 관련 질문]`), or appends to an active ticket to maintain the conversation history.
- **Polling System**: Added `GET /instructor-tickets` for the student client to fetch real-time updates.
- **Instructor API Router**: Created `questions.py` to provide the endpoints for the instructor dashboard (`GET /tickets` and `POST /tickets/{ticket_id}/reply`). This allows any user with the `instructor` or `mentor` role to answer a question.

## 3. Frontend: Student UI
- **Categories**: Added "학습 관련 질문" and "기타 질의 사항" category quick buttons. Clicking these will prefix the next message and initiate a new topic.
- **System Bubble Fix**: Just like we did for Operations and Tech support, the system message notification bubble ("Your question has been posted...") safely persists locally when sending a message and won't be wiped out by the automated data sync.
- **Chat Continuity**: The local state reliably polls for updates from the DB every 5 seconds, pulling down the latest replies and dynamically reconstructing the chat sequence.

## 4. Frontend: Instructor/Mentor UI
- **New Dashboard Page**: Created `LearningQuestions.tsx`. This page meticulously follows the layout of the EduOps "문의사항" page but is built exclusively with an **Orange** theme (`text-orange-600`, `bg-orange-50`) to match the "Instructor Q&A" brand identity.
- **Role Sharing**: The page seamlessly accommodates both roles. Regardless of whether a 주강사 (Instructor) or a 멘토 (Mentor) replies, the reply is securely saved in the database under their name and instantly synced to the student's pop-up.
- **Sidebar Integration**: The new "학습 질문 게시판" menu item is fully accessible on the left-hand navigation bar for `instructor` and `mentor` accounts.

### 🧪 Verification Steps
1. Navigate to the student AI Help Bot pop-up, choose "Instructor Q&A".
2. Select a category and send a message. Notice the gray system bubble appears seamlessly.
3. Log in as an Instructor or Mentor and click "학습 질문 게시판" in the sidebar.
4. Reply to the new student question.
5. Watch the reply automatically render back on the student's pop-up.
