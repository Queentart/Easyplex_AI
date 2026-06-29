/* ==========================================================
 * DesktopLayout 컴포넌트
 * ----------------------------------------------------------
 * 데스크톱 대시보드용 레이아웃 (Sidebar + Header + Content).
 * Executive, Instructor, EduOps 대시보드에서 사용됩니다.
 *
 * [구조]
 * ┌──────────┬─────────────────────────┐
 * │ Sidebar  │ Header                  │
 * │          ├─────────────────────────│
 * │          │ Content (children)      │
 * │          │                         │
 * └──────────┴─────────────────────────┘
 * ========================================================== */

import { useState, type ReactNode } from 'react';
import type { MenuItem, User } from '../../types';
import Sidebar from '../common/Sidebar';
import Header from '../common/Header';
import IntranetChatDrawer from '../common/IntranetChatDrawer';
import { useNotification } from '../../contexts/NotificationContext';
import SettingsModal from '../common/SettingsModal';
import './Layout.css';

interface DesktopLayoutProps {
  /* ── Sidebar Props ── */
  /** 사이드바 브랜드 타이틀 */
  brandTitle: string;
  /** 사이드바 브랜드 부제목 */
  brandSubtitle?: string;
  /** 메뉴 아이템 목록 */
  menuItems: MenuItem[];
  /** 사용자 정보 */
  user: User;
  /** 사이드바 액션 버튼 라벨 */
  sidebarAction?: string;
  /** 사이드바 액션 버튼 아이콘 */
  sidebarActionIcon?: string;
  /** 사이드바 액션 버튼 핸들러 */
  onSidebarAction?: () => void;
  /** 사이드바 액션 variant */
  sidebarActionVariant?: 'primary' | 'outline';
  /** 채팅 이력 (Instructor 전용) */
  chatHistory?: { id: string; label: string; date: string }[];
  /** 하단 링크 표시 */
  showFooterLinks?: boolean;
  /** 로그아웃 라벨 */
  logoutLabel?: string;

  /* ── Header Props ── */
  /** 헤더 타이틀 */
  headerTitle?: string;
  /** 헤더 부제목 */
  headerSubtitle?: string;
  /** 헤더 탭 */
  headerTabs?: { id: string; label: string; active: boolean }[];
  /** 탭 클릭 핸들러 */
  onTabClick?: (tabId: string) => void;
  /** 헤더 상태 태그 */
  headerStatusTags?: { label: string; color: string }[];
  /** 헤더 액션 버튼 라벨 */
  headerAction?: string;
  /** 헤더 액션 버튼 아이콘 */
  headerActionIcon?: string;
  /** 헤더 액션 핸들러 */
  onHeaderAction?: () => void;
  /** 헤더 검색 표시 */
  showSearch?: boolean;
  /** 검색 placeholder */
  searchPlaceholder?: string;
  /** 추가 아이콘 */
  headerExtraIcons?: { icon: string; onClick?: () => void }[];

  /* ── Content ── */
  /** 자식 콘텐츠 */
  children: ReactNode;
}

/**
 * DesktopLayout 컴포넌트
 * 
 * 데스크톱 대시보드의 기본 레이아웃 프레임을 제공합니다.
 * 사이드바, 헤더, 콘텐츠 영역으로 구성됩니다.
 */
