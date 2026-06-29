# Login Implementation & User Seeding Plan

This plan details how to implement the initial login functionality for all roles (Students, Instructors, Operations, TechOps, Owner) by bridging the frontend UI with the backend authentication system.

## User Review Required
- **Seed Data Credentials**: We will create 5 default accounts with standard passwords (e.g., `password123`). Please confirm if you want specific passwords or if default ones are acceptable for development.
- **Student Login Identifier**: The backend requires an `email` for login, but the Student Login UI asks for a `Student ID` (e.g., `24-001`). We plan to automatically append `@student.easyplex.ai` to the input in the frontend before sending it to the backend. Is this acceptable?

## Open Questions
- Is there any additional user data (like specific names or departments) you want pre-populated in the seeder, or are generic names (e.g., "Tech Admin") sufficient for now?

## Proposed Changes

---

### Backend: Database Seeding & Auth API

#### [NEW] [seed_users.py](file:///C:/Easyplex_AI/backend/scripts/seed_users.py)
Create a script to populate the `users` table with default accounts for each role (`STUDENT`, `INSTRUCTOR`, `EDUOPS`, `TECHOPS`, `OWNER`). It will use `app.core.security.get_password_hash` to securely store passwords.

#### [MODIFY] [auth.py](file:///C:/Easyplex_AI/backend/app/api/v1/endpoints/auth.py)
Map the backend's uppercase enum roles (`TECHOPS`, `EDUOPS`, etc.) to the lowercase string roles expected by the frontend's TypeScript definition (`admin`, `ops`, `owner`, `instructor`, `student`). This ensures `user_info.role` returned in the JWT response is correctly understood by the frontend router.

---

### Frontend: Login Pages & Routing

#### [MODIFY] [StudentLogin.tsx](file:///C:/Easyplex_AI/frontend/src/pages/auth/StudentLogin.tsx)
Format the entered `studentId` into an email address (e.g., `24-001@student.easyplex.ai`) before submitting to the backend, to align with the backend's email-based authentication.

#### [MODIFY] [ProtectedRoute.tsx](file:///C:/Easyplex_AI/frontend/src/components/common/ProtectedRoute.tsx)
Fix the redirect logic for unauthenticated users. It currently redirects to `/login` (which does not exist). It will be updated to redirect to the Welcome page (`/`).

---

## Verification Plan

### Automated Tests
- Run `seed_users.py` successfully without database errors.

### Manual Verification
- Start both backend (`uvicorn app.main:app`) and frontend (`npm run dev`).
- Open the Admin Login page and log in as `owner@easyplex.ai`, verifying it routes to `/executive`.
- Log in as `techops@easyplex.ai`, verifying it routes to `/techops`.
- Open the Student Login page and log in with `24-001`, verifying it routes to `/student`.
