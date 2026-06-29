/* ==========================================================
 * StudentLogin 페이지 (Student PWA Login Portal)
 * ----------------------------------------------------------
 * 수강생 로그인 페이지 (PWA 앱에서도 사용).
 *
 * [화면 구성]
 * - 상단 네비게이션 (뒤로가기 포함)
 * - 글래스모픽 로그인 카드
 *   · 학번(Student ID) 입력
 *   · 비밀번호 입력
 *   · 로그인 유지 체크박스 + 비밀번호 찾기
 *   · 로그인 버튼
 *   · 소셜 로그인 구분선
 * - 푸터
 * ========================================================== */

import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { useAuth } from '../../hooks/useAuth';
import { apiClient } from '../../api/client';
import './Auth.css';

/**
 * StudentLogin 페이지
 *
 * 수강생이 학번과 비밀번호로 로그인하는 PWA 지원 포털입니다.
 */
export default function StudentLogin() {
  const navigate = useNavigate();
  const [studentId, setStudentId] = useState('');
  const [password, setPassword] = useState('');

  const { login } = useAuth();
  const [errorMsg, setErrorMsg] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  /**
   * 로그인 폼 제출 핸들러
   * 실제 백엔드 /auth/login 호출
   */
  const handleSubmit = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();
    setErrorMsg('');
    setIsSubmitting(true);
    
    try {
      const formData = new URLSearchParams();
      // 학생의 경우 백엔드에서 studentId를 username으로 처리하도록 수정됨
      formData.append('username', studentId);
      formData.append('password', password);

      const response = await apiClient.post('/auth/login', formData, {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      });

      const { access_token, user_info } = response.data;
      login(access_token, user_info);
      navigate('/student');

    } catch (err: unknown) {
      console.error('Login failed:', err);
      if (axios.isAxiosError(err) && err.response?.status === 401) {
        setErrorMsg('학번 또는 비밀번호가 올바르지 않습니다.');
      } else {
        setErrorMsg('서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="auth-page auth-page--student">
      {/* ── 상단 네비게이션 ── */}
      <nav className="auth-nav">
        <div className="auth-nav__brand">
          <div className="auth-nav__logo">E</div>
          <div>
            <div className="auth-nav__title">EasyPlex AI</div>
            <div className="auth-nav__subtitle">Student Portal</div>
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
          <div className="login-card__icon login-card__icon--teal">
            <span className="material-icons-outlined">school</span>
          </div>

          <h1 className="login-card__title">Student Login</h1>
          <p className="login-card__subtitle">수강생 포털에 로그인하세요</p>

          {errorMsg && (
            <div style={{ color: '#ef4444', backgroundColor: 'rgba(239, 68, 68, 0.1)', padding: '0.75rem', borderRadius: '0.5rem', marginBottom: '1rem', fontSize: '0.875rem' }}>
              {errorMsg}
            </div>
          )}

          <form className="auth-form" onSubmit={handleSubmit}>
            <div className="auth-field">
              <label className="auth-field__label" htmlFor="student-id">Student ID</label>
              <input
                id="student-id"
                className="auth-field__input"
                type="text"
                placeholder="학번을 입력하세요 (예: 24-001)"
                value={studentId}
                onChange={(e) => setStudentId(e.target.value)}
                autoComplete="username"
              />
            </div>

            <div className="auth-field">
              <label className="auth-field__label" htmlFor="student-pw">Password</label>
              <input
                id="student-pw"
                className="auth-field__input"
                type="password"
                placeholder="비밀번호를 입력하세요"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
              />
            </div>

            <div className="auth-form__options">
              <label className="auth-form__remember">
                <input type="checkbox" />
                로그인 상태 유지
              </label>
              <span className="auth-form__forgot">비밀번호 찾기</span>
            </div>

            <button type="submit" className="auth-submit auth-submit--teal" disabled={isSubmitting}>
              <span className="material-icons-outlined">
                {isSubmitting ? 'hourglass_empty' : 'login'}
              </span>
              {isSubmitting ? '로그인 중...' : '로그인'}
            </button>
          </form>

          <div className="auth-divider" style={{ marginTop: 'var(--space-6)' }}>또는</div>

          <button
            className="auth-submit auth-submit--teal"
            style={{ marginTop: 'var(--space-4)', background: 'rgba(255,255,255,0.06)', boxShadow: 'none', border: '1px solid rgba(255,255,255,0.12)' }}
            onClick={() => console.log('Google SSO')}
          >
            <span className="material-icons-outlined">g_mobiledata</span>
            Google 계정으로 로그인
          </button>
        </div>
      </div>

      {/* ── 푸터 ── */}
      <footer className="auth-footer">
        <p className="auth-footer__text">
          © 2026 EasyPlex AI · 최초 로그인 시 교육기관 제공 학번과 초기 비밀번호를 사용하세요
        </p>
      </footer>
    </div>
  );
}
