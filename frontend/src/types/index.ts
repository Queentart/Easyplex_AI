/* ==========================================================
 * 공통 TypeScript 타입 정의
 * ----------------------------------------------------------
 * 앱 전체에서 사용되는 데이터 모델 인터페이스를 정의합니다.
 * ========================================================== */

/* ── 사용자 관련 타입 ── */

/** 사용자 역할 구분 */
export type UserRole = 'owner' | 'admin' | 'instructor' | 'tutor' | 'ops' | 'eduops' | 'tech' | 'techops' | 'student';

/** 공통 사용자 프로필 인터페이스 */
export interface User {
  id: string;
  name: string;
  nameKo?: string;        // 한국어 이름
  role: UserRole;
  title?: string;          // 직함 (e.g., "Senior Faculty", "AI Developer")
  avatar?: string;         // 프로필 이미지 URL
  email?: string;
}

/* ── 사이드바/네비게이션 타입 ── */

/** 사이드바 메뉴 아이템 */
export interface MenuItem {
  id: string;
  label: string;
  icon: string;            // Material Icon 이름
  path: string;            // 라우터 경로
  badge?: string | number; // 알림 뱃지 텍스트
  children?: MenuItem[];   // 하위 메뉴
  allowedRoles?: UserRole[]; // 역할 기반 메뉴 필터링
}

/** 하단 네비게이션 탭 */
export interface BottomNavItem {
  id: string;
  label: string;
  icon: string;
  path: string;
}

/* ── 학생 관련 타입 ── */

/** 학생 상태 */
export type StudentStatus = 'active' | 'warning' | 'inactive' | 'completed';

/** 학생 프로필 */
export interface Student {
  id: string;
  studentId: string;       // 학번 (e.g., "24-001")
  name: string;
  nameKo: string;
  cohort: string;          // 소속 코호트 (e.g., "Spring 2024")
  attendanceRate: number;  // 출석률 (%)
  recentCounseling?: string; // 최근 상담 날짜
  status: StudentStatus;
  lastLogin?: string;
  riskLevel?: 'high' | 'medium' | 'low';
  riskReason?: string;
}

/** 출석 기록 */
export interface AttendanceRecord {
  studentName: string;
  date: string;
  goyong24Record: string;  // 고용24 기록 시간
  zoomLog: string;         // Zoom 기록 시간
  status: 'matched' | 'mismatch';
}

/** 상담 로그 */
export interface CounselingLog {
  studentName: string;
  date: string;
  type: string;            // 상담 유형 (e.g., "Check-in", "Intervention")
  summary: string;
}

/* ── 코호트/배치 관련 타입 ── */

/** 코호트(배치) 정보 */
export interface Cohort {
  id: string;
  name: string;
  placementRate: number;
  studentCount?: number;
}

/* ── 과제 관련 타입 ── */

/** 과제 상태 */
export type AssignmentStatus = 'pending' | 'submitted' | 'graded' | 'missing';

/** 과제 */
export interface Assignment {
  id: string;
  title: string;
  deadline: string;
  deadlineLabel?: string;  // "D-2" 등
  status: AssignmentStatus;
}

/* ── 채팅 관련 타입 ── */

/** 채팅 메시지 발신자 */
export type MessageSender = 'user' | 'ai' | 'student' | 'system' | 'ops' | 'tech' | 'instructor';

/** 채팅 메시지 */
export interface ChatMessage {
  id: string;
  sender: MessageSender;
  content: string;
  timestamp?: string;
  /** AI 응답에 포함될 수 있는 테이블 데이터 */
  tableData?: {
    headers: string[];
    rows: string[][];
  };
  /** 빠른 액션 버튼 목록 */
  actions?: ChatAction[];
}

/** 채팅 빠른 액션 */
export interface ChatAction {
  label: string;
  variant: 'primary' | 'outline';
  onClick?: () => void;
}

/** 사내 인트라넷 메시지 */
export interface IntranetMessage {
  id: number;
  sender_id: number;
  sender_name: string;
  receiver_role: UserRole;
  content: string;
  cohort_name?: string;
  created_at: string;
}


