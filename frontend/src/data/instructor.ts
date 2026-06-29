/* ==========================================================
 * Instructor 강사 대시보드 목업 데이터
 * ----------------------------------------------------------
 * 강사용 5개 대시보드에서 사용되는 목업 데이터를 정의합니다.
 * ========================================================== */

import type { MenuItem, User } from '../types';

/* ── 현재 로그인 사용자 (강사) ── */
export const instructorUser: User = {
  id: 'inst-001',
  name: 'Dr. Aris Thorne',
  role: 'instructor',
  title: 'Senior Faculty',
  avatar: '',
};

/* ── 좌측 사이드바 메뉴 (5개 페이지 매핑) ── */
export const instructorMenuItems: MenuItem[] = [
  { id: 'dashboard', label: 'AI Dashboard', icon: 'dashboard', path: '/instructor' },
  { id: 'materials', label: '강의 자료 관리', icon: 'library_books', path: '/instructor/materials' },
  { id: 'assignments', label: '과제', icon: 'assignment', path: '/instructor/assignments' },
  { id: 'counseling', label: '학생 상담', icon: 'psychology', path: '/instructor/counseling' },
  { id: 'training_logs', label: '학습 일지', icon: 'menu_book', path: '/instructor/training-logs', allowedRoles: ['instructor'] },
  { id: 'mentoring_logs', label: '멘토링 일지', icon: 'import_contacts', path: '/instructor/mentoring-logs', allowedRoles: ['tutor'] },
  { id: 'learning_questions', label: '학습 질문 게시판', icon: 'question_answer', path: '/instructor/learning-questions', allowedRoles: ['instructor', 'tutor'] },
  { id: 'streams', label: '실시간 스트리밍', icon: 'ondemand_video', path: '/instructor/streams', allowedRoles: ['instructor', 'tutor'] },
  { id: 'curriculum', label: '학습 커리큘럼 로드맵', icon: 'route', path: '/instructor/curriculum', allowedRoles: ['instructor', 'tutor'] },
];

/* ── 1. Instructor Dashboard 데이터 ── */
export const dashboardStats = {
  totalStudents: 145,
  avgAttendance: 94.2,
  assignmentsToGrade: 28,
  counselingPending: 5,
};

export const recentAlerts = [
  { id: 'a1', title: 'Low Attendance Alert', desc: '3 students dropped below 80% this week.', type: 'warning', date: '2 hours ago' },
  { id: 'a2', title: 'AI Grading Completed', desc: 'LangGraph Assignment #3 graded.', type: 'success', date: '5 hours ago' },
  { id: 'a3', title: 'Counseling Requested', desc: 'Min-woo Park requested a session.', type: 'info', date: '1 day ago' },
];

/* ── 2. Attendance & Student Monitoring 데이터 ── */
export const attendanceList = [
  { id: 's1', name: 'Kim Ji-soo', status: 'Present', rate: 98, lastLogin: '10 mins ago' },
  { id: 's2', name: 'Park Min-woo', status: 'Absent', rate: 75, lastLogin: '2 days ago' },
  { id: 's3', name: 'Lee Seo-yeon', status: 'Late', rate: 88, lastLogin: '5 hours ago' },
  { id: 's4', name: 'Choi Ha-eun', status: 'Present', rate: 95, lastLogin: 'Just now' },
];

/* ── 3. Assignments & Grading 데이터 ── */
export const assignmentTasks = [
  { id: 't1', title: 'LangGraph Project', submitted: 42, total: 45, aiGraded: 40, deadline: 'Today' },
  { id: 't2', title: 'React Basics Quiz', submitted: 45, total: 45, aiGraded: 45, deadline: '2 days ago' },
  { id: 't3', title: 'Final Architecture Design', submitted: 10, total: 45, aiGraded: 0, deadline: 'Next Week' },
];

export const gradingQueue = [
  { id: 'g1', student: 'Park Min-woo', score: 85, aiConfidence: 'High', status: 'Needs Review' },
  { id: 'g2', student: 'Kim Ji-soo', score: 98, aiConfidence: 'High', status: 'Auto-Approved' },
  { id: 'g3', student: 'Lee Seo-yeon', score: 65, aiConfidence: 'Low', status: 'Manual Grade Required' },
];

/* ── 4. Counseling & AI Mentoring 데이터 ── */
export const counselingList = [
  { id: 'c1', name: 'Park Min-woo', issue: 'Falling grades in backend dev', aiSuggestion: 'Recommend 1:1 tutoring session & extension', urgency: 'High' },
  { id: 'c2', name: 'Lee Seo-yeon', issue: 'Missed 3 consecutive classes', aiSuggestion: 'Send automated check-in email', urgency: 'Medium' },
];

/* ── 5. AI Analytics & Reports 데이터 ── */
export const performanceData = [
  { label: 'Week 1', score: 82 },
  { label: 'Week 2', score: 85 },
  { label: 'Week 3', score: 84 },
  { label: 'Week 4', score: 88 },
  { label: 'Week 5', score: 92 },
];

/* ── 6. Dashboard Additional Data ── */
export const pendingQuestions = [
  { id: 'q1', student: 'Kim Ji-soo', title: 'LangGraph State 에러 해결 방법 문의', time: '10 mins ago', urgent: true },
  { id: 'q2', student: 'Lee Seo-yeon', title: 'React useEffect 의존성 배열 질문', time: '1 hour ago', urgent: false },
  { id: 'q3', student: 'Park Min-woo', title: '비동기 처리(Async/Await) 관련', time: '2 hours ago', urgent: false },
];

export const recentMaterials = [
  { id: 'm1', title: 'Week 6: Advanced RAG Architecture', type: 'PDF', uploaded: 'Today' },
  { id: 'm2', title: 'React Hooks Deep Dive', type: 'Video', uploaded: 'Yesterday' },
];

export const recentLogs = [
  { id: 'l1', author: 'Dr. Aris (Instructor)', title: 'Week 5 Session 2 강의 일지', status: 'Submitted', time: 'Today 10:00 AM' },
  { id: 'l2', author: 'Kim Tutor', title: 'Week 5 멘토링 세션 일지 (특이사항 있음)', status: 'Review Needed', time: 'Yesterday' },
];

/* ── 7. Tutor Specific Data ── */
export const tutorMentoringSessions = [
  { id: 'ms1', student: 'Park Min-woo', time: 'Today, 14:00', topic: 'Backend Dev Catch-up', status: 'Upcoming' },
  { id: 'ms2', student: 'Lee Seo-yeon', time: 'Tomorrow, 11:00', topic: 'Attendance & Routine Check', status: 'Scheduled' },
];

export const tutorPendingLogs = [
  { id: 'pl1', title: 'Mentoring Log for Park Min-woo', dueDate: 'Today, 18:00', urgent: true },
  { id: 'pl2', title: 'Weekly Summary Log', dueDate: 'Friday, 18:00', urgent: false },
];
