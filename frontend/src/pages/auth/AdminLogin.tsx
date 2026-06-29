/* ==========================================================
 * AdminLogin 페이지 (Admin Executive Login Portal)
 * ----------------------------------------------------------
 * 관리자(강사, 운영팀, 기술팀, 오너/원장) 로그인 페이지.
 *
 * [화면 구성]
 * - 상단 네비게이션 (뒤로가기 포함)
 * - 글래스모픽 로그인 카드
 *   · 역할 선택 (4가지: Instructor, EduOps, TechOps, Owner)
 *   · 이메일 입력
 *   · 비밀번호 입력
 *   · 로그인 유지 + 비밀번호 찾기
 *   · 로그인 버튼
 * - 푸터
 * ========================================================== */

import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { useAuth } from '../../hooks/useAuth';
import { apiClient } from '../../api/client';
import './Auth.css';

/** 관리자 역할 목록 */
const ADMIN_ROLES = [
  { id: 'instructor', label: 'Instructor', icon: 'person', path: '/instructor' },
  { id: 'eduops', label: 'EduOps', icon: 'school', path: '/eduops' },
  { id: 'techops', label: 'TechOps', icon: 'memory', path: '/techops' },
  { id: 'owner', label: 'Owner', icon: 'shield', path: '/executive' },
] as const;

type AdminRoleId = typeof ADMIN_ROLES[number]['id'];

/**
 * AdminLogin 페이지
 *
 * 관리자가 역할을 선택하고 이메일/비밀번호로 로그인하는 웹 뷰 포털입니다.
 */
export default function AdminLogin() {
  const navigate = useNavigate();
  const [selectedRole, setSelectedRole] = useState<AdminRoleId>('instructor');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const { login } = useAuth();
  const [errorMsg, setErrorMsg] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  /**
   * 로그인 폼 제출 핸들러
   * 실제 백엔드 /auth/login 엔드포인트를 호출합니다.
   */
  const handleSubmit = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();
    setErrorMsg('');
    setIsSubmitting(true);
    
    try {
      const formData = new URLSearchParams();
      formData.append('username', email); // OAuth2PasswordRequestForm expects 'username'
      formData.append('password', password);
      // 백엔드 구현에 맞추어 grant_type 등 추가될 수 있으나 기본 설정으로 진행

      const response = await apiClient.post('/auth/login', formData, {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      });

      const { access_token, user_info } = response.data;
      
      // AuthContext 상태 업데이트 (여기서 localStorage에도 저장됨)
      login(access_token, user_info);

      const rolePathMap: Record<string, string> = {
        'owner': '/executive',
        'instructor': '/instructor',
        'tutor': '/instructor',
        'ops': '/eduops',
        'admin': '/techops',
      };
      
      const destPath = rolePathMap[user_info.role] || '/';
      navigate(destPath);

    } catch (err: unknown) {
      console.error('Login failed:', err);
      if (axios.isAxiosError(err) && err.response?.status === 401) {
        setErrorMsg('이메일 또는 비밀번호가 올바르지 않습니다.');
      } else {
        setErrorMsg('서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="auth-page auth-page--admin">
      {/* ── 상단 네비게이션 ── */}
      <nav className="auth-nav">
        <div className="auth-nav__brand">
          <div className="auth-nav__logo" style={{ background: 'linear-gradient(135deg, var(--color-indigo), #818CF8)' }}>E</div>
          <div>
            <div className="auth-nav__title">EasyPlex AI</div>
            <div className="auth-nav__subtitle">Admin Portal</div>
          </div>
        </div>
        <div className="auth-nav__links">
          <span className="auth-nav__link" onClick={() => navigate('/')}>
            <span className="material-icons-outlined" style={{ fontSize: '18px', verticalAlign: 'middle' }}>arrow_back</span>
            {' '}Back to Home
          </span>
        </div>
      </nav>

      {/* ── 로그인 카드 ── */}
      <div className="auth-content">
        <div className="login-card">
          <div className="login-card__icon login-card__icon--indigo">
            <span className="material-icons-outlined">admin_panel_settings</span>
          </div>

          <h1 className="login-card__title">Admin Login</h1>
          <p className="login-card__subtitle">관리자 포털에 로그인하세요</p>

          {errorMsg && (
            <div style={{ color: '#ef4444', backgroundColor: 'rgba(239, 68, 68, 0.1)', padding: '0.75rem', borderRadius: '0.5rem', marginBottom: '1rem', fontSize: '0.875rem' }}>
              {errorMsg}
            </div>
          )}

          <form className="auth-form" onSubmit={handleSubmit}>
            {/* ── 역할 선택 ── */}
            <div className="auth-field">
              <label className="auth-field__label">Select Role</label>
              <div className="role-selector">
                {ADMIN_ROLES.map(role => (
                  <button
                    key={role.id}
                    type="button"
                    className={`role-option ${selectedRole === role.id ? 'role-option--active' : ''}`}
                    onClick={() => setSelectedRole(role.id)}
                  >
                    <span className="material-icons-outlined role-option__icon">{role.icon}</span>
                    {role.label}
                  </button>
                ))}
              </div>
            </div>

            {/* ── 이메일 ── */}
            <div className="auth-field">
              <label className="auth-field__label" htmlFor="admin-email">Email</label>
              <input
                id="admin-email"
                className="auth-field__input auth-field__input--admin"
                type="email"
                placeholder="admin@easyplex.ai"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="username"
              />
            </div>

            {/* ── 비밀번호 ── */}
            <div className="auth-field">
              <label className="auth-field__label" htmlFor="admin-pw">Password</label>
              <input
                id="admin-pw"
                className="auth-field__input auth-field__input--admin"
                type="password"
                placeholder="비밀번호를 입력하세요"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
              />
            </div>

            {/* ── 옵션 행 ── */}
            <div className="auth-form__options">
              <label className="auth-form__remember">
                <input type="checkbox" />
                로그인 상태 유지
              </label>
              <span className="auth-form__forgot auth-form__forgot--indigo">비밀번호 찾기</span>
            </div>

            {/* ── 로그인 버튼 ── */}
            <button type="submit" className="auth-submit auth-submit--indigo" disabled={isSubmitting}>
              <span className="material-icons-outlined">
                {isSubmitting ? 'hourglass_empty' : 'login'}
              </span>
              {isSubmitting ? '로그인 중...' : '관리자 로그인'}
            </button>
          </form>

          <div className="auth-divider" style={{ marginTop: 'var(--space-6)' }}>또는</div>

          <button
            className="auth-submit auth-submit--indigo"
            style={{ marginTop: 'var(--space-4)', background: 'rgba(255,255,255,0.06)', boxShadow: 'none', border: '1px solid rgba(255,255,255,0.12)' }}
            onClick={() => console.log('SSO')}
          >
            <span className="material-icons-outlined">vpn_key</span>
            SSO 통합 로그인
          </button>
        </div>
      </div>

      {/* ── 푸터 ── */}
      <footer className="auth-footer">
        <p className="auth-footer__text">
          © 2026 EasyPlex AI · 관리자 계정은 시스템 관리자에게 문의하세요 ·{' '}
          <span className="auth-footer__link">보안 정책</span>
        </p>
      </footer>
    </div>
  );
}
