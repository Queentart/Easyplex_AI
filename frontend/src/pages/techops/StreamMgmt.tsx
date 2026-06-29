import React, { useState, useEffect } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import { useAuth } from '../../contexts/AuthContext';
import { mockTechUser, techMenu } from '../../data/techops';
import { streamLinkService } from '../../api/streamLinkService';
import type { TodaySession } from '../../api/streamLinkService';
import { vodService } from '../../api/vodService';
import { opsLogService } from '../../api/opsLogService';
import type { RecordedLecture } from '../../types';

export default function StreamMgmt() {
  const { user } = useAuth();
  const currentUser = user || mockTechUser;

  const initialStream = streamLinkService.getTodayStream();
  const [currentStream, setCurrentStream] = useState<TodaySession | null>(initialStream);
  const [vods, setVods] = useState<RecordedLecture[]>(vodService.getVODs());
  
  const [newTitle, setNewTitle] = useState(initialStream?.title || '');
  const [zoomUrl, setZoomUrl] = useState(initialStream?.zoomUrl || '');
  const [youtubeUrl, setYoutubeUrl] = useState(initialStream?.youtubeUrl || '');
  const [vimeoUrl, setVimeoUrl] = useState(initialStream?.vimeoUrl || '');

  // VOD form states
  const [showVodForm, setShowVodForm] = useState(false);
  const [vodFormId, setVodFormId] = useState<string | null>(null);
  const [vodTitle, setVodTitle] = useState('');
  const [vodWeek, setVodWeek] = useState(1);
  const [vodYoutube, setVodYoutube] = useState('');
  const [vodVimeo, setVodVimeo] = useState('');

  useEffect(() => {

    const handleStorage = (e: StorageEvent) => {
      if (e.key === 'easyplex_stream_link_v1') setCurrentStream(streamLinkService.getTodayStream());
      if (e.key === 'easyplex_vod_list') setVods(vodService.getVODs());
    };
    window.addEventListener('storage', handleStorage);
    return () => window.removeEventListener('storage', handleStorage);
  }, []);

  const handleBroadcastStream = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle) {
      alert('세션 타이틀을 입력해주세요.');
      return;
    }

    const updated = streamLinkService.updateTodayStream({
      title: newTitle,
      zoomUrl: zoomUrl || null,
      youtubeUrl: youtubeUrl || null,
      vimeoUrl: vimeoUrl || null,
      date: new Date().toISOString().split('T')[0],
      status: 'Live'
    });
    
    setCurrentStream(updated);
    window.dispatchEvent(new StorageEvent('storage', { key: 'easyplex_stream_link_v1' }));
    alert('라이브 스트리밍 링크가 수강생, 강사진, 운영팀 화면에 모두 실시간 동기화되었습니다!');
  };

  const handleEndStream = () => {
    if (window.confirm('스트리밍을 종료(Archived) 상태로 변경하시겠습니까? 해당 영상은 VOD 목록으로 자동 추가됩니다.')) {
      const updated = streamLinkService.updateTodayStream({ status: 'Archived' });
      setCurrentStream(updated);
      window.dispatchEvent(new StorageEvent('storage', { key: 'easyplex_stream_link_v1' }));

      // Auto archive to VOD list
      const highestWeek = vods.reduce((max, vod) => Math.max(max, vod.week || 1), 1);
      vodService.addVOD({
        id: Date.now().toString(),
        title: updated.title,
        date: updated.date,
        duration: "00:00", // Default duration, TechOps can edit later
        week: highestWeek,
        youtubeUrl: updated.youtubeUrl || undefined,
        vimeoUrl: updated.vimeoUrl || undefined,
      });
      setVods(vodService.getVODs());
      alert(`VOD 목록(Week ${highestWeek})에 성공적으로 아카이브 되었습니다.`);
    }
  };

  const openVodForm = (vod?: RecordedLecture) => {
    if (vod) {
      setVodFormId(vod.id);
      setVodTitle(vod.title);
      setVodWeek(vod.week || 1);
      setVodYoutube(vod.youtubeUrl || vod.url || '');
      setVodVimeo(vod.vimeoUrl || '');
    } else {
      setVodFormId(null);
      setVodTitle('');
      setVodWeek(1);
      setVodYoutube('');
      setVodVimeo('');
    }
    setShowVodForm(true);
  };

  const saveVod = (e: React.FormEvent) => {
    e.preventDefault();
    if (vodFormId) {
      vodService.updateVOD(vodFormId, {
        title: vodTitle,
        week: vodWeek,
        youtubeUrl: vodYoutube,
        vimeoUrl: vodVimeo,
        url: vodYoutube || vodVimeo // fallback
      });
      opsLogService.addLog('VOD Updated', `Updated VOD: ${vodTitle} (Week ${vodWeek})`, 'info');
    } else {
      vodService.addVOD({
        id: Date.now().toString(),
        title: vodTitle,
        date: new Date().toISOString().split('T')[0],
        duration: "00:00",
        week: vodWeek,
        youtubeUrl: vodYoutube,
        vimeoUrl: vodVimeo,
        url: vodYoutube || vodVimeo
      });
      opsLogService.addLog('VOD Added', `Added new VOD: ${vodTitle} (Week ${vodWeek})`, 'success');
    }
    setVods(vodService.getVODs());
    setShowVodForm(false);
  };

  const deleteVod = () => {
    if (vodFormId && window.confirm('정말 이 VOD를 삭제하시겠습니까?')) {
      const vod = vods.find(v => v.id === vodFormId);
      vodService.deleteVOD(vodFormId);
      opsLogService.addLog('VOD Deleted', `Deleted VOD: ${vod?.title || vodFormId}`, 'warning');
      setVods(vodService.getVODs());
      setShowVodForm(false);
    }
  };

  return (
    <DesktopLayout
      brandTitle="TechOps Center"
      brandSubtitle="Systems & Infrastructure"
      menuItems={techMenu}
      user={currentUser}
      headerTitle="Streaming Management"
      headerAction="Refresh List"
      headerActionIcon="refresh"
      sidebarAction="Export Logs"
      sidebarActionIcon="download"
    >
      <div className="flex flex-col gap-6 p-6">
        <header>
          <h1 className="text-2xl font-bold text-gray-800">Live Stream Broadcaster</h1>
          <p className="text-gray-500">수강생 및 전체 교직원에게 배포될 오늘의 라이브 스트리밍 링크를 관리하고 동시 송출합니다.</p>
        </header>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="md:col-span-1">
            <Card title="Broadcast New Stream" titleIcon="cell_tower">
              <form onSubmit={handleBroadcastStream} className="flex flex-col gap-4">
                <div style={{ padding: '1rem', backgroundColor: '#eff6ff', borderRadius: '8px', border: '1px solid #bfdbfe', marginBottom: '0.5rem' }}>
                  <p style={{ fontSize: '0.85rem', color: '#1e40af', margin: 0 }}>
                    <span className="material-icons-outlined" style={{ fontSize: '16px', verticalAlign: 'middle', marginRight: '4px' }}>info</span>
                    여기에 링크를 입력하고 <strong>[동시 송출 배포]</strong>를 누르면, 즉시 수강생/강사진/운영팀/원장님의 모든 화면에 실시간으로 버튼이 활성화됩니다.
                  </p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Session Title</label>
                  <input type="text" className="w-full border border-gray-300 rounded p-2 text-sm" placeholder="e.g. Week 4: Final Project Live" value={newTitle} onChange={(e) => setNewTitle(e.target.value)} required />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">1. Zoom URL (주 강의)</label>
                  <input type="url" className="w-full border border-gray-300 rounded p-2 text-sm" placeholder="https://zoom.us/j/..." value={zoomUrl} onChange={(e) => setZoomUrl(e.target.value)} />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">2. YouTube Live URL (메인 송출)</label>
                  <input type="url" className="w-full border border-gray-300 rounded p-2 text-sm" placeholder="https://youtube.com/live/..." value={youtubeUrl} onChange={(e) => setYoutubeUrl(e.target.value)} />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">3. Vimeo Live URL (백업 송출)</label>
                  <input type="url" className="w-full border border-gray-300 rounded p-2 text-sm" placeholder="https://vimeo.com/event/..." value={vimeoUrl} onChange={(e) => setVimeoUrl(e.target.value)} />
                </div>
                
                <button type="submit" className="mt-4 bg-teal-600 text-white rounded py-3 text-sm font-bold hover:bg-teal-700 transition flex items-center justify-center gap-2">
                  <span className="material-icons-outlined">podcasts</span> 전체 동시 송출 배포
                </button>
              </form>
            </Card>
          </div>

          <div className="md:col-span-1">
            <Card title="Current Live Status" titleIcon="visibility">
              {currentStream ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '1rem', borderBottom: '1px solid var(--color-border)' }}>
                    <div>
                      <h3 style={{ fontSize: '1.2rem', fontWeight: 600, color: 'var(--color-text-primary)', margin: '0 0 0.25rem 0' }}>{currentStream.title}</h3>
                      <p style={{ fontSize: '0.85rem', color: 'var(--color-text-secondary)', margin: 0 }}>송출일: {currentStream.date}</p>
                    </div>
                    <StatusTag label={currentStream.status} variant={currentStream.status === 'Live' ? 'danger' : 'success'} icon={currentStream.status === 'Live' ? 'sensors' : 'archive'} />
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                      <span className="material-icons-outlined" style={{ color: zoomUrl ? '#2563eb' : '#9ca3af' }}>videocam</span>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: '0.9rem', fontWeight: 500, color: 'var(--color-text-primary)' }}>Zoom (Primary)</div>
                        <div style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>{currentStream.zoomUrl || 'Not configured'}</div>
                      </div>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                      <span className="material-icons-outlined" style={{ color: youtubeUrl ? '#ef4444' : '#9ca3af' }}>play_circle</span>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: '0.9rem', fontWeight: 500, color: 'var(--color-text-primary)' }}>YouTube (Main Broadcast)</div>
                        <div style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>{currentStream.youtubeUrl || 'Not configured'}</div>
                      </div>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                      <span className="material-icons-outlined" style={{ color: vimeoUrl ? '#0ea5e9' : '#9ca3af' }}>movie</span>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: '0.9rem', fontWeight: 500, color: 'var(--color-text-primary)' }}>Vimeo (Backup Broadcast)</div>
                        <div style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>{currentStream.vimeoUrl || 'Not configured'}</div>
                      </div>
                    </div>
                  </div>

                  {currentStream.status === 'Live' && (
                    <button onClick={handleEndStream} style={{ marginTop: '1rem', width: '100%', padding: '10px', background: 'transparent', border: '1px solid #ef4444', color: '#ef4444', borderRadius: '4px', fontWeight: 500 }}>
                      송출 종료 처리 (Archive)
                    </button>
                  )}
                </div>
              ) : (
                <div style={{ padding: '3rem', textAlign: 'center', color: 'var(--color-text-secondary)' }}>현재 송출 중인 스트림이 없습니다.</div>
              )}
            </Card>
          </div>
        </div>

        {/* =========================================
            VOD Management Section
        ========================================= */}
        <div className="mt-4">
          <Card 
            title="VOD / Archived Lectures Management" 
            titleIcon="video_library"
            action={<button type="button" onClick={() => openVodForm()} className="text-sm bg-blue-100 text-blue-700 px-3 py-1 rounded font-medium hover:bg-blue-200 transition cursor-pointer relative z-10 pointer-events-auto">Add New VOD</button>}
          >
            <div className="overflow-x-auto mt-4">
              <table className="w-full text-left text-sm text-gray-600">
                <thead className="bg-gray-50 border-b border-gray-200 text-gray-700">
                  <tr>
                    <th className="p-3 font-semibold">Week</th>
                    <th className="p-3 font-semibold">Title</th>
                    <th className="p-3 font-semibold">Date</th>
                    <th className="p-3 font-semibold">Links</th>
                    <th className="p-3 font-semibold text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {vods.length === 0 ? (
                    <tr><td colSpan={5} className="p-6 text-center text-gray-400">등록된 VOD가 없습니다.</td></tr>
                  ) : (
                    vods.map(vod => (
                      <tr key={vod.id} className="hover:bg-gray-50">
                        <td className="p-3 font-medium text-gray-900 text-center w-16">W{vod.week || 1}</td>
                        <td className="p-3 font-medium text-gray-800">{vod.title}</td>
                        <td className="p-3 text-xs">{vod.date}</td>
                        <td className="p-3 text-xs">
                          <div className="flex flex-col gap-1">
                            {(vod.youtubeUrl || (vod.url && vod.url.includes('youtube'))) && (
                              <div className="flex items-center gap-2">
                                <span className="inline-block bg-red-100 text-red-700 px-2 py-0.5 rounded text-[10px] font-bold whitespace-nowrap">YouTube</span>
                                <a href={vod.youtubeUrl || vod.url} target="_blank" rel="noreferrer" className="text-blue-500 hover:text-blue-700 hover:underline truncate max-w-[150px]" title={vod.youtubeUrl || vod.url}>
                                  Link
                                </a>
                              </div>
                            )}
                            {(vod.vimeoUrl || (vod.url && vod.url.includes('vimeo'))) && (
                              <div className="flex items-center gap-2">
                                <span className="inline-block bg-blue-100 text-blue-700 px-2 py-0.5 rounded text-[10px] font-bold whitespace-nowrap">Vimeo</span>
                                <a href={vod.vimeoUrl || vod.url} target="_blank" rel="noreferrer" className="text-blue-500 hover:text-blue-700 hover:underline truncate max-w-[150px]" title={vod.vimeoUrl || vod.url}>
                                  Link
                                </a>
                              </div>
                            )}
                            {!vod.youtubeUrl && !vod.vimeoUrl && !vod.url && (
                              <span className="text-gray-400 italic">No links</span>
                            )}
                          </div>
                        </td>
                        <td className="p-3 text-right">
                          <button type="button" onClick={() => openVodForm(vod)} className="text-blue-600 hover:text-blue-800 font-medium px-2 py-1 rounded hover:bg-blue-50 transition cursor-pointer relative z-10 pointer-events-auto">Edit</button>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            {/* Modal replaces inline form */}
          </Card>
        </div>

      </div>

      {/* VOD Edit Modal */}
      {showVodForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="bg-white w-full max-w-lg rounded-2xl shadow-2xl overflow-hidden flex flex-col">
            
            {/* Modal Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 bg-gray-50">
              <h3 className="font-bold text-lg text-gray-800 flex items-center gap-2">
                <span className="material-icons-outlined text-teal-600">
                  {vodFormId ? 'edit_square' : 'add_circle_outline'}
                </span>
                {vodFormId ? 'Edit VOD' : 'Add New VOD'}
              </h3>
              <button 
                onClick={() => setShowVodForm(false)}
                className="text-gray-400 hover:text-gray-700 hover:bg-gray-200 p-1 rounded-full transition flex items-center justify-center"
              >
                <span className="material-icons-outlined">close</span>
              </button>
            </div>

            {/* Modal Body & Form */}
            <form onSubmit={saveVod} className="flex flex-col flex-1">
              <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-5 overflow-y-auto max-h-[60vh]">
                <div className="md:col-span-2 flex gap-4">
                  <div className="w-28">
                    <label className="block text-sm font-semibold text-gray-700 mb-1.5">Week</label>
                    <input type="number" min="1" className="w-full border border-gray-300 focus:border-teal-500 focus:ring-1 focus:ring-teal-500 rounded-lg p-2.5 text-sm transition" value={vodWeek} onChange={e => setVodWeek(Number(e.target.value))} required />
                  </div>
                  <div className="flex-1">
                    <label className="block text-sm font-semibold text-gray-700 mb-1.5">Title</label>
                    <input type="text" className="w-full border border-gray-300 focus:border-teal-500 focus:ring-1 focus:ring-teal-500 rounded-lg p-2.5 text-sm transition" value={vodTitle} onChange={e => setVodTitle(e.target.value)} required placeholder="강의 제목 입력" />
                  </div>
                </div>
                <div className="md:col-span-2">
                  <label className="block text-sm font-semibold text-gray-700 mb-1.5">YouTube URL</label>
                  <input type="url" className="w-full border border-gray-300 focus:border-teal-500 focus:ring-1 focus:ring-teal-500 rounded-lg p-2.5 text-sm transition" value={vodYoutube} onChange={e => setVodYoutube(e.target.value)} placeholder="https://youtube.com/..." />
                </div>
                <div className="md:col-span-2">
                  <label className="block text-sm font-semibold text-gray-700 mb-1.5">Vimeo URL (Fallback)</label>
                  <input type="url" className="w-full border border-gray-300 focus:border-teal-500 focus:ring-1 focus:ring-teal-500 rounded-lg p-2.5 text-sm transition" value={vodVimeo} onChange={e => setVodVimeo(e.target.value)} placeholder="https://vimeo.com/..." />
                </div>
              </div>

              {/* Modal Footer */}
              <div className="px-6 py-4 border-t border-gray-100 bg-gray-50 flex justify-between items-center mt-auto">
                <div>
                  {vodFormId && (
                    <button type="button" onClick={deleteVod} className="text-red-600 hover:text-red-800 hover:bg-red-50 px-3 py-2 rounded-lg text-sm font-bold transition flex items-center gap-1">
                      <span className="material-icons-outlined" style={{ fontSize: '18px' }}>delete</span>
                      Delete
                    </button>
                  )}
                </div>
                <div className="flex gap-2">
                  <button type="button" onClick={() => setShowVodForm(false)} className="px-5 py-2 border border-gray-300 text-gray-700 bg-white rounded-lg text-sm font-bold hover:bg-gray-50 transition">
                    Cancel
                  </button>
                  <button type="submit" className="px-5 py-2 bg-teal-600 text-white rounded-lg text-sm font-bold hover:bg-teal-700 shadow-sm transition flex items-center gap-2">
                    <span className="material-icons-outlined" style={{ fontSize: '18px' }}>save</span>
                    Save VOD
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}

    </DesktopLayout>
  );
}
