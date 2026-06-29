/* ==========================================================
 * MobileLayout 컴포넌트
 * ----------------------------------------------------------
 * 모바일 PWA 레이아웃 (Header + Content + BottomNav).
 * Student PWA 화면에서 사용됩니다.
 *
 * [구조]
 * ┌─────────────────────────┐
 * │ Header (compact)        │
 * ├─────────────────────────│
 * │ Content (scrollable)    │
 * │                         │
 * ├─────────────────────────│
 * │ BottomNav               │
 * └─────────────────────────┘
 * ========================================================== */

import { useState } from 'react';
import type { ReactNode } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import type { BottomNavItem } from '../../types';
import Header from '../common/Header';
import AIHelpBotModal from '../../pages/student/AIHelpBot';
import { useNotification } from '../../contexts/NotificationContext';
import './Layout.css';

interface MobileLayoutProps {
  /** 헤더 타이틀 (로고 텍스트) */
  title?: string;
  /** 하단 네비게이션 아이템 목록 */
  bottomNavItems: BottomNavItem[];
  /** FAB 버튼 표시 여부 */
  showFAB?: boolean;
  /** FAB 클릭 핸들러 */
  onFABClick?: () => void;
  /** 검색 표시 여부 */
  showSearch?: boolean;
  /** 추가 헤더 아이콘 */
  headerExtraIcons?: { icon: string; onClick?: () => void }[];
  /** 자식 콘텐츠 */
  children: ReactNode;
}

/**
 * MobileLayout 컴포넌트
 * 
 * 모바일 PWA 앱의 기본 레이아웃을 제공합니다.
 * 상단 헤더, 스크롤 가능한 콘텐츠, 하단 네비게이션으로 구성됩니다.
 */
export default function MobileLayout({
  title = 'AcademiaAI',
  bottomNavItems,
  showFAB = true,
  onFABClick,
  showSearch = false,
  headerExtraIcons,
  children,
}: MobileLayoutProps) {
  const location = useLocation();
  const navigate = useNavigate();
  const [isChatOpen, setIsChatOpen] = useState(false);
  const [fabUnreadCount, setFabUnreadCount] = useState(0);
  const { unreadCount } = useNotification();

  /**
   * 하단 네비 아이템 활성 상태 확인
   * 정확한 경로 매칭으로 현재 탭을 하이라이트합니다.
   */
  const isActive = (path: string): boolean => {
    if (path === '/student') return location.pathname === '/student';
    return location.pathname.startsWith(path);
  };

  const handleFABClick = () => {
    if (onFABClick) {
      onFABClick();
    } else {
      setIsChatOpen(!isChatOpen);
    }
  };

  return (
    <div className="mobile-layout">
      {/* 상단 헤더 */}
      <Header
        title={title}
        isMobile={true}
        showSearch={showSearch}
        extraIcons={headerExtraIcons}
        userInitials="S"
        showNotificationBadge={unreadCount > 0}
      />

      {/* 메인 콘텐츠 */}
      <div className="mobile-layout__content">
        {children}
      </div>

      {/* FAB (플로팅 액션 버튼) - AI 챗봇 */}
      {showFAB && (
        <button className="fab" onClick={handleFABClick} aria-label="AI Help Bot">
          <span className="material-icons">{isChatOpen ? 'close' : 'smart_toy'}</span>
          {!isChatOpen && fabUnreadCount > 0 && (
            <span style={{
              position: 'absolute', top: -4, right: -4, background: 'var(--color-danger)', color: 'white',
              fontSize: '11px', fontWeight: 'bold', width: '20px', height: '20px', borderRadius: '50%',
              display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px solid white'
            }}>
              {fabUnreadCount > 99 ? '99+' : fabUnreadCount}
            </span>
          )}
        </button>
      )}

      {/* 챗봇 모달 오버레이 */}
      <AIHelpBotModal isOpen={isChatOpen} onClose={() => setIsChatOpen(false)} onUnreadChange={setFabUnreadCount} />

      {/* 하단 네비게이션 */}
      <nav className="bottom-nav">
        {bottomNavItems.map(item => (
          <button
            key={item.id}
            className={`bottom-nav__item ${isActive(item.path) ? 'bottom-nav__item--active' : ''}`}
            onClick={() => navigate(item.path)}
          >
            <span className="material-icons-outlined bottom-nav__icon">{item.icon}</span>
            <span>{item.label}</span>
          </button>
        ))}
      </nav>
    </div>
  );
}
