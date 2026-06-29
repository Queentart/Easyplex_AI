import React, { useState, useMemo } from 'react';
import type { RecordedLecture } from '../../types';

interface WeeklyVODBlockProps {
  title: string;
  icon: string;
  lectures: RecordedLecture[];
}

interface WeekGroup {
  weekNumber: number;
  latestThumbnail?: string;
  lectures: RecordedLecture[];
}

export default function WeeklyVODBlock({ title, icon, lectures }: WeeklyVODBlockProps) {
  const [selectedWeek, setSelectedWeek] = useState<number | null>(null);

  // Group lectures by week
  const groupedWeeks = useMemo(() => {
    const groups: Record<number, WeekGroup> = {};

    lectures.forEach(lecture => {
      // Default to week 1 if no week is provided
      const weekNum = lecture.week || 1;
      
      if (!groups[weekNum]) {
        groups[weekNum] = {
          weekNumber: weekNum,
          lectures: [],
        };
      }
      groups[weekNum].lectures.push(lecture);
    });

    // Sort weeks descending (latest week first)
    const sortedWeeks = Object.values(groups).sort((a, b) => b.weekNumber - a.weekNumber);

    // Sort lectures within each week and find the latest thumbnail
    sortedWeeks.forEach(group => {
      // Sort lectures by date descending (assuming date string is sortable like 'Sep 20', 'Sep 19')
      group.lectures.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
      
      // The latest thumbnail is the thumbnail of the most recent video
      const latestLectureWithThumbnail = group.lectures.find(l => l.thumbnail);
      group.latestThumbnail = latestLectureWithThumbnail?.thumbnail;
    });

    return sortedWeeks;
  }, [lectures]);

  return (
    <div className="mobile-card relative overflow-hidden">
      {/* ── Header ── */}
      <div className="mobile-card__title flex justify-between items-center">
        <div className="flex items-center gap-2">
          <span className="material-icons-outlined" style={{ fontSize: 18, color: 'var(--color-primary)' }}>{icon}</span>
          {title}
        </div>
        
        {selectedWeek === null ? (
          <button 
            className="flex items-center gap-1 text-xs font-medium text-gray-500 hover:text-blue-600 transition"
          >
            전체 보기
            <span className="material-icons" style={{ fontSize: 14 }}>chevron_right</span>
          </button>
        ) : (
          <button 
            onClick={() => setSelectedWeek(null)}
            className="flex items-center gap-1 text-xs font-medium text-blue-600 hover:text-blue-800 transition"
          >
            <span className="material-icons" style={{ fontSize: 14 }}>arrow_back</span>
            뒤로 가기
          </button>
        )}
      </div>

      {/* ── Content Area ── */}
      <div className="mt-4 grid">
        {/* ==============================================
            VIEW 1: 주차별 그리드 뷰 (Week Grid View)
        ============================================== */}
        <div 
          className="col-start-1 row-start-1 transition-all duration-300"
          style={{ 
            opacity: selectedWeek === null ? 1 : 0, 
            transform: selectedWeek === null ? 'translateX(0)' : 'translateX(-20px)',
            pointerEvents: selectedWeek === null ? 'auto' : 'none',
            visibility: selectedWeek === null ? 'visible' : 'hidden'
          }}
        >
          <div className="grid grid-cols-2 gap-4 pb-2">
            {groupedWeeks.map(group => (
              <div 
                key={group.weekNumber} 
                onClick={() => setSelectedWeek(group.weekNumber)}
                className="group block overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow-md transition cursor-pointer"
              >
                <div className="aspect-video bg-gray-100 relative overflow-hidden">
                  {group.latestThumbnail ? (
                    <img 
                      src={group.latestThumbnail} 
                      alt={`${group.weekNumber}주차 강의`} 
                      className="w-full h-full object-cover group-hover:scale-105 transition duration-300" 
                    />
                  ) : (
                    <div className="w-full h-full flex flex-col items-center justify-center text-gray-400 group-hover:scale-105 transition duration-300">
                      <span className="material-icons" style={{ fontSize: 48 }}>folder</span>
                      <span className="text-xs mt-2">No Thumbnail</span>
                    </div>
                  )}
                  {/* 영상 개수 뱃지 */}
                  <div className="absolute top-2 right-2 bg-black/70 text-white text-[10px] px-2 py-0.5 rounded-full font-medium flex items-center gap-1">
                    <span className="material-icons" style={{ fontSize: 12 }}>play_circle</span>
                    {group.lectures.length}
                  </div>
                </div>
                <div className="p-3">
                  <h4 className="font-semibold text-sm text-gray-900 leading-tight">
                    Week {group.weekNumber} 강의
                  </h4>
                  <p className="text-xs text-gray-500 mt-1">
                    최신 업데이트: {group.lectures[0]?.date || 'N/A'}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* ==============================================
            VIEW 2: 해당 주차의 개별 영상 리스트 뷰 (Detail View)
        ============================================== */}
        <div 
          className="col-start-1 row-start-1 transition-all duration-300"
          style={{ 
            opacity: selectedWeek !== null ? 1 : 0, 
            transform: selectedWeek !== null ? 'translateX(0)' : 'translateX(20px)',
            pointerEvents: selectedWeek !== null ? 'auto' : 'none',
            visibility: selectedWeek !== null ? 'visible' : 'hidden'
          }}
        >
          {selectedWeek !== null && (
            <div className="flex flex-col gap-3 pb-2 pr-1">
              <div className="text-sm font-semibold text-gray-800 mb-1">
                Week {selectedWeek} 상세 목록
              </div>
              {groupedWeeks.find(g => g.weekNumber === selectedWeek)?.lectures.map(lecture => {
                const targetUrl = lecture.youtubeUrl || lecture.vimeoUrl || lecture.url || '#';
                return (
                <a 
                  key={lecture.id} 
                  href={targetUrl} 
                  target="_blank" 
                  rel="noreferrer"
                  className="flex items-center gap-3 p-2 rounded-lg border border-gray-100 bg-gray-50 hover:bg-blue-50 hover:border-blue-100 transition group"
                >
                  <div className="w-24 aspect-video bg-gray-200 rounded overflow-hidden shrink-0 relative">
                    {lecture.thumbnail ? (
                       <img src={lecture.thumbnail} alt={lecture.title} className="w-full h-full object-cover" />
                    ) : (
                       <div className="w-full h-full flex items-center justify-center text-gray-400">
                         <span className="material-icons" style={{ fontSize: 20 }}>movie</span>
                       </div>
                    )}
                    {lecture.watchedProgress !== undefined && (
                      <div className="absolute bottom-0 left-0 w-full h-1 bg-gray-300">
                        <div className="h-full bg-red-500" style={{ width: `${lecture.watchedProgress}%` }} />
                      </div>
                    )}
                  </div>
                  <div className="flex-1 min-w-0 py-1">
                    <h4 className="font-medium text-xs text-gray-900 line-clamp-2 leading-snug group-hover:text-blue-700 transition">
                      {lecture.title}
                    </h4>
                    <div className="text-[10px] text-gray-500 mt-1 flex items-center gap-1">
                      <span className="material-icons" style={{ fontSize: 10 }}>calendar_today</span>
                      {lecture.date}
                      <span className="mx-1">·</span>
                      <span className="material-icons" style={{ fontSize: 10 }}>schedule</span>
                      {lecture.duration}
                    </div>
                  </div>
                </a>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
