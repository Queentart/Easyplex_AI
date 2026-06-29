import { useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

interface ProfileDropdownProps {
  isOpen: boolean;
  onClose: () => void;
  onSettingsClick?: () => void;
}

export default function ProfileDropdown({ isOpen, onClose, onSettingsClick }: ProfileDropdownProps) {
  const dropdownRef = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();

  // Close dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        onClose();
      }
    }

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const handleMenuItemClick = (action: string) => {
    if (action === '마이 페이지') {
      navigate('/mypage');
    } else {
      console.log(`${action} 클릭됨`);
      alert(`${action} 페이지로 이동 또는 기능 실행이 연결될 예정입니다.`);
    }
    onClose();
  };

  return (
    <div 
      ref={dropdownRef}
      style={{
        position: 'absolute',
        top: '120%',
        right: '0',
        width: '240px',
        background: 'white',
        borderRadius: '12px',
        boxShadow: '0 10px 40px rgba(0,0,0,0.1), 0 4px 12px rgba(0,0,0,0.05)',
        border: '1px solid var(--color-border)',
        display: 'flex',
        flexDirection: 'column',
        zIndex: 9999,
        overflow: 'hidden'
      }}
    >
      {/* Profile Header (User Info Summary) */}
      <div style={{ 
        padding: '16px',
        borderBottom: '1px solid var(--color-border)',
        background: '#f8fafc',
        display: 'flex',
        flexDirection: 'column',
        gap: '4px'
      }}>
        <div style={{ fontSize: '1rem', fontWeight: 600, color: 'var(--color-text-primary)' }}>
          User Name
        </div>
        <div style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>
          user@example.com
        </div>
      </div>

      {/* Menu List */}
      <div style={{ display: 'flex', flexDirection: 'column', padding: '8px 0' }}>
        
        {/* 마이 페이지 */}
        <div 
          onClick={() => handleMenuItemClick('마이 페이지')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            padding: '12px 16px',
            cursor: 'pointer',
            transition: 'background 0.2s',
            color: 'var(--color-text-primary)',
            fontSize: '0.9rem'
          }}
          onMouseOver={(e) => e.currentTarget.style.background = '#f0f4f8'}
          onMouseOut={(e) => e.currentTarget.style.background = 'white'}
        >
          <span className="material-icons-outlined" style={{ fontSize: '20px', color: 'var(--color-text-secondary)' }}>person</span>
          마이 페이지
        </div>

        {/* 설정 */}
        <div 
          onClick={() => {
            if (onSettingsClick) {
              onSettingsClick();
              onClose();
            } else {
              handleMenuItemClick('설정');
            }
          }}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            padding: '12px 16px',
            cursor: 'pointer',
            transition: 'background 0.2s',
            color: 'var(--color-text-primary)',
            fontSize: '0.9rem'
          }}
          onMouseOver={(e) => e.currentTarget.style.background = '#f0f4f8'}
          onMouseOut={(e) => e.currentTarget.style.background = 'white'}
        >
          <span className="material-icons-outlined" style={{ fontSize: '20px', color: 'var(--color-text-secondary)' }}>settings</span>
          설정
        </div>

        <div style={{ height: '1px', background: 'var(--color-border)', margin: '4px 0' }} />

        {/* 로그아웃 */}
        <div 
          onClick={() => handleMenuItemClick('로그아웃')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            padding: '12px 16px',
            cursor: 'pointer',
            transition: 'background 0.2s',
            color: 'var(--color-danger)',
            fontSize: '0.9rem',
            fontWeight: 500
          }}
          onMouseOver={(e) => e.currentTarget.style.background = '#fef2f2'}
          onMouseOut={(e) => e.currentTarget.style.background = 'white'}
        >
          <span className="material-icons-outlined" style={{ fontSize: '20px', color: 'var(--color-danger)' }}>logout</span>
          로그아웃
        </div>

      </div>
    </div>
  );
}
