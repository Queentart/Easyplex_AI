/* ==========================================================
 * StudentSettings 페이지 (학생 설정)
 * ----------------------------------------------------------
 * (목업 화면 #16) 프로필, 알림 설정, 앱 설정, 지원
 * ========================================================== */

import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import MobileLayout from '../../components/layout/MobileLayout';
import Toggle from '../../components/common/Toggle';
import { studentBottomNav } from '../../data/student';
import { useAuth } from '../../contexts/AuthContext';
import './Student.css';

export default function StudentSettings() {
  const navigate = useNavigate();
  const { logout } = useAuth();

  // 프로필 정보 (Mock)
  const profileInfo = {
    name: '김이지',
    email: 'easy.kim@example.com',
    cohort: 'AI 1기',
    profileImg: 'https://api.dicebear.com/7.x/avataaars/svg?seed=이지'
  };

  // 알림 설정 상태
  const [notifPreferences, setNotifPreferences] = useState({
    academic: true, // 출석/과제 경고 등
    learning: true, // 새 공지, 자료 업로드 등
    community: false, // Q&A 답변 등
    marketing: false // 이벤트 및 혜택 알림
  });

  // 앱 환경 설정 상태
  const [appPreferences, setAppPreferences] = useState({
    darkMode: false,
    startPageHome: true // true: Home, false: Classroom
  });

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  return (
    <MobileLayout title="Settings" bottomNavItems={studentBottomNav} showFAB={false}>
      <div className="settings-page">
        {/* ── 프로필 섹션 ── */}
        <div className="mobile-card profile-card">
          <div className="profile-card__header">
            <img src={profileInfo.profileImg} alt="Profile" className="profile-card__avatar" />
            <div className="profile-card__info">
              <h2 className="profile-card__name">{profileInfo.name}</h2>
              <p className="profile-card__cohort">{profileInfo.cohort} 수강생</p>
              <p className="profile-card__email">{profileInfo.email}</p>
            </div>
            <button className="btn btn-outline btn-sm">수정</button>
          </div>
        </div>

        {/* ── 알림 설정 ── */}
        <div className="settings-group">
          <div className="settings-group__title">알림 설정</div>
          <div className="mobile-card">
            <Toggle
              label="출석 및 학사 경고 알림"
              checked={notifPreferences.academic}
              onChange={(c) => setNotifPreferences({ ...notifPreferences, academic: c })}
            />
            <Toggle
              label="공지사항 및 학습 자료 알림"
              checked={notifPreferences.learning}
              onChange={(c) => setNotifPreferences({ ...notifPreferences, learning: c })}
            />
            <Toggle
              label="커뮤니티 (Q&A) 활동 알림"
              checked={notifPreferences.community}
              onChange={(c) => setNotifPreferences({ ...notifPreferences, community: c })}
            />
          </div>
        </div>

        {/* ── 디스플레이 및 앱 설정 ── */}
        <div className="settings-group">
          <div className="settings-group__title">앱 환경 설정</div>
          <div className="mobile-card">
            <Toggle
              label="다크 모드 (Dark Mode)"
              checked={appPreferences.darkMode}
              onChange={(c) => setAppPreferences({ ...appPreferences, darkMode: c })}
            />
            <Toggle
              label="시작 화면을 'Home'으로 설정"
              checked={appPreferences.startPageHome}
              onChange={(c) => setAppPreferences({ ...appPreferences, startPageHome: c })}
            />
          </div>
        </div>

        {/* ── 고객지원 및 기타 ── */}
        <div className="settings-group">
          <div className="settings-group__title">지원 및 기타</div>
          <div className="mobile-card support-menu">
            <button className="support-menu__item">
              <span className="material-icons-outlined">support_agent</span>
              <span>1:1 운영팀 문의</span>
              <span className="material-icons-outlined arrow">chevron_right</span>
            </button>
            <button className="support-menu__item">
              <span className="material-icons-outlined">description</span>
              <span>이용약관 및 정책</span>
              <span className="material-icons-outlined arrow">chevron_right</span>
            </button>
            <button className="support-menu__item">
              <span className="material-icons-outlined">info</span>
              <span>버전 정보 (v1.0.0)</span>
            </button>
          </div>
        </div>

        {/* ── 로그아웃 버튼 ── */}
        <button className="btn btn-outline" style={{ width: '100%', marginTop: 'var(--space-2)' }} onClick={handleLogout}>
          <span className="material-icons-outlined" style={{ fontSize: 18 }}>logout</span>
          로그아웃
        </button>
      </div>
    </MobileLayout>
  );
}