export default function DesktopLayout({
  brandTitle, brandSubtitle, menuItems, user,
  sidebarAction, sidebarActionIcon, onSidebarAction,
  sidebarActionVariant, chatHistory, showFooterLinks, logoutLabel,
  headerTitle, headerSubtitle, headerTabs, onTabClick,
  headerStatusTags, headerAction, headerActionIcon, onHeaderAction,
  showSearch, searchPlaceholder, headerExtraIcons,
  children,
}: DesktopLayoutProps) {
  const [isIntranetChatOpen, setIsIntranetChatOpen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const { unreadCount } = useNotification();
  /** 사용자 이니셜 생성 (name이 없을 경우를 대비해 기본값 제공) */
  const safeName = user?.name || 'Unknown';
  const userInitials = safeName.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();

  // 사용자 권한별 동적 브랜드 정보 매핑
  let derivedBrandTitle = brandTitle;
  let derivedBrandSubtitle = brandSubtitle;

  if (user) {
    switch (user.role.toLowerCase()) {
      case 'instructor':
        derivedBrandTitle = "EduAI Instructor";
        derivedBrandSubtitle = "AI Co-pilot";
        break;
      case 'tutor':
        derivedBrandTitle = "EduAI Mentor";
        derivedBrandSubtitle = "AI Co-pilot";
        break;
      case 'ops':
      case 'eduops':
        derivedBrandTitle = "EduAI Operations";
        derivedBrandSubtitle = "Ops Portal";
        break;
      case 'tech':
      case 'techops':
        derivedBrandTitle = "EduAI TechCenter";
        derivedBrandSubtitle = "Tech Portal";
        break;
      case 'owner':
        derivedBrandTitle = "EduAI Executive";
        derivedBrandSubtitle = "Owner Portal";
        break;
      default:
        // 학생 등 기본값 유지
        break;
    }
  }

  // 강제로 톱니바퀴 아이콘을 추가
  const combinedExtraIcons = [
    { icon: 'settings', onClick: () => setIsSettingsOpen(true) },
    ...(headerExtraIcons || []),
  ];

  return (
    <div className="desktop-layout">
      {/* 사이드바 */}
      <Sidebar
        brandTitle={derivedBrandTitle}
        brandSubtitle={derivedBrandSubtitle}
        menuItems={menuItems}
        user={user}
        actionLabel={sidebarAction}
        actionIcon={sidebarActionIcon}
        onAction={onSidebarAction}
        actionVariant={sidebarActionVariant}
        chatHistory={chatHistory}
        showFooterLinks={showFooterLinks}
        logoutLabel={logoutLabel}
      />

      {/* 메인 영역 */}
      <main className="desktop-layout__main">
        {/* 헤더 */}
        <Header
          title={headerTitle}
          subtitle={headerSubtitle}
          tabs={headerTabs}
          onTabClick={onTabClick}
          statusTags={headerStatusTags}
          actionLabel={headerAction}
          actionIcon={headerActionIcon}
          onAction={onHeaderAction}
          showSearch={showSearch}
          searchPlaceholder={searchPlaceholder}
          userInitials={userInitials}
          extraIcons={combinedExtraIcons}
          showNotificationBadge={unreadCount > 0}
        />

        {/* 콘텐츠 */}
        <div className="desktop-layout__content">
          {children}
        </div>
      </main>

      {/* 사내 메신저 플로팅 버튼 및 드로어 (관리자 전용) */}
      {user.role !== 'student' && (
        <>
          <button 
            className="fixed bottom-6 right-6 bg-indigo-600 text-white rounded-full w-14 h-14 flex items-center justify-center shadow-xl hover:bg-indigo-700 transition-colors z-40"
            onClick={() => setIsIntranetChatOpen(!isIntranetChatOpen)}
            title="사내 메신저"
          >
            <span 
              className="material-icons-outlined"
              style={{
                transform: isIntranetChatOpen ? 'rotate(90deg)' : 'rotate(0deg)',
                transition: 'transform 0.2s ease-in-out'
              }}
            >
              {isIntranetChatOpen ? 'close' : 'corporate_fare'}
            </span>
          </button>
          <IntranetChatDrawer 
            isOpen={isIntranetChatOpen} 
            onClose={() => setIsIntranetChatOpen(false)} 
            userRole={user.role} 
          />
        </>
      )}

      {/* 관리자 공통 설정 모달 */}
      <SettingsModal isOpen={isSettingsOpen} onClose={() => setIsSettingsOpen(false)} />
    </div>
  );
}
