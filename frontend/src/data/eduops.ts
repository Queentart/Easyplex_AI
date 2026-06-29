/* ==========================================================
 * EduOps 운영 대시보드 목업 데이터
 * ----------------------------------------------------------
 * EduOps 운영 뷰 (Student Mgmt, Data Sync, AI Automation, Settings)
 * 에서 사용되는 더미 데이터를 정의합니다.
 * ========================================================== */

import type {
  User, Student, CounselingLog, AttendanceRecord,
  FlaggedQuery, GeneratedReport, ToggleSetting, MenuItem
} from '../types';

/* ── 현재 로그인 사용자 (운영팀) ── */
export const opsUser: User = {
  id: 'ops-001',
  name: 'Lee Ju-yeong',
  nameKo: '이주영',
  role: 'ops',
  title: 'AI Developer',
  avatar: '',
};

/* ── EduOps 사이드바 메뉴 ── */
export const opsMenu: MenuItem[] = [
  { id: 'dashboard', label: '대시보드', icon: 'dashboard', path: '/eduops' },
  { id: 'students', label: '학생 관리', icon: 'people', path: '/eduops/students' },
  { id: 'inquiries', label: '문의사항', icon: 'support_agent', path: '/eduops/inquiries' },
  { id: 'announcements', label: '공지사항', icon: 'campaign', path: '/eduops/announcements' },
  { id: 'instructor-logs', label: '강의 자료 및 일지', icon: 'library_books', path: '/eduops/instructor-logs' },
  { id: 'sync', label: '데이터 동기화', icon: 'sync', path: '/eduops/sync' },
  { id: 'ai', label: 'AI 자동화', icon: 'smart_toy', path: '/eduops/ai' },
  { id: 'streams', label: '실시간 강의 링크', icon: 'ondemand_video', path: '/eduops/streams' },
  { id: 'curriculum', label: '학습 커리큘럼 로드맵', icon: 'route', path: '/eduops/curriculum' },
  { id: 'settings', label: '운영팀 설정', icon: 'settings', path: '/eduops/settings' },
];

/* ── StudentMgmt 학생 목록 ── */
export const students: Student[] = [
  { id: 'st1', studentId: '24-001', name: 'Kim Ji-woo', nameKo: '김지우', cohort: 'Spring 2024', attendanceRate: 98, recentCounseling: 'Oct 12, 2023', status: 'active' },
  { id: 'st2', studentId: '24-042', name: 'Park Min-ho', nameKo: '박민호', cohort: 'Spring 2024', attendanceRate: 75, recentCounseling: 'Oct 20, 2023', status: 'warning' },
  { id: 'st3', studentId: '23-118', name: 'Choi Ha-eun', nameKo: '최하은', cohort: 'Fall 2023', attendanceRate: 92, recentCounseling: 'Nov 02, 2023', status: 'active' },
];

/** 학생 관리 통계 */
export const studentStats = {
  totalActive: 145,
  attendanceWarning: 4,
};

/** 최근 상담 로그 */
export const counselingLogs: CounselingLog[] = [
  { studentName: 'Choi Ha-eun', date: 'Nov 02', type: 'Check-in', summary: 'Discussed career path adjustments...' },
  { studentName: 'Park Min-ho', date: 'Oct 20', type: 'Intervention', summary: 'Attendance warning / Intervention meeting...' },
  { studentName: 'Kim Ji-woo', date: 'Oct 12', type: 'Routine', summary: 'Routine check-in...' },
];

/* ── Dashboard 대시보드 추가 데이터 ── */
export const pendingInquiries = [
  { id: 'inq1', title: '출석 인정 서류 제출 기한 문의', student: '박민호', date: 'Today, 10:30 AM', status: 'pending' },
  { id: 'inq2', title: '강의 교재 관련 질문', student: '최하은', date: 'Yesterday', status: 'pending' },
];

export const recentAnnouncements = [
  { id: 'ann1', title: '[필독] 6월 교육 지원금 지급 안내', date: 'Jun 28, 2026', important: true },
  { id: 'ann2', title: '이번 주 금요일 실시간 특강 접속 링크', date: 'Jun 27, 2026', important: false },
];

