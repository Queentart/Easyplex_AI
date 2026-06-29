/* ==========================================================
 * Sidebar 컴포넌트
 * ----------------------------------------------------------
 * 데스크톱 레이아웃의 왼쪽 사이드바 네비게이션 컴포넌트.
 * Executive, Instructor, EduOps 각 대시보드에서 재사용됩니다.
 *
 * [주요 기능]
 * - 브랜드 로고 & 타이틀 표시
 * - 네비게이션 메뉴 아이템 렌더링 (활성 상태 표시)
 * - 액션 버튼 (e.g., "New Analysis", "Generate Report")
 * - 사용자 프로필 표시
 * - 채팅 이력 목록 (Instructor 전용)
 * - 하단 링크 (Settings, Support)
 * ========================================================== */

import { useLocation, useNavigate } from 'react-router-dom';
import type { MenuItem, User } from '../../types';
import './Sidebar.css';

/** Sidebar 컴포넌트 Props 인터페이스 */
interface SidebarProps {
  /** 브랜드 타이틀 (e.g., "EduAI Executive") */
  brandTitle: string;
  /** 브랜드 부제목 (e.g., "Strategic Oversight") */
  brandSubtitle?: string;
  /** 사이드바 메뉴 아이템 목록 */
  menuItems: MenuItem[];
  /** 사용자 프로필 정보 */
  user: User;
  /** 액션 버튼 라벨 (e.g., "Generate Report") */
  actionLabel?: string;
  /** 액션 버튼 아이콘 */
  actionIcon?: string;
  /** 액션 버튼 클릭 핸들러 */
  onAction?: () => void;
  /** 액션 버튼 스타일 variant */
  actionVariant?: 'primary' | 'outline';
  /** 채팅 이력 목록 (Instructor 전용) */
  chatHistory?: { id: string; label: string; date: string }[];
  /** 하단 링크 표시 여부 */
  showFooterLinks?: boolean;
  /** 로그아웃 라벨 */
  logoutLabel?: string;
}

/**
 * Sidebar 컴포넌트
 * 
 * 데스크톱 레이아웃에서 왼쪽에 고정되는 네비게이션 사이드바입니다.
 * 현재 라우트에 따라 활성 메뉴 아이템을 자동으로 하이라이트합니다.
 */
export default function Sidebar({
  brandTitle,
  brandSubtitle,
  menuItems,
  user,
  actionLabel,
  actionIcon,
  onAction,
  actionVariant = 'primary',
  chatHistory,
  showFooterLinks = true,
  logoutLabel,
}: SidebarProps) {
  const location = useLocation();
  const navigate = useNavigate();

  /**
   * 메뉴 아이템이 현재 활성 상태인지 확인
   * @param path - 메뉴 아이템의 라우트 경로
   * @returns 활성 상태 여부
   */
  const isActive = (path: string): boolean => {
    return location.pathname === path;
  };

  /**
   * 메뉴 아이템 클릭 핸들러
   * react-router를 통해 해당 경로로 네비게이션합니다.
   */
  const handleMenuClick = (path: string) => {
    navigate(path);
  };

  /** 사용자 이름의 이니셜 생성 */
  const getInitials = (name: string): string => {
    return name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();
  };

  return (
    <aside className="sidebar">
      {/* ── 브랜드 로고 영역 ── */}
      <div className="sidebar__brand">
        <div className="sidebar__brand-icon">
          {brandTitle.charAt(0)}
        </div>
        <div className="sidebar__brand-text">
          <span className="sidebar__brand-title">{brandTitle}</span>
          {brandSubtitle && (
            <span className="sidebar__brand-subtitle">{brandSubtitle}</span>
          )}
        </div>
      </div>

      {/* ── 액션 버튼 (있는 경우) ── */}
      {actionLabel && (
        <div className="sidebar__action">
          <button
            className={`sidebar__action-btn ${actionVariant === 'outline' ? 'sidebar__action-btn--outline' : ''}`}
            onClick={onAction}
          >
            {actionIcon && (
              <span className="material-icons-outlined" style={{ fontSize: 18 }}>
                {actionIcon}
              </span>
            )}
            {actionLabel}
          </button>
        </div>
      )}

      {/* ── 채팅 이력 (Instructor 전용) ── */}
      {chatHistory && chatHistory.length > 0 && (
        <div className="sidebar__chat-history">
          <div className="sidebar__chat-history-title">Chat History</div>
          {chatHistory.map(chat => (
            <div key={chat.id} className="sidebar__chat-item">
              <span className="material-icons-outlined" style={{ fontSize: 16 }}>chat_bubble_outline</span>
              {chat.label}
            </div>
          ))}
          <div className="sidebar__divider" />
        </div>
      )}

      <nav className="sidebar__nav">
        {menuItems
          .filter(item => !item.allowedRoles || item.allowedRoles.includes(user.role))
          .map(item => (
          <div
            key={item.id}
            className={`sidebar__menu-item ${isActive(item.path) ? 'sidebar__menu-item--active' : ''}`}
            onClick={() => handleMenuClick(item.path)}
            role="button"
            tabIndex={0}
            aria-current={isActive(item.path) ? 'page' : undefined}
          >
            <span className="material-icons-outlined sidebar__menu-icon">
              {item.icon}
            </span>
            <span className="sidebar__menu-label">{item.label}</span>
            {item.badge && (
              <span className="sidebar__menu-badge">{item.badge}</span>
            )}
          </div>
        ))}
      </nav>

      {/* ── 하단 영역 ── */}
      <div className="sidebar__footer">
        {/* 하단 링크 (Settings, Support) */}
        {showFooterLinks && (
          <div className="sidebar__footer-links">
            <span className="sidebar__footer-link" onClick={() => navigate('/settings')}>
              <span className="material-icons-outlined" style={{ fontSize: 16 }}>settings</span>
              Settings
            </span>
            <span className="sidebar__footer-link">
              <span className="material-icons-outlined" style={{ fontSize: 16 }}>help_outline</span>
              Support
            </span>
          </div>
        )}

        {/* 로그아웃 링크 */}
        {logoutLabel && (
          <div className="sidebar__footer-links">
            <span className="sidebar__footer-link">
              <span className="material-icons-outlined" style={{ fontSize: 16 }}>logout</span>
              {logoutLabel}
            </span>
          </div>
        )}

        {/* 사용자 프로필 */}
        <div className="sidebar__profile">
          <div className="sidebar__profile-avatar">
            {getInitials(user.name)}
          </div>
          <div className="sidebar__profile-info">
            <span className="sidebar__profile-name">{user.nameKo || user.name}</span>
            <span className="sidebar__profile-role">{user.title || user.role}</span>
          </div>
        </div>
      </div>
    </aside>
  );
}
