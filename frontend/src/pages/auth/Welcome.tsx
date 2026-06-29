/* ==========================================================
 * Welcome 페이지 (Unified Welcome & Gateway Landing Page)
 * ----------------------------------------------------------
 * 앱 최초 접속 시 표시되는 메인 웰컴/게이트웨이 랜딩 페이지.
 *
 * [화면 구성]
 * - 상단 네비게이션 (로고 + 링크)
 * - 센터 히어로 블록 (타이틀 + 설명 + CTA 버튼 2개)
 * - 하단 특성 태그 (AI, 실시간, 다국어 등)
 * - 푸터
 *
 * [CTA 버튼]
 * - 수강생 로그인 → /login/student
 * - 관리자 로그인 → /login/admin
 * ========================================================== */

import { useNavigate } from 'react-router-dom';
import './Auth.css';

/**
 * Welcome 게이트웨이 랜딩 페이지
 *
 * 수강생과 관리자 로그인 포털로 분기하는 시작점입니다.
 */
export default function Welcome() {
  const navigate = useNavigate();

  return (
    <div className="auth-page auth-page--welcome">
      {/* ── 상단 네비게이션 ── */}
      <nav className="auth-nav">
        <div className="auth-nav__brand">
          <div className="auth-nav__logo">E</div>
          <div>
            <div className="auth-nav__title">EasyPlex AI</div>
            <div className="auth-nav__subtitle">Intelligent Education Platform</div>
          </div>
        </div>
        <div className="auth-nav__links">
          <span className="auth-nav__link">About</span>
          <span className="auth-nav__link">Contact</span>
          <span className="auth-nav__link">Documentation</span>
        </div>
      </nav>

      {/* ── 히어로 센터 블록 ── */}
      <div className="auth-content">
        <div className="welcome-center">
          <div className="welcome-center__badge">
            <span className="material-icons-outlined" style={{ fontSize: '16px' }}>auto_awesome</span>
            AI-Powered Education Platform
          </div>

          <h1 className="welcome-center__title">
            Welcome to<br />
            <span>EasyPlex AI</span>
          </h1>

          <p className="welcome-center__desc">
            차세대 AI 기반 교육 관리 플랫폼으로 학습 경험을 혁신합니다.
            실시간 출결 관리, AI 채점, 커리큘럼 최적화를 경험하세요.
          </p>

          {/* ── CTA 버튼 ── */}
          <div className="auth-cta-group">
            <button
              className="auth-cta auth-cta--primary"
              onClick={() => navigate('/login/student')}
            >
              <span className="material-icons-outlined">school</span>
              수강생 로그인
            </button>
            <button
              className="auth-cta auth-cta--secondary"
              onClick={() => navigate('/login/admin')}
            >
              <span className="material-icons-outlined">admin_panel_settings</span>
              관리자 로그인
            </button>
          </div>

          {/* ── 하단 특성 태그 ── */}
          <div className="welcome-features">
            <div className="welcome-feature">
              <span className="material-icons-outlined welcome-feature__icon">psychology</span>
              AI-Powered Analytics
            </div>
            <div className="welcome-feature">
              <span className="material-icons-outlined welcome-feature__icon">sync</span>
              Real-time Sync
            </div>
            <div className="welcome-feature">
              <span className="material-icons-outlined welcome-feature__icon">security</span>
              Enterprise Security
            </div>
            <div className="welcome-feature">
              <span className="material-icons-outlined welcome-feature__icon">language</span>
              Multi-language
            </div>
          </div>
        </div>
      </div>

      {/* ── 푸터 ── */}
      <footer className="auth-footer">
        <p className="auth-footer__text">
          © 2026 EasyPlex AI · Powered by LangGraph Agent Architecture ·{' '}
          <span className="auth-footer__link">Privacy Policy</span> ·{' '}
          <span className="auth-footer__link">Terms of Service</span>
        </p>
      </footer>
    </div>
  );
}
