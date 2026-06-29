import { useState, useRef, useEffect } from 'react';
import { useNotification } from '../../contexts/NotificationContext';
import { notificationApi } from '../../api/notificationApi';

interface NotificationDropdownProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function NotificationDropdown({ isOpen, onClose }: NotificationDropdownProps) {
  const { notifications, unreadCount, markAsRead, markAllAsRead, refreshNotifications } = useNotification();
  const dropdownRef = useRef<HTMLDivElement>(null);

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

  const handleNotificationClick = async (id: number) => {
    // 알림 클릭 시 페이지 이동 없이 읽음 처리(빨간 점 제거)만 수행
    await markAsRead(id);
  };

  const [testTypeIndex, setTestTypeIndex] = useState(0);

  const handleTestNotification = async () => {
    const types = ['info', 'warning', 'success', 'message', 'alert'];
    const selectedType = types[testTypeIndex];
    setTestTypeIndex((prev) => (prev + 1) % types.length);

    await notificationApi.createTestNotification(
      `테스트 알림 (${selectedType})`,
      '이것은 테스트로 생성된 알림입니다.',
      selectedType
    );
    await refreshNotifications();
  };

  const getIconForType = (type: string) => {
    switch (type) {
      case 'warning': return { icon: 'warning', color: 'var(--color-warning)' };
      case 'success': return { icon: 'check_circle', color: 'var(--color-success)' };
      case 'message': return { icon: 'chat', color: 'var(--color-primary)' };
      case 'alert': return { icon: 'error', color: 'var(--color-danger)' };
      case 'info':
      default: return { icon: 'campaign', color: 'var(--color-info)' };
    }
  };

  const getTimeAgo = (dateStr: string) => {
    const date = new Date(dateStr);
    const now = new Date();
    const diff = Math.floor((now.getTime() - date.getTime()) / 1000);
    
    if (diff < 60) return '방금 전';
    if (diff < 3600) return `${Math.floor(diff / 60)}분 전`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}시간 전`;
    return `${Math.floor(diff / 86400)}일 전`;
  };

  if (!isOpen) return null;

  return (
    <div 
      ref={dropdownRef}
      style={{
        position: 'absolute',
        top: '120%',
        right: '-10px',
        width: '360px',
        maxHeight: '480px',
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
      {/* Header */}
      <div style={{ 
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center', 
        padding: '16px',
        borderBottom: '1px solid var(--color-border)',
        background: '#f8fafc'
      }}>
        <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}>
          알림 센터
          {unreadCount > 0 && (
            <span style={{
              background: 'var(--color-danger)', 
              color: 'white', 
              borderRadius: '50%', 
              padding: '2px 6px',
              fontSize: '0.75rem',
              fontWeight: 'bold'
            }}>
              {unreadCount}
            </span>
          )}
        </h3>
        <div style={{ display: 'flex', gap: '8px' }}>
          <button 
            onClick={handleTestNotification}
            style={{ 
              background: 'none', border: '1px solid var(--color-border)', 
              borderRadius: '4px', fontSize: '0.75rem', padding: '4px 8px', cursor: 'pointer',
              color: 'var(--color-text-secondary)', display: 'flex', alignItems: 'center', gap: '4px'
            }}
          >
            <span className="material-icons-outlined" style={{ fontSize: '14px', color: 'var(--color-info)' }}>campaign</span>
            테스트
          </button>
          <button 
            onClick={markAllAsRead}
            disabled={unreadCount === 0}
            style={{ 
              background: 'none', border: 'none', fontSize: '0.875rem', cursor: unreadCount > 0 ? 'pointer' : 'not-allowed',
              color: unreadCount > 0 ? 'var(--color-primary)' : 'var(--color-text-tertiary)'
            }}
          >
            모두 읽음
          </button>
        </div>
      </div>

      {/* List */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '0', maxHeight: '380px' }} className="hide-scrollbar">
        {notifications.length === 0 ? (
          <div style={{ padding: '32px 16px', textAlign: 'center', color: 'var(--color-text-tertiary)' }}>
            <span className="material-icons-outlined" style={{ fontSize: '32px', marginBottom: '8px' }}>notifications_none</span>
            <p style={{ margin: 0, fontSize: '0.875rem' }}>새로운 알림이 없습니다.</p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            {notifications.map(notification => {
              const { icon, color } = getIconForType(notification.type);
              return (
                <div 
                  key={notification.id}
                  onClick={() => handleNotificationClick(notification.id)}
                  style={{
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: '12px',
                    padding: '16px',
                    background: notification.is_read ? 'white' : '#f0fdfa',
                    borderBottom: '1px solid var(--color-border)',
                    cursor: 'pointer',
                    transition: 'background 0.2s'
                  }}
                  onMouseOver={(e) => e.currentTarget.style.background = '#f8fafc'}
                  onMouseOut={(e) => e.currentTarget.style.background = notification.is_read ? 'white' : '#f0fdfa'}
                >
                  <div style={{ 
                    color: color,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    background: `${color}15`,
                    padding: '8px',
                    borderRadius: '50%',
                    flexShrink: 0
                  }}>
                    <span className="material-icons-outlined" style={{ fontSize: '20px' }}>{icon}</span>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '4px' }}>
                      <h4 style={{ 
                        margin: 0, fontSize: '0.9rem', color: 'var(--color-text-primary)',
                        fontWeight: notification.is_read ? 500 : 600,
                        whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis'
                      }}>
                        {notification.title}
                      </h4>
                      {!notification.is_read && (
                        <div style={{
                          width: '6px', height: '6px', borderRadius: '50%',
                          background: 'var(--color-danger)', marginTop: '6px', flexShrink: 0
                        }} />
                      )}
                    </div>
                    <p style={{ 
                      margin: '0 0 4px 0', fontSize: '0.8rem', color: 'var(--color-text-secondary)',
                      display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden'
                    }}>
                      {notification.message}
                    </p>
                    <span style={{ fontSize: '0.7rem', color: 'var(--color-text-tertiary)' }}>
                      {getTimeAgo(notification.created_at)}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
