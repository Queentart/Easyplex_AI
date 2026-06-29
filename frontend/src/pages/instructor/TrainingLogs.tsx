import { useState, useRef } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import { useAuth } from '../../contexts/AuthContext';
import { instructorMenuItems } from '../../data/instructor';
import { trainingLogService } from '../../api/trainingLogService';
import type { TrainingLogData, ClassPeriod } from '../../api/trainingLogService';
import './Instructor.css';

const DEFAULT_SCHEDULE = Array.from({ length: 8 }, (_, i) => ({
  period: i + 1,
  subject: '',
  instructorName: '',
  content: '',
  notes: ''
}));

export default function TrainingLogs() {
  const { user } = useAuth();
  const [logs, setLogs] = useState<TrainingLogData[]>(() => trainingLogService.getLogs());
  const formRef = useRef<HTMLFormElement>(null);
  const [activeTab, setActiveTab] = useState<'write' | 'history'>('write');
  const [expandedMonths, setExpandedMonths] = useState<Record<string, boolean>>({ '2026-06': true });
  const [expandedLogs, setExpandedLogs] = useState<Record<string, boolean>>({});

  const currentUser = user || {
    id: 'unknown',
    name: 'Unknown',
    email: '',
    role: 'instructor',
    avatar: ''
  };

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formRef.current) return;
    const formData = new FormData(formRef.current);
    
    const schedule: ClassPeriod[] = [];
    for (let i = 1; i <= 8; i++) {
      schedule.push({
        period: i,
        subject: formData.get(`subject_${i}`) as string || '',
        instructorName: formData.get(`instructor_${i}`) as string || '',
        content: formData.get(`content_${i}`) as string || '',
        notes: formData.get(`notes_${i}`) as string || ''
      });
    }

    const logData: Omit<TrainingLogData, 'id' | 'createdAt'> = {
      courseName: formData.get('courseName') as string || '',
      coursePeriod: formData.get('coursePeriod') as string || '',
      trainingDate: formData.get('trainingDate') as string || '',
      trainingDayNumber: Number(formData.get('trainingDayNumber')) || 0,
      remainingDays: Number(formData.get('remainingDays')) || 0,
      attendance: {
        total: Number(formData.get('att_total')) || 0,
        present: Number(formData.get('att_present')) || 0,
        absent: Number(formData.get('att_absent')) || 0,
        late: Number(formData.get('att_late')) || 0,
        out: Number(formData.get('att_out')) || 0,
        earlyLeave: Number(formData.get('att_earlyLeave')) || 0,
      },
      schedule,
      instructions: formData.get('instructions') as string || '',
      specialNotes: formData.get('specialNotes') as string || '',
      instructorId: currentUser.id
    };

    trainingLogService.saveLog(logData);
    setLogs(trainingLogService.getLogs()); // Reload
    setActiveTab('history');
    if (formRef.current) formRef.current.reset();
  };

  // Group logs by month
  const groupedLogs = logs.reduce((acc, log) => {
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

  return (
    <DesktopLayout
      brandTitle="EduAI"
      brandSubtitle="Instructor Portal"
      menuItems={instructorMenuItems}
      user={currentUser}
      showFooterLinks={true}
      headerTitle="학습 일지 (훈련 일지)"
      headerAction="엑셀 다운로드"
      headerActionIcon="download"
    >
      <div className="instructor-grid">
        <div className="col-12">
          {/* 탭 네비게이션 */}
          <div style={{ display: 'flex', borderBottom: '1px solid var(--color-border)', marginBottom: '1.5rem' }}>
            <button 
              onClick={() => setActiveTab('write')}
              style={{ 
                padding: '1rem 2rem', 
                fontWeight: 600, 
                borderBottom: activeTab === 'write' ? '2px solid var(--color-primary)' : '2px solid transparent',
                color: activeTab === 'write' ? 'var(--color-primary)' : 'var(--color-text-secondary)',
                backgroundColor: 'transparent',
                cursor: 'pointer'
              }}
            >
              오늘의 일지 작성
            </button>
            <button 
              onClick={() => setActiveTab('history')}
              style={{ 
                padding: '1rem 2rem', 
                fontWeight: 600, 
                borderBottom: activeTab === 'history' ? '2px solid var(--color-primary)' : '2px solid transparent',
                color: activeTab === 'history' ? 'var(--color-primary)' : 'var(--color-text-secondary)',
                backgroundColor: 'transparent',
                cursor: 'pointer'
              }}
            >
              과거 기록 (월별 조회)
            </button>
          </div>

          {activeTab === 'write' && (
            <Card title="훈련 일지 작성" titleIcon="edit_document">
              <form ref={formRef} onSubmit={handleSave}>
              <div style={{ 
                backgroundColor: '#f8fafc', 
                border: '1px solid #e2e8f0', 
                borderRadius: '8px', 
                padding: '1.5rem',
                marginBottom: '2rem'
              }}>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '1rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, color: '#475569', marginBottom: '0.25rem' }}>훈련과정</label>
                    <input name="courseName" type="text" defaultValue="AI Agent를 활용한 디지털 미디어 콘텐츠 Innovator" style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.9rem', color: '#0f172a' }} />
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, color: '#475569', marginBottom: '0.25rem' }}>훈련기간</label>
                    <input name="coursePeriod" type="text" defaultValue="2026년 3월 31일 ~ 2026년 10월 8일 (3회차)" style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.9rem', color: '#0f172a' }} />
                  </div>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '1rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, color: '#475569', marginBottom: '0.25rem' }}>훈련일</label>
                    <input name="trainingDate" type="date" defaultValue="2026-06-17" style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.9rem', color: '#0f172a' }} />
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, color: '#475569', marginBottom: '0.25rem' }}>훈련일수</label>
                    <input name="trainingDayNumber" type="number" defaultValue={53} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.9rem', color: '#0f172a' }} />
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, color: '#475569', marginBottom: '0.25rem' }}>잔여일수</label>
                    <input name="remainingDays" type="number" defaultValue={77} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.9rem', color: '#0f172a' }} />
                  </div>
                </div>
              </div>

              <h3 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '1rem', color: 'var(--color-text-primary)' }}>출결 인원</h3>
              <div style={{ display: 'flex', gap: '1rem', marginBottom: '2rem', flexWrap: 'wrap' }}>
                {[
                  { label: '총원', name: 'att_total', val: 28 }, 
                  { label: '출석', name: 'att_present', val: 0 }, 
                  { label: '결석', name: 'att_absent', val: 0 }, 
                  { label: '지각', name: 'att_late', val: 0 }, 
                  { label: '외출', name: 'att_out', val: 0 }, 
                  { label: '조퇴', name: 'att_earlyLeave', val: 0 }
                ].map((item) => (
                  <div key={item.name} style={{ flex: '1', minWidth: '80px' }}>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, color: '#475569', marginBottom: '0.25rem', textAlign: 'center' }}>{item.label}</label>
                    <input name={item.name} type="number" defaultValue={item.val} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '1rem', textAlign: 'center', color: '#0f172a' }} />
                  </div>
                ))}
              </div>

              <h3 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '1rem', color: 'var(--color-text-primary)' }}>교육 사항 (교시별)</h3>
              <div className="table-responsive" style={{ marginBottom: '2rem', overflowX: 'auto' }}>
                <table className="data-table" style={{ width: '100%', minWidth: '800px' }}>
                  <thead>
                    <tr>
                      <th style={{ width: '60px', textAlign: 'center' }}>교시</th>
                      <th style={{ width: '20%' }}>교과목</th>
                      <th style={{ width: '15%' }}>강사</th>
                      <th style={{ width: '40%' }}>교육내용</th>
                      <th style={{ width: '25%' }}>비고</th>
                    </tr>
                  </thead>
                  <tbody>
                    {DEFAULT_SCHEDULE.map(cls => (
                      <tr key={cls.period}>
                        <td style={{ textAlign: 'center', fontWeight: 500 }}>{cls.period}</td>
                        <td style={{ padding: '0.25rem' }}><input name={`subject_${cls.period}`} type="text" placeholder="과목명 입력" style={{ width: '100%', padding: '0.5rem', border: '1px solid transparent', borderRadius: '4px', backgroundColor: '#f8fafc', color: '#0f172a' }} /></td>
                        <td style={{ padding: '0.25rem' }}><input name={`instructor_${cls.period}`} type="text" placeholder="강사명" style={{ width: '100%', padding: '0.5rem', border: '1px solid transparent', borderRadius: '4px', backgroundColor: '#f8fafc', color: '#0f172a' }} /></td>
                        <td style={{ padding: '0.25rem' }}><input name={`content_${cls.period}`} type="text" placeholder="세부 교육 내용" style={{ width: '100%', padding: '0.5rem', border: '1px solid transparent', borderRadius: '4px', backgroundColor: '#f8fafc', color: '#0f172a' }} /></td>
                        <td style={{ padding: '0.25rem' }}><input name={`notes_${cls.period}`} type="text" placeholder="비고" style={{ width: '100%', padding: '0.5rem', border: '1px solid transparent', borderRadius: '4px', backgroundColor: '#f8fafc', color: '#0f172a' }} /></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', marginBottom: '2rem' }}>
                <div>
                  <h3 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem', color: 'var(--color-text-primary)' }}>지시사항 (과제 등)</h3>
                  <textarea name="instructions" rows={4} style={{ width: '100%', padding: '0.75rem', border: '1px solid #cbd5e1', borderRadius: '4px', resize: 'vertical', color: '#0f172a' }} placeholder="오늘 안내된 과제나 지시사항을 기록하세요." />
                </div>
                <div>
                  <h3 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem', color: 'var(--color-text-primary)' }}>특기사항 &lt;결석자 명단 포함&gt;</h3>
                  <textarea name="specialNotes" rows={4} style={{ width: '100%', padding: '0.75rem', border: '1px solid #cbd5e1', borderRadius: '4px', resize: 'vertical', color: '#0f172a' }} placeholder="결석자, 지각자 명단 및 사유 등 특이사항을 기록하세요." />
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '1rem' }}>
                <button type="button" className="button button--outline">임시 저장</button>
                <button type="submit" className="button button--primary" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span className="material-icons-outlined" style={{ fontSize: '18px' }}>check_circle</span>
                  작성 완료 및 엑셀 제출
                </button>
              </div>
              </form>
            </Card>
          )}

          {activeTab === 'history' && (
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
            </div>
          )}
        </div>
      </div>
    </DesktopLayout>
  );
}
