import { useState, useEffect } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import { executiveUser, executiveMenuItems } from '../../data/executive';
import { streamLinkService } from '../../api/streamLinkService';
import type { TodaySession } from '../../api/streamLinkService';

export default function ExecutiveClassStreams() {
  const [currentStream, setCurrentStream] = useState<TodaySession | null>(() => streamLinkService.getTodayStream());

  useEffect(() => {
    // 기술팀 업로드 시 실시간 감지
    const handleStorage = (e: StorageEvent) => {
      if (e.key === 'easyplex_stream_link_v1') {
        setCurrentStream(streamLinkService.getTodayStream());
      }
    };
    window.addEventListener('storage', handleStorage);
    return () => window.removeEventListener('storage', handleStorage);
  }, []);

  return (
    <DesktopLayout
      brandTitle="Strategic Command"
      brandSubtitle="Executive Oversight"
      menuItems={executiveMenuItems}
      user={executiveUser}
      headerTitle="Class Streams (Live Oversight)"
    >
      <div className="flex flex-col gap-6 p-6">
        <header>
          <h1 className="text-2xl font-bold text-gray-800">Class Streams</h1>
          <p className="text-gray-500">원장님 권한으로 현재 송출 중인 강의에 긴급하게 직접 접속하여 모니터링할 수 있습니다.</p>
        </header>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Card title="Today's Live Class (Oversight View)" titleIcon="visibility">
            {currentStream && currentStream.status === 'Live' ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '1rem', borderBottom: '1px solid var(--color-border)' }}>
                  <div>
                    <h3 style={{ fontSize: '1.2rem', fontWeight: 600, color: 'var(--color-text-primary)', margin: '0 0 0.25rem 0' }}>{currentStream.title}</h3>
                    <p style={{ fontSize: '0.85rem', color: 'var(--color-text-secondary)', margin: 0 }}>Date: {currentStream.date}</p>
                  </div>
                  <StatusTag label="Live" variant="danger" icon="sensors" />
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                  {currentStream.zoomUrl && (
                    <a 
                      href={currentStream.zoomUrl} 
                      target="_blank" 
                      rel="noreferrer"
                      style={{ display: 'flex', alignItems: 'center', gap: '1rem', padding: '1rem', backgroundColor: '#eff6ff', border: '1px solid #bfdbfe', borderRadius: '8px', color: 'inherit', textDecoration: 'none' }}
                      onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#dbeafe'}
                      onMouseOut={(e) => e.currentTarget.style.backgroundColor = '#eff6ff'}
                    >
                      <div style={{ width: '40px', height: '40px', borderRadius: '50%', backgroundColor: '#2563eb', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <span className="material-icons">videocam</span>
                      </div>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: '1rem', fontWeight: 600, color: '#1e3a8a' }}>Zoom (Primary)</div>
                        <div style={{ fontSize: '0.85rem', color: '#3b82f6' }}>Direct Join via Executive Privileges</div>
                      </div>
                    </a>
                  )}

                  {currentStream.youtubeUrl && (
                    <a 
                      href={currentStream.youtubeUrl} 
                      target="_blank" 
                      rel="noreferrer"
                      style={{ display: 'flex', alignItems: 'center', gap: '1rem', padding: '1rem', backgroundColor: '#fef2f2', border: '1px solid #fecaca', borderRadius: '8px', color: 'inherit', textDecoration: 'none' }}
                      onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#fee2e2'}
                      onMouseOut={(e) => e.currentTarget.style.backgroundColor = '#fef2f2'}
                    >
                      <div style={{ width: '40px', height: '40px', borderRadius: '50%', backgroundColor: '#ef4444', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <span className="material-icons">play_arrow</span>
                      </div>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: '1rem', fontWeight: 600, color: '#991b1b' }}>YouTube (Broadcast)</div>
                        <div style={{ fontSize: '0.85rem', color: '#ef4444' }}>Monitor public stream</div>
                      </div>
                    </a>
                  )}

                  {currentStream.vimeoUrl && (
                    <a 
                      href={currentStream.vimeoUrl} 
                      target="_blank" 
                      rel="noreferrer"
                      style={{ display: 'flex', alignItems: 'center', gap: '1rem', padding: '1rem', backgroundColor: '#f0f9ff', border: '1px solid #bae6fd', borderRadius: '8px', color: 'inherit', textDecoration: 'none' }}
                      onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#e0f2fe'}
                      onMouseOut={(e) => e.currentTarget.style.backgroundColor = '#f0f9ff'}
                    >
                      <div style={{ width: '40px', height: '40px', borderRadius: '50%', backgroundColor: '#0ea5e9', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <span className="material-icons">movie</span>
                      </div>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: '1rem', fontWeight: 600, color: '#075985' }}>Vimeo (Backup Broadcast)</div>
                        <div style={{ fontSize: '0.85rem', color: '#0ea5e9' }}>Monitor backup stream</div>
                      </div>
                    </a>
                  )}
                </div>
              </div>
            ) : (
              <div style={{ padding: '3rem', textAlign: 'center', color: 'var(--color-text-secondary)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '1rem' }}>
                <span className="material-icons-outlined" style={{ fontSize: '48px', color: '#e5e7eb' }}>ondemand_video</span>
                <p>현재 기술팀이 송출 중인 라이브 강의가 없습니다.</p>
              </div>
            )}
          </Card>
        </div>
      </div>
    </DesktopLayout>
  );
}
