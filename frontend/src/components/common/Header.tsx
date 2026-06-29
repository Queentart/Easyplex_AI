/* ==========================================================
 * Header 컴포넌트
 * ----------------------------------------------------------
 * 페이지 상단에 위치하는 헤더 바 컴포넌트.
 * 로고/타이틀, 네비게이션 탭, 검색, 알림, 프로필을 표시합니다.
 *
 * [주요 기능]
 * - 브랜드 타이틀 및 부제목 표시
 * - 네비게이션 탭 렌더링 (활성 상태 표시)
 * - 상태 태그 표시 (e.g., "Active Batches: 8")
 * - 알림 아이콘, 프로필 아바타
 * - 액션 버튼 (e.g., "Launch Class", "Deploy Updates")
 * - 검색 입력 필드
 * ========================================================== */

import { useState } from 'react';
import NotificationDropdown from './NotificationDropdown';
import ProfileDropdown from './ProfileDropdown';
import './Header.css';

/** 헤더 탭 아이템 */
interface HeaderTab {
  id: string;
  label: string;
  active: boolean;
}

/** 상태 태그 아이템 */
interface StatusTagItem {
  label: string;
  color: string;
}

/** Header 컴포넌트 Props */
interface HeaderProps {
  /** 헤더 타이틀 */
  title?: string;
  /** 부제목 (한국어 등) */
  subtitle?: string;
  /** 네비게이션 탭 목록 */
  tabs?: HeaderTab[];
  /** 탭 클릭 핸들러 */
  onTabClick?: (tabId: string) => void;
  /** 상태 태그 목록 */
  statusTags?: StatusTagItem[];
  /** 액션 버튼 라벨 */
  actionLabel?: string;
  /** 액션 버튼 아이콘 */
  actionIcon?: string;
  /** 액션 버튼 클릭 핸들러 */
  onAction?: () => void;
  /** 검색 표시 여부 */
  showSearch?: boolean;
  /** 검색 placeholder */
  searchPlaceholder?: string;
  /** 알림 뱃지 표시 여부 */
  showNotificationBadge?: boolean;
  /** 모바일 모드 여부 */
  isMobile?: boolean;
  /** 사용자 이니셜 */
  userInitials?: string;
  /** 추가 우측 아이콘 버튼 */
  extraIcons?: { icon: string; onClick?: () => void }[];
}

/**
 * Header 컴포넌트
 * 
 * 모든 대시보드 페이지 상단에 표시되는 헤더 바입니다.
 * 대시보드 유형에 따라 탭, 검색, 액션 버튼 등을 선택적으로 표시합니다.
 */
export default function Header({
  title,
  subtitle,
  tabs,
  onTabClick,
  statusTags,
  actionLabel,
  actionIcon,
  onAction,
  showSearch = false,
  searchPlaceholder = 'Search...',
  showNotificationBadge = false,
  isMobile = false,
  userInitials = 'U',
  extraIcons,
}: HeaderProps) {
  const [isNotificationOpen, setIsNotificationOpen] = useState(false);
  const [isProfileOpen, setIsProfileOpen] = useState(false);

  const handleNotificationIconClick = () => {
    setIsNotificationOpen(!isNotificationOpen);
  };

  const handleProfileClick = () => {
    setIsProfileOpen(!isProfileOpen);
  };

  return (
    <header className={`header ${isMobile ? 'header--mobile' : ''}`}>
      {/* ── 좌측 영역: 타이틀 + 탭 + 태그 ── */}
      <div className="header__left">
        {title && (
          <>
            <h1 className="header__title">{title}</h1>
            {subtitle && <span className="header__subtitle">{subtitle}</span>}
          </>
        )}

        {/* 네비게이션 탭 */}
        {tabs && tabs.length > 0 && (
          <div className="header__tabs">
            {tabs.map(tab => (
              <button
                key={tab.id}
                className={`header__tab ${tab.active ? 'header__tab--active' : ''}`}
                onClick={() => onTabClick?.(tab.id)}
              >
                {tab.label}
              </button>
            ))}
          </div>
        )}

        {/* 상태 태그 */}
        {statusTags && statusTags.length > 0 && (
          <div className="header__tags">
            {statusTags.map((tag, i) => (
              <span key={i} className={`status-tag status-tag--${tag.color}`}>
                {tag.label}
              </span>
            ))}
          </div>
        )}
      </div>

      {/* ── 우측 영역: 검색 + 액션 + 아이콘 ── */}
      <div className="header__right">
        {/* 검색 입력 */}
        {showSearch && (
          <div className="header__search">
            <span className="material-icons-outlined" style={{ fontSize: 18, color: 'var(--color-text-tertiary)' }}>
              search
            </span>
            <input type="text" placeholder={searchPlaceholder} />
          </div>
        )}

        {/* 액션 버튼 */}
        {actionLabel && (
          <button className="header__action-btn" onClick={onAction}>
            {actionIcon && (
              <span className="material-icons-outlined" style={{ fontSize: 18 }}>
                {actionIcon}
              </span>
            )}
            {actionLabel}
          </button>
        )}

        {/* 추가 아이콘 버튼 */}
        {extraIcons?.map((ei, i) => (
          <button key={i} className="header__icon-btn" onClick={ei.onClick}>
            <span className="material-icons-outlined">{ei.icon}</span>
          </button>
        ))}

        {/* 알림 아이콘 & 드롭다운 */}
        <div style={{ position: 'relative' }}>
          <button 
            className={`header__icon-btn ${showNotificationBadge ? 'header__icon-btn--badge' : ''}`} 
            onClick={handleNotificationIconClick}
          >
            <span className="material-icons-outlined">notifications</span>
          </button>
          <NotificationDropdown 
            isOpen={isNotificationOpen} 
            onClose={() => setIsNotificationOpen(false)} 
          />
        </div>

        {/* 프로필 아바타 & 드롭다운 */}
        <div style={{ position: 'relative' }}>
          <div className="header__avatar" onClick={handleProfileClick}>
            {userInitials}
          </div>
          <ProfileDropdown 
            isOpen={isProfileOpen} 
            onClose={() => setIsProfileOpen(false)} 
            onSettingsClick={extraIcons?.find(ei => ei.icon === 'settings')?.onClick}
          />
        </div>
      </div>
    </header>
  );
}
