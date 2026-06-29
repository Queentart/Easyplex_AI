# Ops Team Inquiry Workflow Implementation Plan

This document outlines the architecture and file modifications required to implement the "Operations Team Chat to Inquiry Board" feature.

## Goal
1. When a student sends a message via the `Operations Team` channel in the chat modal, it creates a ticket on the Ops Team's dashboard.
2. Ops team members can access the "Inquiries (문의사항)" page from their left sidebar to view and reply to these tickets.
3. Once the Ops team replies, the student will see the reply or a notification within their chat modal.

## Proposed Changes

### Backend (Database & API)
We need a new table to store tickets and endpoints to manage them.

#### [MODIFY] [backend/app/models/ops.py](file:///c:/Easyplex_AI/backend/app/models/ops.py)
- Create an `OpsTicket` SQLAlchemy model (`id`, `student_name`, `message`, `status`, `reply`, `created_at`, `replied_at`).

#### [MODIFY] [backend/app/db/base.py](file:///c:/Easyplex_AI/backend/app/db/base.py)
- Import `OpsTicket` to register it with Alembic.

#### [MODIFY] [backend/app/api/v1/endpoints/student/support.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/student/support.py)
- Update `handle_support_message` so that if `mode == "ops"`, it creates a new `OpsTicket` in the database.
- Add a new endpoint `GET /api/v1/student/support/tickets` so the student's chat modal can fetch ticket statuses and display ops replies.

#### [NEW] [backend/app/api/v1/endpoints/ops/inquiries.py](file:///c:/Easyplex_AI/backend/app/api/v1/endpoints/ops/inquiries.py)
- Add `GET /api/v1/ops/inquiries`: Fetch all Ops tickets for the admin dashboard.
- Add `POST /api/v1/ops/inquiries/{ticket_id}/reply`: Allow Ops team to leave a reply and change the ticket status to 'Answered'.

#### [MODIFY] [backend/app/main.py](file:///c:/Easyplex_AI/backend/app/main.py)
- Register the new `ops/inquiries` router.

---

### Frontend (UI & Routing)
We need a new dashboard page for the Ops team and updates to the student's chat modal.

#### [MODIFY] [frontend/src/types/index.ts](file:///c:/Easyplex_AI/frontend/src/types/index.ts)
- Add `OpsTicket` interface.

#### [MODIFY] [frontend/src/data/eduops.ts](file:///c:/Easyplex_AI/frontend/src/data/eduops.ts)
- Add a new menu item for "문의사항 (Inquiries)" targeting `/eduops/inquiries`.

#### [MODIFY] [frontend/src/App.tsx](file:///c:/Easyplex_AI/frontend/src/App.tsx)
- Register the `<Route path="/eduops/inquiries" element={<Inquiries />} />` route.

#### [NEW] [frontend/src/pages/eduops/Inquiries.tsx](file:///c:/Easyplex_AI/frontend/src/pages/eduops/Inquiries.tsx)
- Build the "문의사항" dashboard where Ops staff can view a list of student tickets and submit replies via a modal or inline form.

#### [MODIFY] [frontend/src/pages/student/AIHelpBot.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/AIHelpBot.tsx)
- Fetch the student's previous `ops` tickets on mount.
- Display the Ops team's replies as system messages or stylized chat bubbles within the `ops` channel stream.

## User Review Required
> [!IMPORTANT]
> To link the student to the ticket, we normally need the student's ID from the JWT token. Currently, the chat modal doesn't strictly send JWT auth headers. For this MVP, I will pass a dummy student name (or "Current Student") along with the message to the backend. Is this acceptable, or do you have an existing user auth state in the frontend you'd prefer me to use?

> [!TIP]
> After I write these codes, you will need to run the `alembic` migrations again to create the `ops_tickets` table in the database.

Please review the file list and plan above. Reply with your approval or any modifications, and I will proceed sequentially!
