# Multi-Modal Student Support Chatbot Implementation Plan

This document outlines the proposed changes to implement a multi-modal support chatbot for students, allowing them to route messages to the AI Assistant, Operations Team, Tech Team, or Instructors directly from the floating chat widget.

## Background & Goal
Currently, the chat FAB (Floating Action Button) only opens the `AIHelpBot.tsx` for general FAQ with an LLM. The goal is to expand this interface so the student can select a specific "Mode" (FAQ, EduOps, TechOps, Instructor) and have their message routed accordingly. This reduces stress on instructors and categorizes issues immediately.

## User Review Required
> [!IMPORTANT]
> - **TechOps Live Chat:** Since this is currently a mock/prototype phase, the TechOps "real-time chat" will be simulated by returning an immediate system message (e.g., "Connected to a tech agent..."), rather than setting up a full WebSocket server right now. Is this acceptable for the current prototype?
> - **UI Design:** We will place a 4-segment toggle bar right below the header in the Chat UI. Each mode will change the header's background color (e.g., AI: Green, Ops: Blue, Tech: Purple, Instructor: Orange).

## Proposed Changes

---

### Frontend

#### [MODIFY] [AIHelpBot.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/AIHelpBot.tsx)
- **State Management**: Add a `chatMode` state (`'faq' | 'ops' | 'tech' | 'instructor'`).
- **UI Menu/Toggle**: Add a horizontal scrollable tab bar or pill buttons just below the header to select the mode.
- **Dynamic Styling**: Change the header's background color and title/icon based on the selected mode:
  - `faq`: `bg-primary` (Green), Icon: `smart_toy`, Title: "AI Help Bot"
  - `ops`: `bg-blue-600`, Icon: `support_agent`, Title: "Operations Team"
  - `tech`: `bg-purple-600`, Icon: `computer`, Title: "Tech Support"
  - `instructor`: `bg-orange-500`, Icon: `school`, Title: "Instructor Q&A"
- **Message Handling**: Update the `handleSend` function to send the message payload along with the active `chatMode` to the new backend endpoint `POST /api/v1/student/support/message`.
- **System Responses**: Render simulated responses from the backend (e.g., "Ticket created for Ops").

---

### Backend

#### [NEW] [support.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/student/support.py)
- Create a new router for student support.
- Implement `POST /message` endpoint.
- **Logic**:
  - `faq`: Return a simulated AI response.
  - `ops`: Log a ticket creation and return a confirmation message to the student.
  - `tech`: Simulate a live chat connection and return an auto-reply.
  - `instructor`: Log a post creation for the instructor dashboard and return a confirmation.

#### [MODIFY] [main.py](file:///c:/Easyplex_AI/backend/app/main.py)
- Import the new `support.py` router.
- Register it via `api_router.include_router(student_support.router, prefix="/student/support", tags=["Student Support"])`.

## Verification Plan

### Automated Tests
- N/A (UI and routing simulation)

### Manual Verification
1. Click the floating chat button on the student page.
2. Verify the 4 mode tabs are visible.
3. Switch between modes and verify the header color, icon, and title change.
4. Send a message in "Ops" mode and verify the backend logs ticket creation and returns a specific confirmation.
5. Send a message in "Tech" mode and verify the "real-time chat" auto-reply is received.
