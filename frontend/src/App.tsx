/* ==========================================================
 * App.tsx - 메인 라우터 설정
 * ----------------------------------------------------------
 * 앱의 모든 라우트를 정의합니다.
 *
 * [라우트 구조]
 * /                        → Welcome (웰컴 게이트웨이 랜딩)
 * /login/student            → StudentLogin (수강생 PWA 로그인)
 * /login/admin              → AdminLogin (관리자 로그인)
 *
 * /executive               → OwnerCommandCenter (Owner 총괄 현황판)
 * /executive/eduops         → EduOpsCommandCenter (교육 운영 커맨드센터)
 * /executive/academic       → AcademicOversight (학사 전략 감독)
 * /executive/techops        → TechOpsSummary (기술 운영 요약)
 * /executive/reports        → StrategicReports (전략 리포트)
 *
 * /instructor               → InstructorDashboard (강사 AI 통합 대시보드)
 * /instructor/assignments    → AssignmentsGrading (과제 및 AI 채점)
 * /instructor/counseling     → CounselingMentoring (상담 & AI 멘토링)
 *
 * /eduops                   → StudentMgmt (운영 학생관리)
 * /eduops/sync              → DataSync
 * /eduops/ai                → AIAutomation
 * /eduops/settings          → OpsSettings
 *
 * /student                  → Home (학생 PWA 홈)
 * /student/classroom        → Classroom
 * /student/assignments      → Assignments
 * /student/community        → Community
 * /student/settings         → StudentSettings
 * /student/helpbot          → AIHelpBot
 *
 * /settings                 → AdminSettings
 * /support                  → TechSupport
 * ========================================================== */

import { useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';

/* ── Auth 페이지 (Welcome / Login) ── */
import Welcome from './pages/auth/Welcome';
import StudentLogin from './pages/auth/StudentLogin';
import AdminLogin from './pages/auth/AdminLogin';

/* ── Executive 페이지 (5개) ── */
import OwnerCommandCenter from './pages/executive/OwnerCommandCenter';
import EduOpsCommandCenter from './pages/executive/EduOpsCommandCenter';
import AcademicOversight from './pages/executive/AcademicOversight';
import TechOpsSummary from './pages/executive/TechOpsSummary';
import StrategicReports from './pages/executive/StrategicReports';
import ExecutiveClassStreams from './pages/executive/ClassStreams';

/* ── Instructor 페이지 ── */
import InstructorDashboard from './pages/instructor/InstructorDashboard';
import AssignmentsGrading from './pages/instructor/AssignmentsGrading';
import CounselingMentoring from './pages/instructor/CounselingMentoring';
import CourseMaterials from './pages/instructor/CourseMaterials';
import TrainingLogs from './pages/instructor/TrainingLogs';
import MentoringLogs from './pages/instructor/MentoringLogs';
import InstructorClassStreams from './pages/instructor/ClassStreams';
import LearningQuestions from './pages/instructor/LearningQuestions';
import InstructorCurriculum from './pages/instructor/InstructorCurriculum';

/* ── TechOps 기술팀 대시보드 ── */
import TechTeamMgmt from './pages/techops/TechTeamMgmt';
import EquipmentMgmt from './pages/techops/EquipmentMgmt';
import StudentsMgmt from './pages/techops/StudentsMgmt';
import DailyOps from './pages/techops/DailyOps';
import StreamMgmt from './pages/techops/StreamMgmt';

/* ── EduOps 페이지 ── */
import EduOpsDashboard from './pages/eduops/EduOpsDashboard';
import StudentMgmt from './pages/eduops/StudentMgmt';
import DataSync from './pages/eduops/DataSync';
import AIAutomation from './pages/eduops/AIAutomation';
import OpsSettings from './pages/eduops/OpsSettings';
import InstructorLogs from './pages/eduops/InstructorLogs';
import EduOpsClassStreams from './pages/eduops/ClassStreams';
import Inquiries from './pages/eduops/Inquiries';
import Announcements from './pages/eduops/Announcements';
import EduOpsCurriculum from './pages/eduops/EduOpsCurriculum';

/* ── Student PWA 페이지 ── */
import Home from './pages/student/Home';
import Classroom from './pages/student/Classroom';
import Assignments from './pages/student/Assignments';
import Community from './pages/student/Community';
import PostDetail from './pages/student/PostDetail';
import StudentSettings from './pages/student/StudentSettings';
import AIHelpBot from './pages/student/AIHelpBot';

/* ── Settings 페이지 ── */
import AdminSettings from './pages/settings/AdminSettings';
import TechSupport from './pages/settings/TechSupport';

/* ── 공유 페이지 ── */
import MyPage from './pages/shared/MyPage';

/* ── 공통 / 컴포넌트 ── */
import ProtectedRoute from './components/common/ProtectedRoute';
import { NotificationProvider } from './contexts/NotificationContext';

/**
 * App 컴포넌트
 * 
 * 전체 앱의 라우팅을 관리하는 루트 컴포넌트입니다.
 * BrowserRouter를 사용하여 클라이언트 사이드 라우팅을 구현합니다.
 */
function App() {
  useEffect(() => {
    const savedDarkMode = localStorage.getItem('darkMode') === 'true';
    if (savedDarkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, []);

  return (
    <NotificationProvider>
      <BrowserRouter>
        <Routes>
        {/* ── 루트: Welcome 게이트웨이 ── */}
        <Route path="/" element={<Welcome />} />
        <Route path="/login/student" element={<StudentLogin />} />
        <Route path="/login/admin" element={<AdminLogin />} />

        {/* ── Executive 대시보드 (5개 페이지) ── */}
        <Route path="/executive" element={<ProtectedRoute allowedRoles={['owner']}><OwnerCommandCenter /></ProtectedRoute>} />
        <Route path="/executive/eduops" element={<ProtectedRoute allowedRoles={['owner']}><EduOpsCommandCenter /></ProtectedRoute>} />
        <Route path="/executive/academic" element={<ProtectedRoute allowedRoles={['owner']}><AcademicOversight /></ProtectedRoute>} />
        <Route path="/executive/techops" element={<ProtectedRoute allowedRoles={['owner']}><TechOpsSummary /></ProtectedRoute>} />
        <Route path="/executive/reports" element={<ProtectedRoute allowedRoles={['owner']}><StrategicReports /></ProtectedRoute>} />
        <Route path="/executive/streams" element={<ProtectedRoute allowedRoles={['owner']}><ExecutiveClassStreams /></ProtectedRoute>} />

        {/* ── Instructor 강사 대시보드 라우트 ── */}
        <Route path="/instructor" element={<ProtectedRoute allowedRoles={['instructor', 'tutor']}><InstructorDashboard /></ProtectedRoute>} />
        <Route path="/instructor/assignments" element={<ProtectedRoute allowedRoles={['instructor', 'tutor']}><AssignmentsGrading /></ProtectedRoute>} />
        <Route path="/instructor/counseling" element={<ProtectedRoute allowedRoles={['instructor', 'tutor']}><CounselingMentoring /></ProtectedRoute>} />
        <Route path="/instructor/materials" element={<ProtectedRoute allowedRoles={['instructor', 'tutor']}><CourseMaterials /></ProtectedRoute>} />
        <Route path="/instructor/training-logs" element={<ProtectedRoute allowedRoles={['instructor']}><TrainingLogs /></ProtectedRoute>} />
        <Route path="/instructor/mentoring-logs" element={<ProtectedRoute allowedRoles={['tutor']}><MentoringLogs /></ProtectedRoute>} />
        <Route path="/instructor/streams" element={<ProtectedRoute allowedRoles={['instructor', 'tutor']}><InstructorClassStreams /></ProtectedRoute>} />
        <Route path="/instructor/learning-questions" element={<ProtectedRoute allowedRoles={['instructor', 'tutor']}><LearningQuestions /></ProtectedRoute>} />
        <Route path="/instructor/curriculum" element={<ProtectedRoute allowedRoles={['instructor', 'tutor']}><InstructorCurriculum /></ProtectedRoute>} />

        {/* ── EduOps 운영 대시보드 ── */}
        <Route path="/eduops" element={<ProtectedRoute allowedRoles={['ops']}><EduOpsDashboard /></ProtectedRoute>} />
        <Route path="/eduops/students" element={<ProtectedRoute allowedRoles={['ops']}><StudentMgmt /></ProtectedRoute>} />
        <Route path="/eduops/inquiries" element={<ProtectedRoute allowedRoles={['ops']}><Inquiries /></ProtectedRoute>} />
        <Route path="/eduops/announcements" element={<ProtectedRoute allowedRoles={['ops']}><Announcements /></ProtectedRoute>} />
        <Route path="/eduops/instructor-logs" element={<ProtectedRoute allowedRoles={['ops']}><InstructorLogs /></ProtectedRoute>} />
        <Route path="/eduops/sync" element={<ProtectedRoute allowedRoles={['ops']}><DataSync /></ProtectedRoute>} />
        <Route path="/eduops/ai" element={<ProtectedRoute allowedRoles={['ops']}><AIAutomation /></ProtectedRoute>} />
        <Route path="/eduops/streams" element={<ProtectedRoute allowedRoles={['ops']}><EduOpsClassStreams /></ProtectedRoute>} />
        <Route path="/eduops/settings" element={<ProtectedRoute allowedRoles={['ops']}><OpsSettings /></ProtectedRoute>} />
        <Route path="/eduops/curriculum" element={<ProtectedRoute allowedRoles={['ops']}><EduOpsCurriculum /></ProtectedRoute>} />

        {/* ── TechOps 기술팀 대시보드 ── */}
        <Route path="/techops" element={<ProtectedRoute allowedRoles={['admin']}><TechTeamMgmt /></ProtectedRoute>} />
        <Route path="/techops/equipment" element={<ProtectedRoute allowedRoles={['admin']}><EquipmentMgmt /></ProtectedRoute>} />
        <Route path="/techops/students" element={<ProtectedRoute allowedRoles={['admin']}><StudentsMgmt /></ProtectedRoute>} />
        <Route path="/techops/daily" element={<ProtectedRoute allowedRoles={['admin']}><DailyOps /></ProtectedRoute>} />
        <Route path="/techops/streams" element={<ProtectedRoute allowedRoles={['admin']}><StreamMgmt /></ProtectedRoute>} />

        {/* ── Student PWA ── */}
        <Route path="/student" element={<ProtectedRoute allowedRoles={['student']}><Home /></ProtectedRoute>} />
        <Route path="/student/classroom" element={<ProtectedRoute allowedRoles={['student']}><Classroom /></ProtectedRoute>} />
        <Route path="/student/assignments" element={<ProtectedRoute allowedRoles={['student']}><Assignments /></ProtectedRoute>} />
        <Route path="/student/community" element={<ProtectedRoute allowedRoles={['student']}><Community /></ProtectedRoute>} />
        <Route path="/student/community/:postId" element={<ProtectedRoute allowedRoles={['student']}><PostDetail /></ProtectedRoute>} />
        <Route path="/student/settings" element={<ProtectedRoute allowedRoles={['student']}><StudentSettings /></ProtectedRoute>} />
        <Route path="/student/helpbot" element={<ProtectedRoute allowedRoles={['student']}><AIHelpBot isOpen={true} onClose={() => {}} /></ProtectedRoute>} />

        {/* ── 관리자 설정 ── */}
        <Route path="/settings" element={<ProtectedRoute><AdminSettings /></ProtectedRoute>} />
        <Route path="/support" element={<ProtectedRoute><TechSupport /></ProtectedRoute>} />
        
        {/* ── 마이 페이지 (전체 공통) ── */}
        <Route path="/mypage" element={<ProtectedRoute><MyPage /></ProtectedRoute>} />

        {/* ── 404 폴백: Welcome으로 리다이렉트 ── */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
    </NotificationProvider>
  );
}

export default App;