/* ── 대시보드/KPI 관련 타입 ── */

/** KPI 카드 데이터 */
export interface KPICard {
  id: string;
  title: string;
  value: string;
  subtitle: string;
  trend?: 'up' | 'down' | 'neutral';
  trendValue?: string;
}

/** 테넌트 정보 */
export interface Tenant {
  id: string;
  name: string;
  licenseType: string;
  activeUsers: number;
  renewalDate: string;
  status: 'active' | 'inactive';
}

/** 보안 감사 로그 */
export interface AuditLog {
  id: string;
  message: string;
  icon: string;
  iconColor: string;
  time: string;
}

/** 비용 카드 */
export interface CostCard {
  title: string;
  value: string;
  change?: string;
  changeType?: 'increase' | 'decrease';
  progress?: number;
  progressLabel?: string;
}

/* ── 커리큘럼 관련 타입 ── */

/** 커리큘럼 단계 */
export interface CurriculumStep {
  id: string;
  title: string;
  status: 'completed' | 'current' | 'upcoming';
  completedDate?: string;
  progress?: number;       // 진행률 (%)
  startsDate?: string;
}

/** 녹화 강의 */
export interface RecordedLecture {
  id: string;
  date: string;
  title: string;
  duration: string;
  watchedProgress?: number;
  url?: string;
  youtubeUrl?: string;
  vimeoUrl?: string;
  thumbnail?: string;
  week?: number;
}

/** 강사진 공지사항 */
export interface Announcement {
  id: string;
  title: string;
  content: string;
  date: string;
  isImportant?: boolean;
}

/** 강의 자료 */
export interface LectureMaterial {
  id: string;
  title: string;
  type: 'pdf' | 'doc' | 'video' | 'link';
  date: string;
  size?: string;
  url: string;
}

/* ── 커뮤니티 관련 타입 ── */

/** 게시글 태그 유형 */
export type PostTag = 'question' | 'freetalk' | 'studygroup' | 'notice';

/** 커뮤니티 댓글 */
export interface CommunityComment {
  id: string;
  author: string;
  timeAgo: string;
  content: string;
  likes: number;
  isLiked?: boolean;
}

/** 커뮤니티 게시글 */
export interface CommunityPost {
  id: string;
  author: string;
  timeAgo: string;
  tag: PostTag;
  content: string;
  likes: number;
  comments: number;
  isLiked?: boolean;
  commentsList?: CommunityComment[];
  attachments?: { name: string; url: string; type: string; size: number }[];
}

/* ── FAQ/Knowledge Base 타입 ── */

/** FAQ 쿼리 플래그 */
export interface FlaggedQuery {
  id: string;
  query: string;
  confidence: number;
  issue: string;
}

/** 생성된 보고서 */
export interface GeneratedReport {
  id: string;
  filename: string;
  generatedAt: string;
  status: 'ready' | 'processing';
  progress?: number;
}

/* ── 설정 관련 타입 ── */

/** 토글 설정 항목 */
export interface ToggleSetting {
  id: string;
  label: string;
  labelKo?: string;
  value: boolean;
}

/* ── 기술 지원 관련 타입 ── */

/** 지원 매뉴얼 카드 */
export interface SupportManual {
  id: string;
  title: string;
  description: string;
  icon: string;
}

export interface IssueFormData {
  submitter: string;
  category: string;
  urgency: string;
  description: string;
}

/** 운영팀 문의(티켓) 내역 */
export interface OpsTicket {
  id: number;
  student_name: string;
  message: string;
  status: 'pending' | 'answered' | 'closed';
  reply: string | null;
  created_at: string;
  replied_at: string | null;
}

/* ── 차트 데이터 타입 ── */

/** 바 차트 데이터 포인트 */
export interface BarChartData {
  label: string;
  values: { label: string; value: number; color: string }[];
}

/** 도넛 차트 데이터 */
export interface DonutChartData {
  value: number;
  max: number;
  label: string;
  color: string;
}
