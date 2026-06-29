import { useState, useEffect } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import { useAuth } from '../../contexts/AuthContext';
import { opsUser, opsMenu } from '../../data/eduops';
import { streamLinkService } from '../../api/streamLinkService';
import type { TodaySession } from '../../api/streamLinkService';
import './EduOps.css';

export default function ClassStreams() {
  const { user } = useAuth();
  const currentUser = user || opsUser;
  const [stream, setStream] = useState<TodaySession | null>(() => streamLinkService.getTodayStream());
  const loading = false;

  useEffect(() => {
    // Listen for storage changes so tech ops updates show immediately
    const handleStorageChange = (e: StorageEvent) => {
      if (e.key === 'easyplex_stream_link_v1') {
        setStream(streamLinkService.getTodayStream());
      }
    };
    window.addEventListener('storage', handleStorageChange);
    return () => window.removeEventListener('storage', handleStorageChange);
  }, []);

  return (
    <DesktopLayout
      brandTitle="EduOps Center"
      brandSubtitle="Class Management"
      menuItems={opsMenu}
      user={currentUser}
      headerTitle="Class Streams Monitoring"
      headerAction="Refresh"
      headerActionIcon="refresh"
    >
      <div className="eduops-layout">
        <div className="col-12" style={{ padding: 'var(--space-6)' }}>
          <header style={{ marginBottom: 'var(--space-4)' }}>
            <h1 className="text-2xl font-bold text-gray-800">Streaming Links Verification</h1>
            <p className="text-gray-500 mt-1">
              기술팀에서 업로드한 금일 실시간 스트리밍 및 동시 송출 링크를 확인합니다. 학생들에게 공유되거나 강사가 접속하는 링크와 동일합니다.
            </p>
          </header>

          <Card title="Today's Stream Links" titleIcon="live_tv">
            {loading ? (
              <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--color-text-secondary)' }}>Loading stream info...</div>
            ) : stream ? (
              <div style={{ 
                display: 'flex', 
                flexDirection: 'column', 
                alignItems: 'center', 
                justifyContent: 'center',
                padding: '3rem 1rem',
                backgroundColor: 'rgba(var(--color-primary-rgb, 43, 108, 176), 0.03)',
                borderRadius: '8px',
                border: '1px dashed var(--color-border)'
              }}>
                <span className="material-icons-outlined" style={{ fontSize: '48px', color: 'var(--color-primary)', marginBottom: '1rem' }}>
                  videocam
                </span>
                <h2 style={{ fontSize: '1.5rem', fontWeight: 600, color: 'var(--color-text-primary)', marginBottom: '0.5rem' }}>
                  {stream.title}
                </h2>
                <div style={{ display: 'flex', gap: '1rem', color: 'var(--color-text-secondary)', marginBottom: '2rem' }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                    <span className="material-icons-outlined" style={{ fontSize: '18px' }}>event</span>
                    {stream.date}
                  </span>
                  <StatusTag label={stream.status} variant="danger" />
                </div>
                
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', width: '100%', maxWidth: '400px' }}>
                  {stream.zoomUrl && (
                    <a 
                      href={stream.zoomUrl} 
                      target="_blank" 
                      rel="noreferrer"
                      className="button button--primary"
                      style={{ padding: '0.75rem 2rem', fontSize: '1.1rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem', width: '100%' }}
                    >
                      <span className="material-icons-outlined">open_in_new</span>
                      Zoom 실시간 강의 참석
                    </a>
                  )}
                  
                  <div style={{ display: 'flex', gap: '1rem', width: '100%' }}>
                    {stream.youtubeUrl && (
                      <a 
                        href={stream.youtubeUrl} 
                        target="_blank" 
                        rel="noreferrer"
                        className="button button--outline"
                        style={{ flex: 1, padding: '0.5rem', fontSize: '0.95rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.25rem' }}
                      >
                        <span className="material-icons-outlined">play_circle</span>
                        YouTube 송출
                      </a>
                    )}
                    {stream.vimeoUrl && (
                      <a 
                        href={stream.vimeoUrl} 
                        target="_blank" 
                        rel="noreferrer"
                        className="button button--outline"
                        style={{ flex: 1, padding: '0.5rem', fontSize: '0.95rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.25rem' }}
                      >
                        <span className="material-icons-outlined">movie</span>
                        Vimeo 송출
                      </a>
                    )}
                  </div>
                </div>
              </div>
            ) : (
              <div style={{ 
                textAlign: 'center', 
                padding: '4rem 2rem', 
                color: 'var(--color-text-secondary)',
                backgroundColor: 'var(--color-bg-alt, #f9fafb)',
                borderRadius: '8px'
              }}>
                <span className="material-icons-outlined" style={{ fontSize: '48px', color: 'var(--color-text-muted, #9ca3af)', marginBottom: '1rem' }}>
                  event_busy
                </span>
                <h3 style={{ fontSize: '1.2rem', fontWeight: 500, marginBottom: '0.5rem', color: 'var(--color-text-primary)' }}>
                  스트리밍 일정이 없습니다
                </h3>
                <p>기술팀에서 아직 금일 스트리밍 링크를 업로드하지 않았습니다.</p>
              </div>
            )}
          </Card>
        </div>
      </div>
    </DesktopLayout>
  );
}
