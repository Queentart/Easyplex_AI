import { useState } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import { useAuth } from '../../contexts/AuthContext';
import { instructorMenuItems } from '../../data/instructor';
import { mentoringLogService } from '../../api/mentoringLogService';
import type { MentoringLogData, MentoringEntry, SpecialTag } from '../../api/mentoringLogService';
import './Instructor.css';

const DEFAULT_COURSE = 'AI Agent를 활용한 디지털 미디어 콘텐츠 Innovator';
const DEFAULT_PERIOD = '2025.12.31 ~ 2026.07.10';
const DEFAULT_SUBJECT = 'AI Agent를 위한 LLM 기초';

const TAG_OPTIONS: { value: SpecialTag, label: string, color: string, bg: string }[] = [
  { value: 'none', label: '선택 안함', color: '#64748b', bg: '#f1f5f9' },
  { value: 'intensive_care', label: '집중관리 필요', color: '#c2410c', bg: '#ffedd5' },
  { value: 'suspicious', label: '요주의 인물', color: '#b91c1c', bg: '#fee2e2' },
  { value: 'excellent', label: '우수/전공자', color: '#15803d', bg: '#dcfce7' }
];

export default function MentoringLogs() {
  const { user } = useAuth();
  const currentUser = user || {
    id: 'unknown',
    name: '이주영',
    email: '',
    role: 'tutor',
    avatar: ''
  };

  const [logs, setLogs] = useState<MentoringLogData[]>(() => mentoringLogService.getLogs());
  const [activeTab, setActiveTab] = useState<'write' | 'history'>('write');
  const [expandedMonths, setExpandedMonths] = useState<Record<string, boolean>>(() => {
    const initialLogs = mentoringLogService.getLogs();
    if (initialLogs.length > 0) {
      const months = initialLogs.map(l => l.entries[0]?.date.substring(0, 7)).filter(Boolean);
      if (months.length > 0) {
        const latest = months.sort().reverse()[0];
        return { [latest.replace('.', '-')]: true };
      }
    }
    return {};
  });
  const [expandedLogs, setExpandedLogs] = useState<Record<string, boolean>>({});

  const [courseName, setCourseName] = useState(DEFAULT_COURSE);
  const [coursePeriod, setCoursePeriod] = useState(DEFAULT_PERIOD);
  const [subject, setSubject] = useState(DEFAULT_SUBJECT);
  const [tutorName, setTutorName] = useState(currentUser.name);
  const [classWeek, setClassWeek] = useState<number>(1);
  const [classPeriod, setClassPeriod] = useState<string>('12.31 ~ 1.2 / 휴강(1.1)');
  
  const [entries, setEntries] = useState<Omit<MentoringEntry, 'id'>[]>([
    { date: '', tutorName: currentUser.name, traineeName: '수강생 전체', category: '질의응답', topic: '', content: '', specialNotes: '', tag: 'none' }
  ]);

  const handleAddEntry = () => {
    setEntries([...entries, { date: '', tutorName: currentUser.name, traineeName: '', category: '기타', topic: '', content: '', specialNotes: '', tag: 'none' }]);
  };

  const handleRemoveEntry = (index: number) => {
    setEntries(entries.filter((_, i) => i !== index));
  };

  const handleEntryChange = (index: number, field: keyof Omit<MentoringEntry, 'id'>, value: string) => {
    const newEntries = [...entries];
    newEntries[index] = { ...newEntries[index], [field]: value };
    setEntries(newEntries);
  };

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    
    const validEntries = entries.filter(e => e.date && e.content).map((e, idx) => ({ ...e, id: `entry-${Date.now()}-${idx}` }));
    if (validEntries.length === 0) {
      alert('최소 1개 이상의 일자와 내용이 입력되어야 합니다.');
      return;
    }

    const logData: Omit<MentoringLogData, 'id' | 'createdAt'> = {
      courseName,
      coursePeriod,
      subject,
      tutorName,
      classWeek,
      classPeriod,
      entries: validEntries
    };

    mentoringLogService.saveLog(logData);
    setLogs(mentoringLogService.getLogs());
    setActiveTab('history');
    
    setEntries([{ date: '', tutorName: currentUser.name, traineeName: '수강생 전체', category: '질의응답', topic: '', content: '', specialNotes: '', tag: 'none' }]);
  };

  const groupedLogs = logs.reduce((acc, log) => {
    if (log.entries.length === 0) return acc;
    let month = log.entries[0].date.substring(0, 7).replace('.', '-'); 
    if (!month.includes('-')) {
      month = log.createdAt.substring(0, 7);
    }
    if (!acc[month]) acc[month] = [];
    acc[month].push(log);
    return acc;
  }, {} as Record<string, MentoringLogData[]>);

  const toggleMonth = (month: string) => {
    setExpandedMonths(prev => ({ ...prev, [month]: !prev[month] }));
  };

  const toggleLog = (logId: string) => {
    setExpandedLogs(prev => ({ ...prev, [logId]: !prev[logId] }));
  };

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

  const renderLogDetails = (log: MentoringLogData) => (
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
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
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

  return (
    <DesktopLayout
      brandTitle="EduAI"
      brandSubtitle="Instructor Portal"
      menuItems={instructorMenuItems}
      user={currentUser}
      showFooterLinks={true}
      headerTitle="멘토링 일지 (멘토용)"
      headerAction="엑셀 다운로드"
      headerActionIcon="download"
    >
      <div className="instructor-grid">
        <div className="col-12">
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
              주차별 멘토링 작성
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
            <Card title="주차별 멘토링 일지" titleIcon="edit_document">
              <form onSubmit={handleSave}>
                <div style={{ backgroundColor: '#0f766e', color: 'white', padding: '1rem', borderRadius: '8px 8px 0 0', textAlign: 'center' }}>
                  <h2 style={{ margin: 0, fontSize: '1.5rem', fontWeight: 'bold' }}>주차별 멘토링 내역</h2>
                </div>
                
                <div style={{ 
                  backgroundColor: '#f8fafc', 
                  border: '1px solid #e2e8f0', 
                  borderTop: 'none',
                  borderRadius: '0 0 8px 8px', 
                  padding: '1.5rem',
                  marginBottom: '2rem'
                }}>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '1rem' }}>
                    <div>
                      <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: '#475569', marginBottom: '0.25rem' }}>훈련과정명</label>
                      <input type="text" value={courseName} onChange={e => setCourseName(e.target.value)} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.9rem', color: '#0f172a' }} />
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: '#475569', marginBottom: '0.25rem' }}>교과목</label>
                      <input type="text" value={subject} onChange={e => setSubject(e.target.value)} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.9rem', color: '#0f172a' }} />
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: '#475569', marginBottom: '0.25rem' }}>전체훈련기간</label>
                      <input type="text" value={coursePeriod} onChange={e => setCoursePeriod(e.target.value)} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.9rem', color: '#0f172a' }} />
                    </div>
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '1rem' }}>
                    <div>
                      <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: '#475569', marginBottom: '0.25rem' }}>멘토 (작성자)</label>
                      <input type="text" value={tutorName} onChange={e => setTutorName(e.target.value)} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.9rem', color: '#0f172a' }} />
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: '#475569', marginBottom: '0.25rem' }}>수업주차</label>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <input type="number" value={classWeek} onChange={e => setClassWeek(Number(e.target.value))} style={{ width: '80px', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.9rem', color: '#0f172a' }} />
                        <span>주차</span>
                      </div>
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: '#475569', marginBottom: '0.25rem' }}>수업기간</label>
                      <input type="text" value={classPeriod} onChange={e => setClassPeriod(e.target.value)} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.9rem', color: '#0f172a' }} />
                    </div>
                  </div>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
                  <h3 style={{ fontSize: '1.1rem', fontWeight: 600, color: 'var(--color-text-primary)', margin: 0 }}>멘토링 활동 상세 내역</h3>
                  <button type="button" onClick={handleAddEntry} className="button button--outline" style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', padding: '0.4rem 0.8rem', fontSize: '0.85rem' }}>
                    <span className="material-icons-outlined" style={{ fontSize: '16px' }}>add</span>
                    행 추가
                  </button>
                </div>
                
                <div className="table-responsive" style={{ marginBottom: '2rem', overflowX: 'auto', border: '1px solid #e2e8f0', borderRadius: '8px' }}>
                  <table className="data-table" style={{ width: '100%', minWidth: '1000px', margin: 0 }}>
                    <thead style={{ backgroundColor: '#334155', color: 'white' }}>
                      <tr>
                        <th style={{ width: '120px' }}>일자</th>
                        <th style={{ width: '100px' }}>멘토명</th>
                        <th style={{ width: '130px' }}>훈련생명</th>
                        <th style={{ width: '100px' }}>구분</th>
                        <th style={{ width: '150px' }}>주제</th>
                        <th>내용</th>
                        <th style={{ width: '150px' }}>특이사항 (태그)</th>
                        <th style={{ width: '50px' }}></th>
                      </tr>
                    </thead>
                    <tbody>
                      {entries.map((entry, idx) => (
                        <tr key={idx}>
                          <td style={{ padding: '0.5rem' }}>
                            <input type="text" placeholder="YYYY.MM.DD" value={entry.date} onChange={e => handleEntryChange(idx, 'date', e.target.value)} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.85rem' }} />
                          </td>
                          <td style={{ padding: '0.5rem' }}>
                            <input type="text" value={entry.tutorName} onChange={e => handleEntryChange(idx, 'tutorName', e.target.value)} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.85rem' }} />
                          </td>
                          <td style={{ padding: '0.5rem' }}>
                            <input type="text" placeholder="특정학생/수강생전체" value={entry.traineeName} onChange={e => handleEntryChange(idx, 'traineeName', e.target.value)} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.85rem' }} />
                          </td>
                          <td style={{ padding: '0.5rem' }}>
                            <select value={entry.category} onChange={e => handleEntryChange(idx, 'category', e.target.value)} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.85rem', backgroundColor: 'white' }}>
                              <option value="질의응답">질의응답</option>
                              <option value="기타">기타</option>
                              <option value="면담">면담</option>
                            </select>
                          </td>
                          <td style={{ padding: '0.5rem' }}>
                            <input type="text" value={entry.topic} onChange={e => handleEntryChange(idx, 'topic', e.target.value)} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.85rem' }} />
                          </td>
                          <td style={{ padding: '0.5rem' }}>
                            <input type="text" value={entry.content} onChange={e => handleEntryChange(idx, 'content', e.target.value)} style={{ width: '100%', padding: '0.5rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.85rem' }} />
                          </td>
                          <td style={{ padding: '0.5rem' }}>
                            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
                              <select 
                                value={entry.tag} 
                                onChange={e => handleEntryChange(idx, 'tag', e.target.value as SpecialTag)} 
                                style={{ width: '100%', padding: '0.4rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.8rem', backgroundColor: 'white' }}
                              >
                                {TAG_OPTIONS.map(opt => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
                              </select>
                              <input type="text" placeholder="추가 코멘트 (선택)" value={entry.specialNotes} onChange={e => handleEntryChange(idx, 'specialNotes', e.target.value)} style={{ width: '100%', padding: '0.4rem', border: '1px solid #cbd5e1', borderRadius: '4px', fontSize: '0.8rem' }} />
                            </div>
                          </td>
                          <td style={{ padding: '0.5rem', textAlign: 'center' }}>
                            <button type="button" onClick={() => handleRemoveEntry(idx)} style={{ background: 'none', border: 'none', color: '#ef4444', cursor: 'pointer', padding: '0.2rem' }}>
                              <span className="material-icons-outlined" style={{ fontSize: '18px' }}>delete</span>
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
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
                      {month.split('-')[0]}년 {month.split('-')[1]}월 멘토링 일지
                    </h2>
                    <span className="material-icons-outlined" style={{ color: 'var(--color-text-secondary)' }}>
                      {expandedMonths[month] ? 'expand_less' : 'expand_more'}
                    </span>
                  </div>
                  
                  {expandedMonths[month] && (
                    <div style={{ padding: '0 1.5rem 1.5rem 1.5rem' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', marginTop: '1rem' }}>
                        {groupedLogs[month].map((log) => (
                          <div key={log.id} style={{ border: '1px solid var(--color-border)', borderRadius: '8px', padding: '1.5rem' }}>
                            <div 
                              style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }}
                              onClick={() => toggleLog(log.id)}
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
                <div style={{ padding: '3rem', textAlign: 'center', color: 'var(--color-text-secondary)' }}>
                  작성된 멘토링 일지가 없습니다.
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </DesktopLayout>
  );
}
