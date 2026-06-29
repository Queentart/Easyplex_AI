import { useState, useEffect } from 'react';
import MobileLayout from '../../components/layout/MobileLayout';
import { studentBottomNav } from '../../data/student';
import { vodService } from '../../api/vodService';
import WeeklyVODBlock from '../../components/common/WeeklyVODBlock';
import { curriculumApi } from '../../api/curriculumApi';
import { attendanceApi } from '../../api/attendanceApi';
import type { AttendanceStats } from '../../api/attendanceApi';
import SettingsModal from '../../components/common/SettingsModal';
import AttendanceQRModal from '../../components/common/AttendanceQRModal';
import { streamLinkService } from '../../api/streamLinkService';
import type { TodaySession } from '../../api/streamLinkService';
import './Student.css';

export default function Home() {
  const [currentStream, setCurrentStream] = useState<TodaySession | null>(() => streamLinkService.getTodayStream());
  const [currentSchedules, setCurrentSchedules] = useState<{id: number, time: string, title: string}[]>([]);
  const [loadingSchedule, setLoadingSchedule] = useState(true);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isQROpen, setIsQROpen] = useState(false);
  const [attendance, setAttendance] = useState<AttendanceStats | null>(null);
  const [vods, setVods] = useState(vodService.getVODs());

  useEffect(() => {
    const handleStorage = (e: StorageEvent) => {
      if (e.key === 'easyplex_stream_link_v1') {
        setCurrentStream(streamLinkService.getTodayStream());
      }
      if (e.key === 'easyplex_vod_list') {
        setVods(vodService.getVODs());
      }
    };
    window.addEventListener('storage', handleStorage);

    // 오늘의 일정 가져오기
    const fetchTodaySchedule = async () => {
      try {
        const now = new Date();
        const data = await curriculumApi.getCurriculumSteps();
        
        const currentItems = data.map((step, index, arr) => {
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
        }).filter(item => item.computedStatus === 'current');

        const schedules = currentItems.map(item => ({
          id: item.id,
          time: '오늘의 학습',
          title: item.title
        }));
        setCurrentSchedules(schedules);
      } catch (err) {
        console.error('Failed to fetch schedule for today', err);
      } finally {
        setLoadingSchedule(false);
      }
    };
    
    const fetchAttendanceStats = async () => {
      try {
        const stats = await attendanceApi.getStudentStats();
        setAttendance(stats);
      } catch (err) {
        console.error('Failed to fetch attendance stats', err);
      }
    };
    
    fetchTodaySchedule();
    fetchAttendanceStats();

    return () => window.removeEventListener('storage', handleStorage);
  }, []);

  return (
    <MobileLayout
      title="AcademiaAI"
      bottomNavItems={studentBottomNav}
      headerExtraIcons={[{ icon: 'settings', onClick: () => setIsSettingsOpen(true) }]}
    >
      {/* ── 출석 QR 위젯 ── */}
      <div className="qr-widget" onClick={() => setIsQROpen(true)} style={{ cursor: 'pointer' }}>
        <div className="qr-placeholder">
          <span className="material-icons" style={{ fontSize: 40, opacity: 0.8 }}>qr_code_2</span>
        </div>
        <div className="qr-info">
          <div className="qr-info__title">출석 체크</div>
          <div className="qr-info__subtitle">QR 코드를 스캔하세요</div>
        </div>
      </div>

      {/* ── 온라인 강의 접속 (TechOps 연동) ── */}
      <div className="mobile-card">
        <div className="mobile-card__title">
          <span className="material-icons-outlined" style={{ fontSize: 18, color: 'var(--color-primary)' }}>cast_for_education</span>
          실시간 강의 접속
        </div>
        <div className="flex flex-col gap-3 mt-3">
          {currentStream?.status === 'Live' ? (
            <>
              {currentStream.zoomUrl && (
                <a 
                  href={currentStream.zoomUrl} 
                  target="_blank" 
                  rel="noreferrer" 
                  className="flex items-center gap-3 p-3 rounded-md bg-blue-50 border border-blue-100 hover:bg-blue-100 transition"
                >
                  <div className="w-10 h-10 rounded-full bg-blue-500 text-white flex items-center justify-center shrink-0">
                    <span className="material-icons">videocam</span>
                  </div>
                  <div className="flex-1">
                    <div className="text-sm font-semibold text-gray-800">Zoom Meeting Link</div>
                    <div className="text-xs text-blue-600">Join today's live session</div>
                  </div>
                </a>
              )}
              {currentStream.youtubeUrl && (
                <a 
                  href={currentStream.youtubeUrl} 
                  target="_blank" 
                  rel="noreferrer" 
                  className="flex items-center gap-3 p-3 rounded-md bg-red-50 border border-red-100 hover:bg-red-100 transition"
                >
                  <div className="w-10 h-10 rounded-full bg-red-500 text-white flex items-center justify-center shrink-0">
                    <span className="material-icons">play_arrow</span>
                  </div>
                  <div className="flex-1">
                    <div className="text-sm font-semibold text-gray-800">YouTube Live</div>
                    <div className="text-xs text-red-600">{currentStream.title}</div>
                  </div>
                </a>
              )}
              {currentStream.vimeoUrl && (
                <a 
                  href={currentStream.vimeoUrl} 
                  target="_blank" 
                  rel="noreferrer" 
                  className="flex items-center gap-3 p-3 rounded-md bg-sky-50 border border-sky-100 hover:bg-sky-100 transition"
                >
                  <div className="w-10 h-10 rounded-full bg-sky-500 text-white flex items-center justify-center shrink-0">
                    <span className="material-icons">movie</span>
                  </div>
                  <div className="flex-1">
                    <div className="text-sm font-semibold text-gray-800">Vimeo Live (Backup)</div>
                    <div className="text-xs text-sky-600">{currentStream.title}</div>
                  </div>
                </a>
              )}
            </>
          ) : (
            <div className="text-sm text-gray-500 text-center py-4 bg-gray-50 rounded-md">
              현재 진행 중인 라이브 강의가 없습니다.
            </div>
          )}
        </div>
      </div>

      {/* ── 이전 강의 (VOD 썸네일) ── */}
      {vods.length > 0 && (
        <WeeklyVODBlock 
          title="이전 강의 보기" 
          icon="video_library" 
          lectures={vods} 
        />
      )}

      {/* ── 출석 통계 (이번 달) ── */}
      <div className="mobile-card">
        <div className="mobile-card__title">
          <span className="material-icons-outlined" style={{ fontSize: 18, color: 'var(--color-primary)' }}>calendar_today</span>
          참여율({new Date().getMonth() + 1}월)
        </div>
        <div className="attendance-grid">
          <div className="attendance-stat">
            <div className="attendance-stat__value">{attendance?.lates ?? 0}</div>
            <div className="attendance-stat__label">Lates</div>
          </div>
          <div className="attendance-stat">
            <div className="attendance-stat__value">{attendance?.absences ?? 0}</div>
            <div className="attendance-stat__label">Absences</div>
          </div>
          <div className="attendance-stat">
            <div className="attendance-stat__value">{attendance?.earlyLeaves ?? 0}</div>
            <div className="attendance-stat__label">Early Leaves</div>
          </div>
          <div className="attendance-stat">
            <div className={`attendance-stat__value ${attendance && attendance.rate >= 80 ? 'attendance-stat__value--safe' : 'text-red-500 font-bold'}`}>
              {attendance?.rate ?? 0}%
            </div>
            <div className="attendance-stat__label">Rate ({attendance && attendance.rate >= 80 ? 'Safe' : 'Warning'})</div>
          </div>
        </div>
      </div>

      {/* ── 오늘 일정 ── */}
      <div className="mobile-card">
        <div className="mobile-card__title">
          <span className="material-icons-outlined" style={{ fontSize: 18, color: 'var(--color-primary)' }}>event</span>
          오늘 일정
        </div>
        {loadingSchedule ? (
          <div className="text-sm text-gray-500 p-3">일정을 불러오는 중입니다...</div>
        ) : currentSchedules.length === 0 ? (
          <div className="text-sm text-gray-500 p-3">오늘 진행 중인 일정이 없습니다.</div>
        ) : (
          currentSchedules.map(item => (
            <div key={item.id} className="schedule-item">
              <span className="schedule-item__time">
                {item.time}
              </span>
              <span className="schedule-item__title">
                {item.title}
              </span>
            </div>
          ))
        )}
      </div>

      <SettingsModal isOpen={isSettingsOpen} onClose={() => setIsSettingsOpen(false)} />
      <AttendanceQRModal isOpen={isQROpen} onClose={() => setIsQROpen(false)} />
    </MobileLayout>
  );
}
