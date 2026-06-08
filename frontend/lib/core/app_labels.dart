/// Single source of truth for UI labels. The nav (`side_nav.dart`) is driven
/// entirely by these, and any screen whose in-page heading duplicates a nav
/// label references the SAME constant — so a rename happens in exactly one
/// place here.
class AppLabels {
  AppLabels._();

  // ── Role home / dashboards ────────────────────────────────────────────
  static const dashboard = '대시보드';
  static const opsStatus = '운영 현황';
  static const infra = '인프라';
  static const execDashboard = '경영 대시보드';

  // ── Community / boards ────────────────────────────────────────────────
  static const notices = '공지사항';
  static const community = '커뮤니티';
  static const communityManagement = '커뮤니티 관리';

  // ── Attendance ────────────────────────────────────────────────────────
  static const attendance = '출결';
  static const attendanceManagement = '출결 관리';

  // ── Assignments ───────────────────────────────────────────────────────
  static const assignments = '과제';
  static const assignmentGrading = '과제 채점';

  // ── Leave ─────────────────────────────────────────────────────────────
  static const leaveRequests = '조퇴/병결';
  static const leaveApproval = '조퇴/병결 승인';

  // ── Classes / counseling / evaluation ────────────────────────────────
  static const classManagement = '수업 관리';
  static const counseling = '상담';
  static const courseEvaluation = '강의평가';

  // ── Courses (period-style 수업 + 영상) ────────────────────────────────
  /// New course/video feature ("수업 관리"). The instructor nav points its
  /// primary "수업 관리" entry at the new course list.
  static const courses = '수업 관리';

  /// Legacy class entry (curriculum / career / training-log / evaluation), kept
  /// as a separate nav item so [ClassListScreen] is not orphaned.
  static const curriculumLog = '커리큘럼·일지';

  /// Student-facing course/video entry ("수업" tab → `/student/courses`).
  static const studentCourses = '수업';

  // ── Chat / support / inquiries ────────────────────────────────────────
  static const chat = '채팅';
  static const support = '지원 · 문의';
  static const myInquiries = '내 문의';
  static const inquiries = '문의/티켓';
  static const ticket = '티켓';

  // ── Admin / ops ───────────────────────────────────────────────────────
  static const userManagement = '사용자';
  static const cohortManagement = '기수 관리';
  static const licenses = '라이선스';
  static const aiCopilot = 'AI 코파일럿';

  // ── Executive analytics ───────────────────────────────────────────────
  static const kpiRoi = 'KPI/ROI';
  static const governance = '거버넌스';
  static const analytics = '분석';
}