/* ── DataSync 데이터 ── */

/** 동기화 상태 */
export const syncStatus = {
  lastSynced: 'Today, 09:30 AM',
  dataMismatches: 3,
};

/** 출석 교차 검증 데이터 */
export const attendanceRecords: AttendanceRecord[] = [
  { studentName: '김민수', date: '2026-05-28', goyong24Record: '08:55 AM', zoomLog: '08:54 AM', status: 'matched' },
  { studentName: '이지은', date: '2026-05-28', goyong24Record: '09:00 AM', zoomLog: '09:15 AM', status: 'mismatch' },
  { studentName: '박준영', date: '2026-05-28', goyong24Record: '08:50 AM', zoomLog: '08:48 AM', status: 'matched' },
];

/* ── AIAutomation 데이터 ── */

/** 최근 플래그된 쿼리 (24h) */
export const flaggedQueries: FlaggedQuery[] = [
  { id: 'fq1', query: '외출 몇 시간까지 가능한가요?', confidence: 42, issue: 'Missing specific dormitory policy context.' },
  { id: 'fq2', query: '체크는 언제해요?', confidence: 38, issue: 'Vague Intent (Attendance vs. Health check).' },
  { id: 'fq3', query: '서류 제출 기한 연장 되나요?', confidence: 55, issue: 'Requires admin override approval flow.' },
];

/** 최근 생성된 보고서 */
export const generatedReports: GeneratedReport[] = [
  { id: 'gr1', filename: 'CS_Fall2024_Kim_Minsu_Profile.pdf', generatedAt: 'Oct 24, 09:41 AM', status: 'ready' },
  { id: 'gr2', filename: 'CS_Fall2024_Park_Jiyeon_Profile.pdf', generatedAt: 'Oct 24, 09:40 AM', status: 'ready' },
  { id: 'gr3', filename: 'CS_Fall2024_Batch_Generation (24 items)...', generatedAt: 'Oct 24, 09:45 AM', status: 'processing', progress: 45 },
];

/** 대상 그룹 (경고 발송) */
export const warningTargetGroup = 'Students with >3 Unexcused Absences (14 identified)';

/** 메시지 템플릿 */
export const messageTemplate = 'Dear {Student_Name}, this is an official notification regarding your recent academic standing...';

/* ── OpsSettings 데이터 ── */

/** API & 데이터 통합 설정 */
export const apiSettings: ToggleSetting[] = [
  { id: 'auto-sync', label: 'Auto-sync with Goyong 24 Portal', value: true },
];

export const apiInputSettings = [
  { id: 'sync-freq', label: 'Sync Frequency', type: 'select' as const, value: 'Hourly', options: ['Every 15 min', 'Every 30 min', 'Hourly', 'Daily'] },
  { id: 'zoom-key', label: 'Zoom API Access Key', type: 'password' as const, value: '••••••••••••' },
];

/** AI 챗봇 설정 */
export const chatbotSettings: ToggleSetting[] = [
  { id: 'auto-reply', label: 'Auto-reply for Admin FAQs', value: true },
];

export const chatbotInputSettings = [
  { id: 'confidence', label: 'AI Confidence Threshold', type: 'select' as const, value: 'High 90%+', options: ['Low 50%+', 'Medium 75%+', 'High 90%+'] },
  { id: 'fallback-email', label: 'Fallback Email', type: 'text' as const, value: 'support@eduops.ai' },
];

/** 모니터링 & 알림 설정 */
export const monitoringSettings: ToggleSetting[] = [
  { id: 'push-notif', label: 'Push Notifications', value: true },
];

export const monitoringInputSettings = [
  { id: 'distraction', label: 'Distraction Alert Threshold (딴짓 감지)', type: 'number' as const, value: '5', unit: 'mins' },
  { id: 'attendance-warning', label: 'Attendance Warning Trigger', type: 'select' as const, value: 'Notify after 3 tardies', options: ['Notify after 2 tardies', 'Notify after 3 tardies', 'Notify after 5 tardies'] },
];
