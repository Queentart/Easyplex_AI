import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import Toggle from './Toggle';
import Modal from './Modal';
import { useAuth } from '../../contexts/AuthContext';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function SettingsModal({ isOpen, onClose }: SettingsModalProps) {
  const navigate = useNavigate();
  const { user, logout } = useAuth();

  const [notifPreferences, setNotifPreferences] = useState({
    chatSound: true,
    academic: true,
  });

  const [appPreferences, setAppPreferences] = useState({
    darkMode: localStorage.getItem('darkMode') === 'true',
  });

  const [isPolicyModalOpen, setIsPolicyModalOpen] = useState(false);
  const [isPasswordModalOpen, setIsPasswordModalOpen] = useState(false);
  const [isContactModalOpen, setIsContactModalOpen] = useState(false);

  // 비밀번호 폼 상태
  const [pwdForm, setPwdForm] = useState({ current: '', newPwd: '', confirm: '' });
  const [pwdError, setPwdError] = useState('');
  const [pwdSuccess, setPwdSuccess] = useState(false);
  const [isPwdSubmitting, setIsPwdSubmitting] = useState(false);

  // 연락처 폼 상태
  const [contactForm, setContactForm] = useState({ email: user?.email || '', phone: '010-0000-0000' });
  const [contactSuccess, setContactSuccess] = useState(false);
  const [isContactSubmitting, setIsContactSubmitting] = useState(false);

  const handlePasswordSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setPwdError('');
    if (pwdForm.newPwd !== pwdForm.confirm) {
      setPwdError('새 비밀번호가 일치하지 않습니다.');
      return;
    }
    if (pwdForm.newPwd.length < 6) {
      setPwdError('새 비밀번호는 6자리 이상이어야 합니다.');
      return;
    }
    
    setIsPwdSubmitting(true);
    // TODO: 백엔드 API 호출로 대체
    setTimeout(() => {
      setIsPwdSubmitting(false);
      setPwdSuccess(true);
      setTimeout(() => {
        setIsPasswordModalOpen(false);
        setPwdSuccess(false);
        setPwdForm({ current: '', newPwd: '', confirm: '' });
      }, 1500);
    }, 1000);
  };

  const handleContactSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setIsContactSubmitting(true);
    // TODO: 백엔드 API 호출로 대체
    setTimeout(() => {
      setIsContactSubmitting(false);
      setContactSuccess(true);
      setTimeout(() => {
        setIsContactModalOpen(false);
        setContactSuccess(false);
      }, 1500);
    }, 1000);
  };

  const handleDarkModeToggle = (checked: boolean) => {
    setAppPreferences({ ...appPreferences, darkMode: checked });
    if (checked) {
      document.documentElement.classList.add('dark');
      localStorage.setItem('darkMode', 'true');
    } else {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('darkMode', 'false');
    }
  };

  if (!isOpen) return null;

  const handleLogout = () => {
    logout();
    navigate('/');
    onClose();
  };

  const handleOverlayClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  const displayName = user?.name || user?.nameKo || '사용자';
  const displayRole = user?.role ? user.role.toUpperCase() : '사용자';
  const displayEmail = user?.email || 'email@example.com';
  // Use user.avatar if available, otherwise dicebear
  const avatarUrl = user?.avatar || `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(displayName)}`;

  return (
    <>
      <div className="settings-modal-overlay" onClick={handleOverlayClick}>
        <div className="settings-modal-content">
        <div className="settings-modal-header">
          <h2>설정</h2>
          <button className="settings-modal-close" onClick={onClose}>
            <span className="material-icons-outlined">close</span>
          </button>
        </div>

        <div className="settings-modal-body">
          {/* 프로필 요약 */}
          <div className="mobile-card profile-card" style={{ marginBottom: '16px' }}>
            <div className="profile-card__header">
              <img src={avatarUrl} alt="Profile" className="profile-card__avatar" />
              <div className="profile-card__info">
                <h2 className="profile-card__name">{displayName}</h2>
                <p className="profile-card__cohort">{user?.title || displayRole}</p>
                <p className="profile-card__email">{displayEmail}</p>
              </div>
            </div>
            <div style={{ display: 'flex', gap: '8px', marginTop: '12px' }}>
              <button className="btn btn-outline btn-sm" style={{ flex: 1 }} onClick={() => setIsPasswordModalOpen(true)}>비밀번호 변경</button>
              <button className="btn btn-outline btn-sm" style={{ flex: 1 }} onClick={() => setIsContactModalOpen(true)}>연락처 수정</button>
            </div>
          </div>

          {/* 알림 설정 */}
          <div className="settings-group">
            <div className="settings-group__title">알림 설정</div>
            <div className="mobile-card">
              <Toggle
                label="채팅 알림음 (Sound)"
                checked={notifPreferences.chatSound}
                onChange={(c) => setNotifPreferences({ ...notifPreferences, chatSound: c })}
              />
              <Toggle
                label="주요 활동 푸시 알림"
                checked={notifPreferences.academic}
                onChange={(c) => setNotifPreferences({ ...notifPreferences, academic: c })}
              />
            </div>
          </div>

          {/* 환경 설정 */}
          <div className="settings-group">
            <div className="settings-group__title">환경 설정</div>
            <div className="mobile-card">
              <Toggle
                label="다크 모드 (Dark Mode)"
                checked={appPreferences.darkMode}
                onChange={handleDarkModeToggle}
              />
            </div>
          </div>

          {/* 기타 */}
          <div className="settings-group">
            <div className="settings-group__title">지원 및 시스템</div>
            <div className="mobile-card support-menu">
              <button className="support-menu__item" onClick={() => setIsPolicyModalOpen(true)}>
                <span className="material-icons-outlined">description</span>
                <span>이용약관 및 정책</span>
                <span className="material-icons-outlined arrow">chevron_right</span>
              </button>
            </div>
          </div>
          
          {/* 로그아웃 */}
          <button className="btn btn-outline" style={{ width: '100%', marginTop: '16px', color: 'var(--color-danger)', borderColor: 'var(--color-danger)' }} onClick={handleLogout}>
            <span className="material-icons-outlined" style={{ fontSize: 18 }}>logout</span>
            로그아웃
          </button>
        </div>
        </div>
      </div>

      <Modal
        isOpen={isPolicyModalOpen}
        onClose={() => setIsPolicyModalOpen(false)}
        title="이용약관 및 정책"
      >
        <div style={{ lineHeight: '1.6', fontSize: 'var(--font-size-sm)', color: 'var(--color-text-secondary)', padding: 'var(--space-2) 0' }}>
          <h4 style={{ color: 'var(--color-text)', marginBottom: 'var(--space-2)' }}>제1조 (목적)</h4>
          <p style={{ marginBottom: 'var(--space-4)' }}>
            본 약관은 Easyplex AI 서비스의 이용과 관련하여 회사와 회원 간의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.
          </p>
          
          <h4 style={{ color: 'var(--color-text)', marginBottom: 'var(--space-2)' }}>제2조 (개인정보보호정책)</h4>
          <p style={{ marginBottom: 'var(--space-4)' }}>
            회사는 관련 법령이 정하는 바에 따라 회원의 개인정보를 보호하기 위해 노력합니다. 개인정보의 보호 및 사용에 대해서는 관련 법령 및 회사의 개인정보처리방침이 적용됩니다.
          </p>

          <h4 style={{ color: 'var(--color-text)', marginBottom: 'var(--space-2)' }}>제3조 (서비스의 제공 및 변경)</h4>
          <p>
            회사는 회원에게 시스템 학습 및 교육 관리 서비스를 제공하며, 운영상 또는 기술상의 필요에 따라 제공하고 있는 서비스의 전부 또는 일부를 변경할 수 있습니다.
          </p>
        </div>
      </Modal>

      {/* 비밀번호 변경 모달 */}
      <Modal
        isOpen={isPasswordModalOpen}
        onClose={() => setIsPasswordModalOpen(false)}
        title="비밀번호 변경"
      >
        <form onSubmit={handlePasswordSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
          {pwdError && <div style={{ color: 'var(--color-danger)', fontSize: 'var(--font-size-sm)' }}>{pwdError}</div>}
          {pwdSuccess && <div style={{ color: 'var(--color-success)', fontSize: 'var(--font-size-sm)' }}>비밀번호가 성공적으로 변경되었습니다.</div>}
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
            <label style={{ fontSize: 'var(--font-size-sm)', fontWeight: 500 }}>현재 비밀번호</label>
            <input type="password" value={pwdForm.current} onChange={(e) => setPwdForm({ ...pwdForm, current: e.target.value })} required />
          </div>
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
            <label style={{ fontSize: 'var(--font-size-sm)', fontWeight: 500 }}>새 비밀번호</label>
            <input type="password" value={pwdForm.newPwd} onChange={(e) => setPwdForm({ ...pwdForm, newPwd: e.target.value })} required />
          </div>
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
            <label style={{ fontSize: 'var(--font-size-sm)', fontWeight: 500 }}>새 비밀번호 확인</label>
            <input type="password" value={pwdForm.confirm} onChange={(e) => setPwdForm({ ...pwdForm, confirm: e.target.value })} required />
          </div>

          <button type="submit" className="btn btn-primary" style={{ marginTop: 'var(--space-4)' }} disabled={isPwdSubmitting || pwdSuccess}>
            {isPwdSubmitting ? '변경 중...' : '변경하기'}
          </button>
        </form>
      </Modal>

      {/* 연락처 수정 모달 */}
      <Modal
        isOpen={isContactModalOpen}
        onClose={() => setIsContactModalOpen(false)}
        title="연락처 수정"
      >
        <form onSubmit={handleContactSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
          {contactSuccess && <div style={{ color: 'var(--color-success)', fontSize: 'var(--font-size-sm)' }}>연락처가 성공적으로 수정되었습니다.</div>}
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
            <label style={{ fontSize: 'var(--font-size-sm)', fontWeight: 500 }}>이메일</label>
            <input type="email" value={contactForm.email} onChange={(e) => setContactForm({ ...contactForm, email: e.target.value })} required disabled />
            <span style={{ fontSize: 'var(--font-size-xs)', color: 'var(--color-text-tertiary)' }}>* 이메일은 변경할 수 없습니다.</span>
          </div>
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
            <label style={{ fontSize: 'var(--font-size-sm)', fontWeight: 500 }}>휴대폰 번호</label>
            <input type="tel" value={contactForm.phone} onChange={(e) => setContactForm({ ...contactForm, phone: e.target.value })} required />
          </div>

          <button type="submit" className="btn btn-primary" style={{ marginTop: 'var(--space-4)' }} disabled={isContactSubmitting || contactSuccess}>
            {isContactSubmitting ? '저장 중...' : '저장하기'}
          </button>
        </form>
      </Modal>
    </>
  );
}
