# Implement Instructor Q&A System

This document outlines the architecture and implementation steps to fully realize the "Instructor Q&A" feature as a threaded ticket system, perfectly mirroring the recent EduOps integration but tailored for Instructors and Mentors.

## Goal Description
Convert the student-to-instructor chat mode into a continuous ticket-based support system. Students will be able to categorize questions, maintain message continuity, and receive structured replies from either an Instructor or a Mentor. Instructors and Mentors will get a new shared dashboard page ("학습 질문 게시판") to manage and reply to these questions.

## Proposed Changes

### Database Layer
#### [MODIFY] [instructor_models.py](file:///c:/Easyplex_AI/backend/app/models/instructor_models.py)
- Create a new `InstructorTicket` model identical in structure to `OpsTicket`.
- Fields: `id`, `student_name`, `message`, `status`, `reply`, `replied_by` (to track whether an instructor or mentor answered), `created_at`, `replied_at`.

### Backend API Layer
#### [MODIFY] [support.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/student/support.py)
- Refactor the `request.mode == "instructor"` logic in the message submission endpoint to append to an active `InstructorTicket` or create a new one if a category title is prefixed.
- Create a new polling endpoint `/api/v1/student/support/instructor-tickets` to allow the student frontend to fetch these tickets.

#### [NEW] [questions.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/instructor/questions.py)
- Create new endpoints exclusively for instructors/mentors:
  - `GET /tickets` (Fetch all instructor tickets)
  - `POST /tickets/{ticket_id}/reply` (Submit a reply, updating `replied_by`, `status`, and `replied_at`)

#### [MODIFY] [api.py](file:///c:/Easyplex_AI/backend/app/api/v1/api.py)
- Register the new `questions` router under the `/instructor` prefix.

### Frontend Student Client
#### [MODIFY] [AIHelpBot.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/AIHelpBot.tsx)
- Add `instructorCategory` state and render category buttons (`['학습 관련 질문', '기타 질의 사항']`) for the instructor mode.
- Intercept and prefix messages with the selected category.
- Establish a 5-second polling mechanism to fetch `instructorTickets` and synchronously reconstruct the `messages['instructor']` array (preserving system notifications, just as we did for Ops and Tech).

### Frontend Instructor/Mentor Dashboard
#### [NEW] [LearningQuestions.tsx](file:///c:/Easyplex_AI/frontend/src/pages/instructor/LearningQuestions.tsx)
- Clone the layout logic of `Inquiries.tsx` but re-theme it meticulously with the orange color palette (`text-orange-600`, `bg-orange-50`) to match the Instructor Q&A theme.
- Connect it to the new `GET` and `POST` endpoints.

#### [MODIFY] [App.tsx](file:///c:/Easyplex_AI/frontend/src/App.tsx)
- Add `<Route path="/instructor/learning-questions" />` accessible by both `['instructor', 'mentor']` roles.

#### [MODIFY] [instructor.ts](file:///c:/Easyplex_AI/frontend/src/data/instructor.ts) & [mentor.ts](file:///c:/Easyplex_AI/frontend/src/data/mentor.ts)
- Append `{ id: 'learning_questions', label: '학습 질문 게시판', icon: 'school', path: '/instructor/learning-questions' }` to the sidebar navigation menu for both roles.

## Verification Plan

### Manual Verification
1. Log in as a Student, send a categorized message via Instructor Q&A. Verify the system message bubble appears correctly.
2. Send a subsequent message without a category. Verify it appends visually and doesn't wipe history.
3. Log in as an Instructor (or Mentor). Navigate to "학습 질문 게시판".
4. Verify the UI is orange-themed and displays the student's concatenated message.
5. Submit a reply.
6. Switch back to the Student view and verify the reply bubbles seamlessly into the chat with the orange avatar.
