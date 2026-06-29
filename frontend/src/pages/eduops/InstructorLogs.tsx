import { useState, useEffect } from 'react';
import type { ComponentProps } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import DataTable from '../../components/common/Table';
import { opsUser, opsMenu } from '../../data/eduops';
import { apiClient } from '../../api/client';
import { trainingLogService } from '../../api/trainingLogService';
import type { TrainingLogData } from '../../api/trainingLogService';
import { mentoringLogService } from '../../api/mentoringLogService';
import type { MentoringLogData, SpecialTag } from '../../api/mentoringLogService';
import './EduOps.css';

interface MaterialLog {
  id: number;
  title: string;
  uploaded_by: string;
  created_at: string;
}

export default function InstructorLogs() {
  const [activeTab, setActiveTab] = useState('Course Materials');
  const [materials, setMaterials] = useState<MaterialLog[]>([]);
  const [trainingLogs, setTrainingLogs] = useState<TrainingLogData[]>([]);
  const [mentoringLogs, setMentoringLogs] = useState<MentoringLogData[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  // Accordion state for Training Logs
  const [expandedMonths, setExpandedMonths] = useState<Record<string, boolean>>({});
  const [expandedLogs, setExpandedLogs] = useState<Record<string, boolean>>({});

  // Accordion state for Mentoring Logs
  const [expandedMentoringMonths, setExpandedMentoringMonths] = useState<Record<string, boolean>>({});
  const [expandedMentoringLogs, setExpandedMentoringLogs] = useState<Record<string, boolean>>({});

  useEffect(() => {
    const fetchData = async () => {
      setIsLoading(true);
      try {
        if (activeTab === 'Course Materials') {
          const res = await apiClient.get('/ops/logs/materials');
          setMaterials(res.data);
        } else if (activeTab === 'Training Logs') {
          setTrainingLogs(trainingLogService.getLogs());
          
          const logs = trainingLogService.getLogs();
          if (logs.length > 0) {
            const latestMonth = logs[0].trainingDate.substring(0, 7);
            setExpandedMonths({ [latestMonth]: true });
          }
        } else if (activeTab === 'Mentoring Logs') {
          setMentoringLogs(mentoringLogService.getLogs());
          
          const logs = mentoringLogService.getLogs();
          if (logs.length > 0) {
            let month = logs[0].entries[0]?.date.substring(0, 7).replace('.', '-');
            if (!month || !month.includes('-')) {
              month = logs[0].createdAt.substring(0, 7);
            }
            setExpandedMentoringMonths({ [month]: true });
          }
        }
      } catch (error) {
        console.error('Failed to fetch logs', error);
      } finally {
        setIsLoading(false);
      }
    };
    fetchData();
  }, [activeTab]);

  const materialColumns = [
    { key: 'id', header: 'ID' },
    { key: 'title', header: 'TITLE' },
    { key: 'uploaded_by', header: 'INSTRUCTOR' },
    { key: 'created_at', header: 'UPLOAD DATE', render: (val: string) => new Date(val).toLocaleDateString() },
    { key: 'action', header: 'ACTION', render: () => <button className="btn btn-outline btn-sm">Download</button> }
  ];

  // Group logs by month
  const groupedLogs = trainingLogs.reduce((acc, log) => {
    const month = log.trainingDate.substring(0, 7); // '2026-06'
    if (!acc[month]) acc[month] = [];
    acc[month].push(log);
    return acc;
  }, {} as Record<string, TrainingLogData[]>);

  const toggleMonth = (month: string) => {
    setExpandedMonths(prev => ({ ...prev, [month]: !prev[month] }));
  };

  const toggleLog = (logId: string) => {
    setExpandedLogs(prev => ({ ...prev, [logId]: !prev[logId] }));
  };

  const renderLogDetails = (log: TrainingLogData) => (
    <div style={{ marginTop: '1rem', borderTop: '1px solid var(--color-border)', paddingTop: '1rem' }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1rem' }}>
        <div>
          <p style={{ fontSize: '0.85rem', color: 'var(--color-text-secondary)', marginBottom: '0.25rem' }}>훈련과정</p>
          <p style={{ fontWeight: 500, color: 'var(--color-text-primary)' }}>{log.courseName}</p>
        </div>
        <div>
          <p style={{ fontSize: '0.85rem', color: 'var(--color-text-secondary)', marginBottom: '0.25rem' }}>훈련기간</p>
          <p style={{ fontWeight: 500, color: 'var(--color-text-primary)' }}>{log.coursePeriod}</p>
        </div>
      </div>
      
      <div style={{ display: 'flex', gap: '1.5rem', marginBottom: '1.5rem', backgroundColor: 'var(--color-bg-alt)', padding: '1rem', borderRadius: '4px', flexWrap: 'wrap' }}>
        <div style={{ textAlign: 'center', flex: 1 }}>
          <p style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>총원</p>
          <p style={{ fontWeight: 'bold', fontSize: '1.1rem', color: 'var(--color-text-primary)' }}>{log.attendance.total}</p>
        </div>
        <div style={{ textAlign: 'center', flex: 1 }}>
          <p style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>출석</p>
          <p style={{ fontWeight: 'bold', fontSize: '1.1rem', color: 'var(--color-success)' }}>{log.attendance.present}</p>
        </div>
        <div style={{ textAlign: 'center', flex: 1 }}>
          <p style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>결석</p>
          <p style={{ fontWeight: 'bold', fontSize: '1.1rem', color: 'var(--color-danger)' }}>{log.attendance.absent}</p>
        </div>
        <div style={{ textAlign: 'center', flex: 1 }}>
          <p style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>지각</p>
          <p style={{ fontWeight: 'bold', fontSize: '1.1rem', color: 'var(--color-warning)' }}>{log.attendance.late}</p>
        </div>
        <div style={{ textAlign: 'center', flex: 1 }}>
          <p style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>외출</p>
          <p style={{ fontWeight: 'bold', fontSize: '1.1rem', color: 'var(--color-warning)' }}>{log.attendance.out}</p>
        </div>
        <div style={{ textAlign: 'center', flex: 1 }}>
          <p style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>조퇴</p>
          <p style={{ fontWeight: 'bold', fontSize: '1.1rem', color: 'var(--color-warning)' }}>{log.attendance.earlyLeave}</p>
        </div>
      </div>

      <div className="table-responsive" style={{ marginBottom: '1.5rem' }}>
        <table className="data-table" style={{ width: '100%', fontSize: '0.9rem' }}>
          <thead>
            <tr>
              <th style={{ width: '60px', textAlign: 'center' }}>교시</th>
              <th>교과목</th>
              <th style={{ width: '100px' }}>강사</th>
              <th>교육내용</th>
              <th>비고</th>
            </tr>
          </thead>
          <tbody>
            {log.schedule.map(cls => (
              <tr key={cls.period}>
                <td style={{ textAlign: 'center', fontWeight: 500 }}>{cls.period}</td>
                <td>{cls.subject}</td>
                <td>{cls.instructorName}</td>
                <td>{cls.content}</td>
                <td>{cls.notes}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
        <div style={{ backgroundColor: '#f9fafb', padding: '1rem', borderRadius: '4px', border: '1px solid #e5e7eb' }}>
          <h4 style={{ fontSize: '0.9rem', fontWeight: 600, marginBottom: '0.5rem', color: '#374151' }}>지시사항 (과제 등)</h4>
          <p style={{ fontSize: '0.9rem', color: '#4b5563', whiteSpace: 'pre-wrap', margin: 0 }}>{log.instructions || '없음'}</p>
        </div>
        <div style={{ backgroundColor: '#fdf2f8', padding: '1rem', borderRadius: '4px', border: '1px solid #fbcfe8' }}>
          <h4 style={{ fontSize: '0.9rem', fontWeight: 600, marginBottom: '0.5rem', color: '#9d174d' }}>특기사항 &lt;결석자 명단 포함&gt;</h4>
          <p style={{ fontSize: '0.9rem', color: '#be185d', whiteSpace: 'pre-wrap', margin: 0 }}>{log.specialNotes || '없음'}</p>
        </div>
      </div>
    </div>
  );

  const renderTrainingLogs = () => {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        {Object.keys(groupedLogs).sort().reverse().map(month => (
          <Card key={month} compact>
            <div 
              onClick={() => toggleMonth(month)}
              style={{ 
                display: 'flex', 
                justifyContent: 'space-between', 
                alignItems: 'center', 
                padding: '1rem 1.5rem', 
                cursor: 'pointer',
                backgroundColor: 'var(--color-bg-alt)'
              }}
            >
              <h2 style={{ fontSize: '1.2rem', fontWeight: 600, color: 'var(--color-text-primary)', margin: 0 }}>
                {month.split('-')[0]}년 {month.split('-')[1]}월 학습 일지
              </h2>
              <span className="material-icons-outlined" style={{ color: 'var(--color-text-secondary)' }}>
                {expandedMonths[month] ? 'expand_less' : 'expand_more'}
              </span>
            </div>
            
            {expandedMonths[month] && (
              <div style={{ padding: '0 1.5rem 1.5rem 1.5rem' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', marginTop: '1rem' }}>
                  {groupedLogs[month].map(log => (
                    <div key={log.id} style={{ border: '1px solid var(--color-border)', borderRadius: '8px', padding: '1.5rem' }}>
                      <div 
                        style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }}
                        onClick={() => toggleLog(log.id)}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                          <span style={{ fontSize: '1.1rem', fontWeight: 600, color: 'var(--color-text-primary)' }}>{log.trainingDate}</span>
                          <span style={{ padding: '0.25rem 0.75rem', backgroundColor: '#e0e7ff', color: '#4338ca', borderRadius: '16px', fontSize: '0.85rem', fontWeight: 500 }}>
                            제{log.trainingDayNumber}일차
                          </span>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                          <span style={{ color: 'var(--color-text-secondary)', fontSize: '0.9rem' }}>출석률: {Math.round((log.attendance.present / log.attendance.total) * 100)}%</span>
                          <span className="material-icons-outlined" style={{ color: 'var(--color-text-secondary)' }}>
                            {expandedLogs[log.id] ? 'expand_less' : 'expand_more'}
                          </span>
                        </div>
                      </div>
                      
                      {expandedLogs[log.id] && renderLogDetails(log)}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </Card>
        ))}
        {Object.keys(groupedLogs).length === 0 && (
           <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--color-text-secondary)' }}>
             작성된 학습 일지가 없습니다.
           </div>
        )}
      </div>
    );
  };

  const TAG_OPTIONS: { value: SpecialTag, label: string, color: string, bg: string }[] = [
    { value: 'none', label: '선택 안함', color: '#64748b', bg: '#f1f5f9' },
    { value: 'intensive_care', label: '집중관리 필요', color: '#c2410c', bg: '#ffedd5' },
    { value: 'suspicious', label: '요주의 인물', color: '#b91c1c', bg: '#fee2e2' },
    { value: 'excellent', label: '우수/전공자', color: '#15803d', bg: '#dcfce7' }
  ];

  const renderTag = (tag: SpecialTag) => {
    const option = TAG_OPTIONS.find(o => o.value === tag);
    if (!option || option.value === 'none') return null;
    return (
      <span style={{ 
        display: 'inline-block',
        padding: '0.2rem 0.5rem', 
        backgroundColor: option.bg, 
        color: option.color, 
        borderRadius: '12px', 
        fontSize: '0.75rem', 
        fontWeight: 600,
        whiteSpace: 'nowrap',
        border: `1px solid ${option.color}30`
      }}>
        {option.label}
      </span>
    );
  };

  const renderMentoringLogDetails = (log: MentoringLogData) => (
    <div style={{ marginTop: '1rem', borderTop: '1px solid var(--color-border)', paddingTop: '1rem' }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '1.5rem', backgroundColor: '#f8fafc', padding: '1rem', borderRadius: '8px' }}>
        <div>
          <p style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)', marginBottom: '0.2rem' }}>훈련과정</p>
          <p style={{ fontWeight: 500, color: 'var(--color-text-primary)', fontSize: '0.9rem' }}>{log.courseName}</p>
        </div>
        <div>
          <p style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)', marginBottom: '0.2rem' }}>교과목</p>
          <p style={{ fontWeight: 500, color: 'var(--color-text-primary)', fontSize: '0.9rem' }}>{log.subject}</p>
        </div>
        <div>
          <p style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)', marginBottom: '0.2rem' }}>전체기간</p>
          <p style={{ fontWeight: 500, color: 'var(--color-text-primary)', fontSize: '0.9rem' }}>{log.coursePeriod}</p>
        </div>
        <div>
          <p style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)', marginBottom: '0.2rem' }}>멘토(강사)</p>
          <p style={{ fontWeight: 500, color: 'var(--color-text-primary)', fontSize: '0.9rem' }}>{log.tutorName}</p>
        </div>
      </div>

      <div className="table-responsive">
        <table className="data-table" style={{ width: '100%', fontSize: '0.9rem' }}>
          <thead>
            <tr>
              <th style={{ width: '100px' }}>일자</th>
              <th style={{ width: '80px' }}>멘토명</th>
              <th style={{ width: '100px' }}>훈련생명</th>
              <th style={{ width: '80px' }}>구분</th>
              <th style={{ width: '150px' }}>주제</th>
              <th>내용</th>
              <th style={{ width: '150px' }}>특이사항</th>
            </tr>
          </thead>
          <tbody>
            {log.entries.map((entry, idx) => (
              <tr key={idx}>
                <td>{entry.date}</td>
                <td>{entry.tutorName}</td>
                <td style={{ fontWeight: 500 }}>{entry.traineeName}</td>
                <td>
                  <span style={{ padding: '0.2rem 0.5rem', backgroundColor: '#e2e8f0', borderRadius: '4px', fontSize: '0.8rem' }}>{entry.category}</span>
                </td>
                <td>{entry.topic}</td>
                <td>{entry.content}</td>
                <td>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem', alignItems: 'flex-start' }}>
                    {renderTag(entry.tag)}
                    {entry.specialNotes && <span style={{ fontSize: '0.85rem' }}>{entry.specialNotes}</span>}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );

  const groupedMentoringLogs = mentoringLogs.reduce((acc, log) => {
    if (log.entries.length === 0) return acc;
    let month = log.entries[0].date.substring(0, 7).replace('.', '-');
    if (!month.includes('-')) {
      month = log.createdAt.substring(0, 7);
    }
    if (!acc[month]) acc[month] = [];
    acc[month].push(log);
    return acc;
  }, {} as Record<string, MentoringLogData[]>);

  const toggleMentoringMonth = (month: string) => {
    setExpandedMentoringMonths(prev => ({ ...prev, [month]: !prev[month] }));
  };

  const toggleMentoringLog = (logId: string) => {
    setExpandedMentoringLogs(prev => ({ ...prev, [logId]: !prev[logId] }));
  };

  const renderMentoringLogsList = () => {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        {Object.keys(groupedMentoringLogs).sort().reverse().map(month => (
          <Card key={month} compact>
            <div 
              onClick={() => toggleMentoringMonth(month)}
              style={{ 
                display: 'flex', 
                justifyContent: 'space-between', 
                alignItems: 'center', 
                padding: '1rem 1.5rem', 
                cursor: 'pointer',
                backgroundColor: 'var(--color-bg-alt)'
              }}
            >
              <h2 style={{ fontSize: '1.2rem', fontWeight: 600, color: 'var(--color-text-primary)', margin: 0 }}>
                {month.split('-')[0]}년 {month.split('-')[1]}월 멘토링 일지
              </h2>
              <span className="material-icons-outlined" style={{ color: 'var(--color-text-secondary)' }}>
                {expandedMentoringMonths[month] ? 'expand_less' : 'expand_more'}
              </span>
            </div>
            
            {expandedMentoringMonths[month] && (
              <div style={{ padding: '0 1.5rem 1.5rem 1.5rem' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', marginTop: '1rem' }}>
                  {groupedMentoringLogs[month].map((log) => (
                    <div key={log.id} style={{ border: '1px solid var(--color-border)', borderRadius: '8px', padding: '1.5rem' }}>
                      <div 
                        style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }}
                        onClick={() => toggleMentoringLog(log.id)}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                          <span style={{ fontSize: '1.1rem', fontWeight: 600, color: 'var(--color-text-primary)' }}>{log.classWeek}주차 멘토링 내역</span>
                          <span style={{ padding: '0.25rem 0.75rem', backgroundColor: '#e0e7ff', color: '#4338ca', borderRadius: '16px', fontSize: '0.85rem', fontWeight: 500 }}>
                            {log.classPeriod}
                          </span>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                          <span style={{ color: 'var(--color-text-secondary)', fontSize: '0.9rem' }}>총 {log.entries.length}건</span>
                          <span className="material-icons-outlined" style={{ color: 'var(--color-text-secondary)' }}>
                            {expandedMentoringLogs[log.id] ? 'expand_less' : 'expand_more'}
                          </span>
                        </div>
                      </div>
                      
                      {expandedMentoringLogs[log.id] && renderMentoringLogDetails(log)}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </Card>
        ))}
        {Object.keys(groupedMentoringLogs).length === 0 && (
           <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--color-text-secondary)' }}>
             작성된 멘토링 일지가 없습니다.
           </div>
        )}
      </div>
    );
  };

  const renderContent = () => {
    if (isLoading) {
      return <div className="chart-placeholder">Loading {activeTab}...</div>;
    }
    
    type TableCols = ComponentProps<typeof DataTable>['columns'];
    type TableData = ComponentProps<typeof DataTable>['data'];
    
    if (activeTab === 'Course Materials') return <DataTable columns={materialColumns as unknown as TableCols} data={materials as unknown as TableData} />;
    if (activeTab === 'Training Logs') return renderTrainingLogs();
    if (activeTab === 'Mentoring Logs') return renderMentoringLogsList();
  };

  return (
    <DesktopLayout
      brandTitle="EduOps Center"
      brandSubtitle="운영 관리 대시보드"
      menuItems={opsMenu}
      user={opsUser}
      showFooterLinks={true}
      headerTitle="Instructor Logs & Materials"
      headerTabs={[
        { id: 'Course Materials', label: 'Course Materials', active: activeTab === 'Course Materials' },
        { id: 'Training Logs', label: 'Training Logs', active: activeTab === 'Training Logs' },
        { id: 'Mentoring Logs', label: 'Mentoring Logs', active: activeTab === 'Mentoring Logs' }
      ]}
      onTabClick={setActiveTab}
      headerAction="Export Report"
      headerActionIcon="download"
    >
      <div className="settings-section">
        <h3 className="settings-section__title" style={{ marginBottom: 'var(--space-4)' }}>
          <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>
            {activeTab === 'Course Materials' ? 'folder' : activeTab === 'Training Logs' ? 'menu_book' : 'people'}
          </span>
          {activeTab} Overview
        </h3>
        
        {activeTab === 'Course Materials' ? (
          <Card compact>
            {renderContent()}
          </Card>
        ) : (
          renderContent()
        )}
      </div>
    </DesktopLayout>
  );
}
