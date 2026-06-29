# Real-time Tech Support Chat Implementation

This plan outlines the steps to implement a real-time (polled) chat system between the Student's Tech Support modal and the TechOps "Students Mgmt" dashboard.

## User Review Required

> [!IMPORTANT]
> - Since WebSockets are not currently used in the student support system (it relies on polling), this plan uses **short polling** (every few seconds) to achieve "real-time" chat. This keeps the architecture simple and consistent with the existing `OpsTicket` implementation. Let me know if you strongly prefer WebSocket implementation instead.
> - A new database table structure will be introduced to handle chat threads (`TechTicket` and `TechMessage`) because the existing `OpsTicket` only supports a single `message` and `reply`.

## Proposed Changes

---

### Backend Data Models

#### [NEW] `c:\Easyplex_AI\backend\app\models\tech_support_chat.py`
Create two new SQLAlchemy models:
- `TechTicket`: Tracks the student's tech support session (id, student_name, priority, status).
- `TechMessage`: Tracks individual messages within the ticket (id, ticket_id, sender_type ['student', 'admin'], message, created_at).

#### [MODIFY] `c:\Easyplex_AI\backend\app\db\base.py`
Import the new `TechTicket` and `TechMessage` models so that Alembic can track them for database migrations.

---

### Backend API Endpoints

#### [MODIFY] `c:\Easyplex_AI\backend\app\api\v1\endpoints\student\support.py`
- Update the `POST /message` endpoint under `mode == "tech"` to create a `TechTicket` (if an active one doesn't exist for the student) and append the message as a `TechMessage`.
- Add a new `GET /tech-messages?student_name=...` endpoint for the student UI to poll their tech chat history.

#### [MODIFY] `c:\Easyplex_AI\backend\app\api\v1\endpoints\tech_support\student_mgmt.py`
- Add `GET /tickets` to fetch all open/active tech tickets.
- Add `GET /tickets/{ticket_id}/messages` to fetch the chat history of a specific ticket.
- Add `POST /tickets/{ticket_id}/messages` to allow the TechOps admin to send a reply back to the student.

---

### Frontend (Student Side)

#### [MODIFY] `c:\Easyplex_AI\frontend\src\pages\student\AIHelpBot.tsx`
- Add a new `useEffect` hook to poll `/api/v1/student/support/tech-messages` every 3-5 seconds when the `isOpen` is true.
- Synchronize the fetched messages into the `messages['tech']` state, allowing the student to see real-time replies from the TechOps admin.

---

### Frontend (Admin Side)

#### [MODIFY] `c:\Easyplex_AI\frontend\src\pages\techops\StudentsMgmt.tsx`
- Remove the hardcoded `techStudentTickets` mockup data.
- Fetch live tickets from `/api/v1/tech_support/student_mgmt/tickets`.
- Add an interactive Chat Modal (popup) that opens when the admin clicks on a ticket row.
- Inside the Chat Modal:
  - Display the history of `TechMessage`s for that ticket.
  - Implement a polling mechanism to fetch new messages from the student in real-time.
  - Add a text input and send button to call the admin reply API.

## Verification Plan

### Manual Verification
1. Open the Student Dashboard, click the chat widget, go to **Tech Support**, and send a message (e.g., "My screen is frozen").
2. Open the TechOps Center in a separate window/tab and navigate to **Students Mgmt**.
3. Verify that the new ticket appears in the list.
4. Click the ticket to open the Tech Chat Popup.
5. Send a reply as the Admin (e.g., "Please try clearing your browser cache").
6. Verify that the reply instantly appears in the Student's Tech Support chat window.
