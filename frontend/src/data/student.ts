/* ==========================================================
 * Student PWA 목업 데이터
 * ----------------------------------------------------------
 * 학생 PWA 뷰 (Home, Classroom, Assignments, Community)
 * 및 설정/AI 도움봇에서 사용되는 더미 데이터를 정의합니다.
 * ========================================================== */

import type {
  User, CurriculumStep, RecordedLecture, Assignment,
  CommunityPost, ChatMessage, ToggleSetting, SupportManual,
  BottomNavItem, Announcement, LectureMaterial
} from '../types';

/* ── 현재 로그인 사용자 (학생) ── */
export const studentUser: User = {
  id: 'stu-001',
  name: 'Student User',
  nameKo: '학생',
  role: 'student',
  title: '',
  avatar: '',
};

/* ── 하단 네비게이션 ── */
export const studentBottomNav: BottomNavItem[] = [
  { id: 'home', label: 'Home', icon: 'home', path: '/student' },
  { id: 'classroom', label: 'Classroom', icon: 'school', path: '/student/classroom' },
  { id: 'assignments', label: 'Assignments', icon: 'assignment', path: '/student/assignments' },
  { id: 'community', label: 'Community', icon: 'forum', path: '/student/community' },
];

/* ── Home 페이지 데이터 ── */

/** 출석 통계 (5월) */
export const attendanceStats = {
  month: 'May',
  lates: 1,
  absences: 0,
  earlyLeaves: 0,
  rate: 98,
  status: 'Safe' as const,
};

/** 오늘 일정 */
export const todaySchedule = [
  { id: 'ts1', time: '14:00 ~ 16:00', title: 'FastAPI Deep Dive' },
];

/* ── Classroom 페이지 데이터 ── */

/** 커리큘럼 로드맵 */
export const curriculumRoadmap: CurriculumStep[] = [
  { id: 'cr1', title: 'Python OOP', status: 'completed', completedDate: 'Sep 15' },
  { id: 'cr2', title: 'FastAPI Deep Dive', status: 'current', progress: 65 },
  { id: 'cr3', title: 'LangGraph Agent Dev', status: 'upcoming', startsDate: 'Oct 01' },
];

/** 녹화 강의 목록 */
export const recordedLectures: RecordedLecture[] = [
  { id: 'rl1', week: 2, date: 'Sep 20', title: 'FastAPI Routing & API Versioning', duration: '45:20', watchedProgress: 72, url: 'https://youtube.com/watch?v=mock1', thumbnail: '/thumbnails/react_thumbnail.png' },
  { id: 'rl2', week: 2, date: 'Sep 19', title: 'Dependency Injection in Practice', duration: '38:15', watchedProgress: 100, url: 'https://vimeo.com/mock2', thumbnail: '/thumbnails/state_thumbnail.png' },
  { id: 'rl3', week: 2, date: 'Sep 18', title: 'Pydantic Models and Validation', duration: '51:00', watchedProgress: 100, url: 'https://youtube.com/watch?v=mock3', thumbnail: '/thumbnails/fastapi_thumbnail.png' },
  { id: 'rl4', week: 1, date: 'Sep 15', title: 'Introduction to FastAPI', duration: '42:10', watchedProgress: 100, url: 'https://youtube.com/watch?v=mock4', thumbnail: '/thumbnails/intro_thumbnail.png' },
  { id: 'rl5', week: 1, date: 'Sep 13', title: 'Setting up the Python Environment', duration: '30:45', watchedProgress: 100, url: 'https://youtube.com/watch?v=mock5', thumbnail: '/thumbnails/setup_thumbnail.png' },
];

/** 강사진 공지사항 */
export const announcements: Announcement[] = [
  { id: 'an1', title: '[Important] Midterm Exam Schedule', content: 'The midterm exam will be held on Oct 15.', date: 'Oct 01', isImportant: true },
  { id: 'an2', title: 'Welcome to FastAPI Deep Dive', content: 'Please install the required dependencies before the next class.', date: 'Sep 25' },
];

/** 강의 자료 (날짜별) */
export const lectureMaterials: LectureMaterial[] = [
  { id: 'lm1', title: 'FastAPI Routing Basics', type: 'pdf', date: 'Sep 20', size: '2.4 MB', url: '#' },
  { id: 'lm2', title: 'Dependency Injection Guide', type: 'doc', date: 'Sep 18', size: '1.1 MB', url: '#' },
];

/* ── Assignments 페이지 데이터 ── */

/** 과제 목록 */
export const assignments: Assignment[] = [
  { id: 'a1', title: 'LangGraph Multi-Agent Setup', deadline: 'May 30, 23:59', deadlineLabel: 'D-2', status: 'pending' },
];

