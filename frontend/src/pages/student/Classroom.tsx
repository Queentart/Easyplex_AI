/* ==========================================================
 * Classroom 페이지
 * ----------------------------------------------------------
 * (목업 화면 #11) 공지사항, 커리큘럼 로드맵, 강의 자료, 녹화 강의 썸네일
 * ========================================================== */

import { useEffect, useState } from 'react';
import MobileLayout from '../../components/layout/MobileLayout';
import ProgressBar from '../../components/common/ProgressBar';
import { announcementApi } from '../../api/announcementApi';
import type { Announcement } from '../../api/announcementApi';
import { curriculumApi } from '../../api/curriculumApi';
import type { CurriculumStep } from '../../api/curriculumApi';
import { materialApi } from '../../api/materialApi';
import type { CourseMaterial } from '../../api/materialApi';
import { 
  studentBottomNav
} from '../../data/student';
import { vodService } from '../../api/vodService';
import WeeklyVODBlock from '../../components/common/WeeklyVODBlock';
import './Student.css';

export default function Classroom() {
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [loadingAnnouncements, setLoadingAnnouncements] = useState(true);
  
  const [curriculumRoadmap, setCurriculumRoadmap] = useState<CurriculumStep[]>([]);
  const [loadingCurriculum, setLoadingCurriculum] = useState(true);

  const [materials, setMaterials] = useState<CourseMaterial[]>([]);
  const [loadingMaterials, setLoadingMaterials] = useState(true);
  
  const [isRoadmapExpanded, setIsRoadmapExpanded] = useState(false);
  const [selectedAnnouncement, setSelectedAnnouncement] = useState<Announcement | null>(null);
  
  const [vods, setVods] = useState(vodService.getVODs());

  useEffect(() => {
    const handleStorage = (e: StorageEvent) => {
      if (e.key === 'easyplex_vod_list') {
        setVods(vodService.getVODs());
      }
    };
    window.addEventListener('storage', handleStorage);
    return () => window.removeEventListener('storage', handleStorage);
  }, []);

  const handleDownload = async (e: React.MouseEvent, url: string, filename: string) => {
    e.preventDefault();
    e.stopPropagation();
    try {
      const response = await fetch(`http://localhost:8000${url}`);
      const blob = await response.blob();
      const objectUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = objectUrl;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(objectUrl);
    } catch (error) {
      console.error("Download failed", error);
    }
  };

  useEffect(() => {
    const fetchAnnouncements = async () => {
      try {
        const data = await announcementApi.getStudentAnnouncements();
        setAnnouncements(data);
      } catch (error) {
        console.error('Failed to fetch announcements:', error);
      } finally {
        setLoadingAnnouncements(false);
      }
    };
    
    const fetchCurriculum = async () => {
      try {
        const data = await curriculumApi.getCurriculumSteps();
        setCurriculumRoadmap(data);
      } catch (error) {
        console.error('Failed to fetch curriculum:', error);
      } finally {
        setLoadingCurriculum(false);
      }
    };

    const fetchMaterials = async () => {
      try {
        const data = await materialApi.getMaterials();
        setMaterials(data);
      } catch (error) {
        console.error('Failed to fetch materials:', error);
      } finally {
        setLoadingMaterials(false);
      }
    };

    fetchAnnouncements();
    fetchCurriculum();
    fetchMaterials();
  }, []);

  return (
    <>
      <MobileLayout title="Classroom" bottomNavItems={studentBottomNav}>
      
      {/* ── 강사진 공지사항 ── */}
      <div className="mobile-card">
        <div className="mobile-card__title">
          <span className="material-icons-outlined" style={{ fontSize: 18, color: 'var(--color-primary)' }}>campaign</span>
          공지 사항
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
          {loadingAnnouncements ? (
            <div style={{ fontSize: '14px', color: '#6B7280', padding: '12px' }}>Loading announcements...</div>
          ) : announcements.length === 0 ? (
            <div style={{ fontSize: '14px', color: '#6B7280', padding: '12px' }}>등록된 공지사항이 없습니다.</div>
          ) : (
            announcements.map(ann => (
              <div 
                key={ann.id} 
                onClick={() => setSelectedAnnouncement(ann)}
                style={{
                  padding: '16px',
                  borderRadius: '8px',
                  border: '1px solid',
                  backgroundColor: ann.is_important ? '#FEF2F2' : '#F9FAFB',
                  borderColor: ann.is_important ? '#FEE2E2' : '#F3F4F6',
                  cursor: 'pointer',
                  transition: 'all 0.2s'
                }}
                className="hover:shadow-md"
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flex: 1, wordBreak: 'break-word' }}>
                    {ann.is_important && (
                      <span className="material-icons text-red-500" style={{ fontSize: 16 }}>priority_high</span>
                    )}
                    <h4 
                      className={`text-sm font-semibold ${ann.is_important ? 'text-red-700' : 'text-gray-800'}`}
                      style={{ margin: 0, lineHeight: '1.4' }}
                    >
                      {ann.title}
                    </h4>
                  </div>
                  <span style={{ fontSize: '12px', color: '#6B7280', whiteSpace: 'nowrap', flexShrink: 0 }}>
                    {new Date(ann.created_at).toLocaleDateString()}
                  </span>
                </div>
                <p style={{ 
                  fontSize: '13px', 
                  color: '#4B5563', 
                  marginTop: '8px', 
                  whiteSpace: 'nowrap', 
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  lineHeight: '1.5' 
                }}>
                  {ann.content}
                </p>
                {ann.attachment_url && (
                  <div style={{ marginTop: '12px' }}>
                    <div 
                      className="inline-flex items-center gap-1 bg-white border border-gray-200 text-blue-600 transition shadow-sm"
                      style={{ padding: '6px 12px', borderRadius: '6px', fontSize: '12px', fontWeight: 500 }}
                    >
                      <span className="material-icons-outlined" style={{ fontSize: 16 }}>attach_file</span>
                      첨부파일 포함
                    </div>
                  </div>
                )}
              </div>
            ))
          )}
        </div>
      </div>

      <div className="mobile-card">
        <div className="mobile-card__title" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span className="material-icons-outlined" style={{ fontSize: 18, color: 'var(--color-primary)' }}>route</span>
            학습 커리큘럼 로드맵
          </div>
          <button 
            onClick={() => setIsRoadmapExpanded(!isRoadmapExpanded)}
            style={{ fontSize: '12px', color: 'var(--color-primary)', background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
          >
            {isRoadmapExpanded ? '간략히 보기' : '자세히 보기'}
            <span className="material-icons" style={{ fontSize: 14 }}>
              {isRoadmapExpanded ? 'expand_less' : 'expand_more'}
            </span>
          </button>
        </div>
        <div className="roadmap">
          {loadingCurriculum ? (
            <div className="text-sm text-gray-500 p-3">Loading curriculum...</div>
          ) : curriculumRoadmap.length === 0 ? (
            <div className="text-sm text-gray-500 p-3">등록된 커리큘럼이 없습니다.</div>
          ) : (
            (() => {
              const now = new Date();
              const processedRoadmap = curriculumRoadmap.map((step, index, arr) => {
                let computedStatus = step.status; 
                if (step.starts_date && step.starts_date !== '미정') {
                  const dateStr = step.starts_date.replace(/\./g, '-');
                  const startDate = new Date(dateStr);
                  if (!isNaN(startDate.getTime())) {
                    let nextStartDate = null;
                    for (let i = index + 1; i < arr.length; i++) {
                      const nextStr = arr[i].starts_date?.replace(/\./g, '-');
                      if (nextStr && nextStr !== '미정') {
                        const d = new Date(nextStr);
                        if (!isNaN(d.getTime())) {
                          nextStartDate = d;
                          break;
                        }
                      }
                    }
                    if (nextStartDate && now >= nextStartDate) {
                      computedStatus = 'completed';
                    } else if (now >= startDate) {
                      computedStatus = 'current';
                    } else {
                      computedStatus = 'upcoming';
                    }
                  }
                }
                return { ...step, computedStatus };
              });

              let displayRoadmap = isRoadmapExpanded 
                ? processedRoadmap 
                : processedRoadmap.filter(s => s.computedStatus === 'current' || s.computedStatus === 'upcoming').slice(0, 4);

              if (!isRoadmapExpanded && displayRoadmap.length === 0 && processedRoadmap.length > 0) {
                  displayRoadmap = processedRoadmap.slice(-3);
              }

              return displayRoadmap.map(step => (
                <div key={step.id} className="roadmap-item">
                  <div className={`roadmap-item__icon roadmap-item__icon--${step.computedStatus}`}>
                    <span className="material-icons" style={{ fontSize: 16 }}>
                      {step.computedStatus === 'completed' ? 'check' : step.computedStatus === 'current' ? 'play_arrow' : 'schedule'}
                    </span>
                  </div>
                  <div className="roadmap-item__content">
                    <div className="roadmap-item__title">{step.title}</div>
                    <div className="roadmap-item__subtitle">
                      {step.computedStatus === 'completed' && step.starts_date && `Started: ${step.starts_date}`}
                      {step.computedStatus === 'current' && (
                        <div style={{ marginTop: 'var(--space-2)' }}>
                          <div style={{ fontSize: '11px', color: 'var(--color-primary)', fontWeight: 600, marginBottom: '4px' }}>In Progress ({step.starts_date})</div>
                          <ProgressBar value={step.progress || 0} size="sm" />
                        </div>
                      )}
                      {step.computedStatus === 'upcoming' && step.starts_date && `Starts: ${step.starts_date}`}
                    </div>
                  </div>
                </div>
              ));
            })()
          )}
        </div>
      </div>

      {/* ── 강의 자료 (Lecture Materials) ── */}
      <div className="mobile-card">
        <div className="mobile-card__title">
          <span className="material-icons-outlined" style={{ fontSize: 18, color: 'var(--color-primary)' }}>folder</span>
          강의 자료
        </div>
        <div className="flex flex-col gap-2 mt-2">
          {loadingMaterials ? (
            <div className="text-sm text-gray-500 p-3">Loading materials...</div>
          ) : materials.length === 0 ? (
            <div className="text-sm text-gray-500 p-3">등록된 강의 자료가 없습니다.</div>
          ) : (
            materials.map(mat => {
              const t = (mat.file_type || '').toLowerCase();
              let icon = 'insert_drive_file';
              if (['pdf'].includes(t)) icon = 'picture_as_pdf';
              if (['xls', 'xlsx', 'csv'].includes(t)) icon = 'table_chart';
              if (['ppt', 'pptx'].includes(t)) icon = 'slideshow';
              if (['jpg', 'jpeg', 'png', 'gif'].includes(t)) icon = 'image';
              if (['mp4', 'avi', 'mkv'].includes(t)) icon = 'video_file';
              if (['zip', 'rar', 'tar', 'gz'].includes(t)) icon = 'folder_zip';
              if (['py', 'js', 'ts', 'html', 'css', 'json'].includes(t)) icon = 'code';
              
              const formatFileSize = (bytes: number) => {
                if (!bytes) return '0 B';
                const k = 1024;
                const sizes = ['B', 'KB', 'MB', 'GB'];
                const i = Math.floor(Math.log(bytes) / Math.log(k));
                return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
              };

              return (
                <a 
                  key={mat.id} 
                  href={`http://localhost:8000${mat.file_url}`}
                  onClick={(e) => handleDownload(e, mat.file_url, mat.file_name)}
                  className="flex items-center gap-3 p-3 rounded border border-gray-200 bg-white hover:bg-gray-50 transition cursor-pointer"
                >
                  <span className="material-icons-outlined text-gray-400" style={{ fontSize: 24 }}>{icon}</span>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium text-gray-800 truncate">{mat.title}</div>
                    <div className="text-xs text-gray-500 mt-0.5 truncate">
                      {mat.created_at ? new Date(mat.created_at).toLocaleDateString() : 'N/A'} • {formatFileSize(mat.file_size)}
                    </div>
                  </div>
                  <span className="material-icons-outlined text-blue-500 flex-shrink-0" style={{ fontSize: 20 }}>download</span>
                </a>
              );
            })
          )}
        </div>
      </div>

      {/* ── 녹화 강의 목록 (VOD 썸네일 형식) ── */}
      {vods.length > 0 && (
        <WeeklyVODBlock 
          title="지난 강의 영상" 
          icon="video_library" 
          lectures={vods} 
        />
      )}

    </MobileLayout>

      {/* ── 공지사항 상세 모달 ── */}
      {selectedAnnouncement && (
        <div 
          className="fixed inset-0 flex items-center justify-center z-[9999] p-4"
          style={{ backgroundColor: 'rgba(0, 0, 0, 0.3)', backdropFilter: 'blur(4px)' }}
          onClick={() => setSelectedAnnouncement(null)}
        >
          <div 
            className="bg-white rounded-xl shadow-xl w-full max-w-md max-h-[80vh] flex flex-col"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="p-4 border-b border-gray-100 flex justify-between items-center bg-gray-50 rounded-t-xl">
              <div className="flex items-center gap-2">
                {selectedAnnouncement.is_important && (
                  <span className="material-icons text-red-500" style={{ fontSize: 20 }}>priority_high</span>
                )}
                <h3 className="font-bold text-gray-800 truncate pr-2">{selectedAnnouncement.title}</h3>
              </div>
              <button 
                onClick={() => setSelectedAnnouncement(null)}
                className="text-gray-400 hover:text-gray-600 bg-transparent border-none cursor-pointer"
              >
                <span className="material-icons">close</span>
              </button>
            </div>
            
            <div className="p-5 overflow-y-auto">
              <div className="text-xs text-gray-500 mb-4 pb-2 border-b border-gray-100">
                게시일: {new Date(selectedAnnouncement.created_at).toLocaleString()}
              </div>
              <p className="text-sm text-gray-700 whitespace-pre-wrap break-words leading-relaxed mb-6">
                {selectedAnnouncement.content}
              </p>
              
              {selectedAnnouncement.attachment_url && (
                <div className="mt-4 p-3 bg-gray-50 rounded-lg border border-gray-200">
                  <div className="text-xs font-semibold text-gray-600 mb-2">첨부파일</div>
                  <button 
                    onClick={(e) => handleDownload(e, selectedAnnouncement.attachment_url!, selectedAnnouncement.attachment_name || 'download')}
                    className="flex items-center gap-2 w-full bg-white border border-gray-300 hover:border-blue-400 hover:bg-blue-50 text-blue-600 p-3 rounded-lg transition-colors cursor-pointer text-left"
                  >
                    <span className="material-icons-outlined text-blue-500">file_download</span>
                    <span className="text-sm font-medium truncate flex-1">
                      {selectedAnnouncement.attachment_name || '첨부파일 다운로드'}
                    </span>
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </>
  );
}
