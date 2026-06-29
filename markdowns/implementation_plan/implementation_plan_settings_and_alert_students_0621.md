# Student Notifications & Settings Implementation Plan

This plan details the UI and functional updates for the Student PWA's Notification and Settings pages based on our discussion.

## Proposed Changes

### 1. Notifications Page (`StudentNotifications.tsx`)
We will create a new page dedicated to displaying notifications. 

#### [MODIFY] [App.tsx](file:///c:/Easyplex_AI/frontend/src/App.tsx)
- Add a new route: `<Route path="/student/notifications" element={<ProtectedRoute allowedRoles={['student']}><StudentNotifications /></ProtectedRoute>} />`

#### [MODIFY] [Header.tsx](file:///c:/Easyplex_AI/frontend/src/components/common/Header.tsx)
- Expose `onNotificationClick?: () => void` in `HeaderProps`.
- Bind `onClick={onNotificationClick}` to the notification bell button.

#### [MODIFY] [MobileLayout.tsx](file:///c:/Easyplex_AI/frontend/src/components/layout/MobileLayout.tsx)
- Pass an `onNotificationClick` handler to the `Header` component.
- The handler will navigate the user to `/student/notifications`.

#### [NEW] [StudentNotifications.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/StudentNotifications.tsx)
- Implement a full-page mobile UI using `MobileLayout`.
- Render a list of notifications using mock data categorized by type:
  - **Academic Alert**: Attendance warnings, Assignment deadlines.
  - **Learning Updates**: Announcements, Materials.
  - **Community**: Q&A replies.
- Include a "Mark all as read" button.

### 2. Settings Page Update (`StudentSettings.tsx`)
We will revamp the existing settings page to be more comprehensive and aligned with the discussed features.

#### [MODIFY] [StudentSettings.tsx](file:///c:/Easyplex_AI/frontend/src/pages/student/StudentSettings.tsx)
- **Profile Section**: Display user's avatar, name, cohort (e.g., 1기), and email.
- **Notification Preferences**: Expand toggles for specific notification types (e.g., "출석/학사 알림", "새 공지사항 알림", "커뮤니티 알림").
- **App Preferences**: Add a dark mode toggle (mock functionality for now) and a default startup page selector (Home vs Classroom).
- **Support Section**: Add buttons for "1:1 운영팀 문의" and "이용약관 및 개인정보처리방침".

#### [MODIFY] [Student.css](file:///c:/Easyplex_AI/frontend/src/pages/student/Student.css)
- Add styles for the notification cards (unread indicators, category icons).
- Enhance the settings group styling to accommodate the new profile and support sections.

## Verification Plan
1. Click the bell icon in the top header and verify it navigates to the new `/student/notifications` page.
2. Verify that different types of notifications are styled correctly.
3. Navigate to the Settings tab and verify that the Profile, Preferences, and Support sections are displayed correctly.
4. Verify that toggles can be interacted with.

> [!IMPORTANT]
> The data used for both notifications and settings will be **mocked (dummy data)** on the frontend for this UI implementation phase. Real backend integration (e.g., saving user preferences or receiving real-time notifications via WebSockets) will need to be implemented later. Please approve this plan if you are ready to proceed with the UI development!