/* ── Community 페이지 데이터 ── */

/** 커뮤니티 게시글 */
const INITIAL_COMMUNITY_POSTS: CommunityPost[] = [
  {
    id: 'cp1',
    author: 'Student User',
    timeAgo: '10 mins ago',
    tag: 'question',
    content: '안녕하세요, 도커(Docker)를 이용해 컨테이너를 띄우려고 하는데 계속 포트 충돌 에러가 발생합니다.\n\n에러 메시지는 다음과 같습니다:\nError response from daemon: driver failed programming external connectivity on endpoint: Bind for 0.0.0.0:8000 failed: port is already allocated.\n\n제가 이미 다른 프로젝트에서 8000 포트를 사용 중인 것 같은데, 어떤 프로세스가 이 포트를 점유하고 있는지 확인하거나, docker-compose 파일에서 포트를 8080 등으로 변경해서 실행하는 가장 좋은 방법이 무엇인지 궁금합니다. 조언 부탁드립니다!',
    likes: 5,
    comments: 2,
    isLiked: false,
    commentsList: [
      { id: 'c1', author: 'Anonymous Student B', timeAgo: '8 mins ago', content: 'Check if another container is using 8000.', likes: 2 },
      { id: 'c2', author: 'Anonymous Student C', timeAgo: '5 mins ago', content: 'Try docker-compose down and up again.', likes: 1 }
    ]
  },
  {
    id: 'cp2',
    author: 'Anonymous Student B',
    timeAgo: '2 hours ago',
    tag: 'freetalk',
    content: 'Looking for final project team members (RAG & FastAPI).',
    likes: 12,
    comments: 1,
    isLiked: true,
    commentsList: [
      { id: 'c3', author: 'Anonymous Student A', timeAgo: '1 hour ago', content: 'I am interested! I have experience with FastAPI.', likes: 0 }
    ]
  },
  {
    id: 'cp3',
    author: 'Anonymous Student C',
    timeAgo: '5 hours ago',
    tag: 'studygroup',
    content: 'LangChain weekend study group.',
    likes: 8,
    comments: 0,
    isLiked: false,
    commentsList: []
  },
];

export const communityPosts: CommunityPost[] = (() => {
  const saved = localStorage.getItem('communityPosts');
  if (saved) {
    try {
      return JSON.parse(saved);
    } catch (e) {
      console.error('Failed to parse communityPosts from localStorage', e);
    }
  }
  return [...INITIAL_COMMUNITY_POSTS];
})();

export const saveCommunityPosts = () => {
  localStorage.setItem('communityPosts', JSON.stringify(communityPosts));
};

/* ── Settings 데이터 ── */

/** 학생 알림 설정 */
export const notificationSettings: ToggleSetting[] = [
  { id: 'assign-deadline', label: 'Assignment Deadlines', labelKo: '과제 마감 알림', value: true },
  { id: 'attend-warning', label: 'Attendance Warnings', labelKo: '출석 경고 알림', value: true },
];

/** 학생 디스플레이 설정 */
export const displaySettings: ToggleSetting[] = [
  { id: 'quick-qr', label: 'Quick QR on Home', labelKo: '홈 화면 QR 위젯', value: true },
  { id: 'dark-mode', label: 'Dark Mode', labelKo: '다크 모드', value: false },
];

/** 관리자 보안 설정 */
export const adminSecuritySettings: ToggleSetting[] = [
  { id: 'intranet-only', label: 'Intranet-Only Communication', value: true },
  { id: 'enforce-2fa', label: 'Enforce 2FA', value: false },
];

/* ── AI Help Bot 데이터 ── */

/** AI 도움봇 채팅 이력 */
export const helpBotMessages: ChatMessage[] = [
  { id: 'hb_init', sender: 'ai', content: '안녕하세요! Easyplex AI 도움봇입니다. 무엇을 도와드릴까요? 하단의 자주 묻는 질문을 클릭하시거나 궁금한 점을 직접 입력해 주세요.' },
];

/* ── Tech Support 데이터 ── */

/** 지원 매뉴얼 카드 */
export const supportManuals: SupportManual[] = [
  { id: 'sm1', title: 'Instructor Guide', description: 'Classroom management & AI grading tools.', icon: 'school' },
  { id: 'sm2', title: 'Ops Team Manual', description: 'Scheduling, billing, and resource allocation.', icon: 'sync' },
  { id: 'sm3', title: 'Tech Support Docs', description: 'Troubleshooting and API integrations.', icon: 'terminal' },
  { id: 'sm4', title: 'Owner Handbook', description: 'High-level analytics and institution settings.', icon: 'account_balance' },
];
