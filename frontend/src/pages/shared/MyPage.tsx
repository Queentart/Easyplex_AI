/* ==========================================================
 * MyPage 컴포넌트
 * ----------------------------------------------------------
 * 역할(Role)에 따라 맞춤형 콘텐츠를 보여주는 마이 페이지입니다.
 * ========================================================== */

import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import DesktopLayout from '../../components/layout/DesktopLayout';
import MobileLayout from '../../components/layout/MobileLayout';
import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';

// 모달 및 API 임포트
import { assignmentApi, type AssignmentTask } from '../../api/assignmentApi';
import AssignmentSubmissionModal from '../student/components/AssignmentSubmissionModal';
import AssignmentReviewModal from '../student/components/AssignmentReviewModal';

// 메뉴 데이터 임포트
import { studentBottomNav } from '../../data/student';
import { instructorMenuItems } from '../../data/instructor';
import { opsMenu } from '../../data/eduops';
import { techMenu } from '../../data/techops';
import { executiveMenuItems } from '../../data/executive';

export default function MyPage() {
  const { user } = useAuth();
  const navigate = useNavigate();

  // 학생용 상태
  const [tasks, setTasks] = useState<AssignmentTask[]>([]);
  const [selectedSubmitTask, setSelectedSubmitTask] = useState<AssignmentTask | null>(null);
  const [selectedReviewTask, setSelectedReviewTask] = useState<AssignmentTask | null>(null);
  const [noteContent, setNoteContent] = useState('');
  const [noteFile, setNoteFile] = useState<File | null>(null);

  const fetchTasks = async () => {
    try {
      const data = await assignmentApi.getTasks();
      setTasks(data);
    } catch (error) {
      console.error('Failed to fetch assignments', error);
    }
  };

  useEffect(() => {
    if (user?.role === 'student') {
      // 린트 에러(동기적 setState 호출 경고)를 회피하기 위해 비동기 큐로 넘깁니다.
      setTimeout(() => {
        fetchTasks().catch(console.error);
      }, 0);
    }
  }, [user]);

  const handleSaveNote = () => {
    if (!noteContent.trim() && !noteFile) {
      alert('저장할 노트 내용이나 파일을 등록해주세요.');
      return;
    }
    alert('나만의 정리 노트가 성공적으로 저장되었습니다! (UI 목업)');
    setNoteContent('');
    setNoteFile(null);
  };

  if (!user) return null;

  const handleBack = () => navigate(-1);

  // 헤더의 뒤로가기 액션
  const headerAction = "돌아가기";
  const headerActionIcon = "arrow_back";

  // 콘텐츠 공통: 뒤로 가기 버튼 컴포넌트 (모바일 뷰 등 상단 표시용)
  const BackButton = () => (
    <button 
      onClick={handleBack} 
      className="btn btn-outline btn-sm"
      style={{ marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '4px', alignSelf: 'flex-start', width: 'fit-content' }}
    >
      <span className="material-icons-outlined" style={{ fontSize: '18px' }}>arrow_back</span>
      돌아가기
    </button>
  );

  /* ── 역할별 콘텐츠 렌더링 ── */
  const renderContent = () => {
    switch (user.role) {
      case 'student':
        return (
          <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <BackButton />
            
            {/* 프로필 히어로 섹션 */}
            <div style={{ 
              background: 'linear-gradient(135deg, var(--color-primary) 0%, #2563eb 100%)',
              borderRadius: '16px',
              padding: '24px',
              color: 'white',
              display: 'flex',
              alignItems: 'center',
              gap: '20px',
              boxShadow: '0 10px 25px -5px rgba(37, 99, 235, 0.4)'
            }}>
              <img 
                src={`https://api.dicebear.com/7.x/avataaars/svg?seed=${user.name}`} 
                alt="Profile" 
                style={{ width: '80px', height: '80px', borderRadius: '50%', border: '4px solid rgba(255,255,255,0.3)', background: 'white' }} 
              />
              <div style={{ flex: 1 }}>
                <h2 style={{ fontSize: '1.4rem', fontWeight: 'bold', margin: 0 }}>반갑습니다, {user.nameKo || user.name}님! 👋</h2>
                <p style={{ margin: '4px 0 8px 0', opacity: 0.9 }}>Spring 2024 AI 부트캠프</p>
                <div style={{ display: 'inline-flex', alignItems: 'center', background: 'rgba(255,255,255,0.2)', padding: '4px 12px', borderRadius: '20px', fontSize: '0.85rem' }}>
                  <span className="material-icons-outlined" style={{ fontSize: '16px', marginRight: '4px', color: '#fbbf24' }}>local_fire_department</span>
                  현재 12일 연속 출석 중!
                </div>
              </div>
            </div>

            {/* 상단 2개 카드 (Flexbox 레이아웃으로 변경) */}
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '16px' }}>
              
              {/* 학습 요약 카드 */}
              <div style={{ flex: '1 1 300px' }}>
                <Card title="학습 요약">
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                    <div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                        <span style={{ fontSize: '0.9rem', color: 'var(--color-text-secondary)', fontWeight: 500 }}>현재 수업 진도율</span>
                        <span style={{ fontSize: '0.9rem', fontWeight: 'bold' }}>45%</span>
                      </div>
                      <div style={{ height: '8px', background: 'var(--color-bg-tertiary)', borderRadius: '4px', overflow: 'hidden' }}>
                        <div style={{ width: '45%', height: '100%', background: 'var(--color-primary)', borderRadius: '4px' }}></div>
                      </div>
                    </div>
                    
                    <div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                        <span style={{ fontSize: '0.9rem', color: 'var(--color-text-secondary)', fontWeight: 500 }}>출석률</span>
                        <span style={{ fontSize: '0.9rem', fontWeight: 'bold', color: 'var(--color-success)' }}>98%</span>
                      </div>
                      <div style={{ height: '8px', background: 'var(--color-bg-tertiary)', borderRadius: '4px', overflow: 'hidden' }}>
                        <div style={{ width: '98%', height: '100%', background: 'var(--color-success)', borderRadius: '4px' }}></div>
                      </div>
                    </div>
                  </div>
                </Card>
              </div>

              {/* 최근 과제 카드 */}
              <div style={{ flex: '1 1 300px' }}>
                <Card title="최근 과제">
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                    {tasks.slice(0, 2).map((task) => {
                      const isPastDeadline = task.deadline ? new Date() > new Date(task.deadline) : false;
                      const isGraded = task.status === 'graded';
                      const isSubmitted = task.status === 'submitted' || isGraded;

                      return (
                        <div key={task.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px', background: 'var(--color-bg-secondary)', borderRadius: '8px' }}>
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                            <span style={{ fontSize: '0.9rem', fontWeight: 600 }}>{task.title}</span>
                            <span style={{ fontSize: '0.8rem', color: 'var(--color-text-tertiary)' }}>
                              {task.deadline ? `마감: ${new Date(task.deadline).toLocaleDateString()}` : '마감일 없음'}
                            </span>
                          </div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            {isGraded && task.final_score !== null && task.final_score !== undefined ? (
                              <span style={{ padding: '2px 8px', fontSize: '0.75rem', background: '#dcfce7', color: '#22c55e', borderRadius: '12px', fontWeight: 'bold' }}>{task.final_score}점</span>
                            ) : (
                              <StatusTag label={task.status || 'pending'} variant={task.status === 'pending' ? 'warning' : 'info'} />
                            )}
                            
                            {isGraded ? (
                              <button className="btn btn-outline btn-sm" style={{ padding: '4px 8px', fontSize: '0.8rem' }} onClick={() => setSelectedReviewTask(task)}>리뷰보기</button>
                            ) : (
                              <button 
                                className={`btn btn-sm ${isPastDeadline && !isSubmitted ? 'btn-outline' : 'btn-primary'}`} 
                                style={{ padding: '4px 8px', fontSize: '0.8rem' }} 
                                onClick={() => setSelectedSubmitTask(task)}
                                disabled={isPastDeadline && !isSubmitted}
                              >
                                {isPastDeadline && !isSubmitted ? '마감됨' : (isSubmitted ? '수정하기' : '제출하기')}
                              </button>
                            )}
                          </div>
                        </div>
                      );
                    })}

                    {tasks.length === 0 && (
                      <p style={{ textAlign: 'center', color: 'var(--color-text-tertiary)', padding: '20px 0', fontSize: '0.9rem' }}>최근 과제가 없습니다.</p>
                    )}

                    <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '4px' }}>
                      <span 
                        style={{ fontSize: '0.85rem', color: 'var(--color-primary)', cursor: 'pointer', fontWeight: 500 }} 
                        onClick={() => navigate('/student/assignments')}
                      >
                        과제 전체보기 &rarr;
                      </span>
                    </div>
                  </div>
                </Card>
              </div>
            </div>

            {/* 나만의 정리 노트 위젯 */}
            <Card title="나만의 정리 노트">
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <p style={{ margin: 0, fontSize: '0.9rem', color: 'var(--color-text-secondary)' }}>수업 중 배운 내용을 마크다운으로 메모하거나, 다양한 유형의 파일(문서, 텍스트, 이미지, 오디오, 비디오)을 아카이빙 해보세요.</p>
                <textarea
                  value={noteContent}
                  onChange={(e) => setNoteContent(e.target.value)}
                  placeholder="# 오늘 배운 내용 요약&#10;- React 상태 관리&#10;- 커스텀 훅 작성법..."
                  style={{
                    width: '100%',
                    minHeight: '120px',
                    padding: '16px',
                    borderRadius: '8px',
                    border: '1px solid var(--color-border)',
                    resize: 'vertical',
                    fontFamily: 'inherit',
                    fontSize: '0.95rem',
                    lineHeight: '1.5'
                  }}
                />
                
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '16px', alignItems: 'center', justifyContent: 'space-between' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <label 
                      htmlFor="note-file-upload" 
                      style={{ 
                        display: 'flex', alignItems: 'center', gap: '6px', 
                        padding: '8px 16px', background: 'var(--color-bg-secondary)', 
                        border: '1px dashed var(--color-primary)', borderRadius: '8px', 
                        color: 'var(--color-primary)', cursor: 'pointer', fontSize: '0.9rem', fontWeight: 500 
                      }}
                    >
                      <span className="material-icons-outlined" style={{ fontSize: '18px' }}>cloud_upload</span>
                      {noteFile ? noteFile.name : '파일 첨부 (Drag & Drop)'}
                    </label>
                    <input 
                      id="note-file-upload"
                      type="file" 
                      onChange={(e) => {
                        if (e.target.files && e.target.files.length > 0) {
                          setNoteFile(e.target.files[0]);
                        }
                      }} 
                      style={{ display: 'none' }}
                    />
                    {noteFile && (
                      <span 
                        className="material-icons-outlined" 
                        style={{ fontSize: '18px', color: 'var(--color-error)', cursor: 'pointer' }}
                        onClick={() => setNoteFile(null)}
                      >
                        cancel
                      </span>
                    )}
                  </div>

                  <button className="btn btn-primary" onClick={handleSaveNote} style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <span className="material-icons-outlined" style={{ fontSize: '18px' }}>save</span>
                    노트 저장
                  </button>
                </div>
              </div>
            </Card>

            {/* 모달 연동 */}
            <AssignmentSubmissionModal 
              isOpen={selectedSubmitTask !== null}
              onClose={() => setSelectedSubmitTask(null)}
              selectedTask={selectedSubmitTask}
              onSuccess={fetchTasks}
            />
            <AssignmentReviewModal
              isOpen={selectedReviewTask !== null}
              onClose={() => setSelectedReviewTask(null)}
              selectedTask={selectedReviewTask}
            />
          </div>
        );
      
      case 'instructor':
        return (
          <div style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <BackButton />
            {/* 프로필 히어로 섹션 */}
            <div style={{ 
              background: 'linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%)',
              borderRadius: '16px',
              padding: '24px',
              color: 'white',
              display: 'flex',
              alignItems: 'center',
              gap: '20px',
              boxShadow: '0 10px 25px -5px rgba(124, 58, 237, 0.4)',
              flexWrap: 'wrap'
            }}>
              <img 
                src={`https://api.dicebear.com/7.x/avataaars/svg?seed=${user.name}`} 
                alt="Profile" 
                style={{ width: '80px', height: '80px', borderRadius: '50%', border: '4px solid rgba(255,255,255,0.3)', background: 'white' }} 
              />
              <div style={{ flex: 1 }}>
                <h2 style={{ fontSize: '1.4rem', fontWeight: 'bold', margin: 0 }}>환영합니다, {user.nameKo || user.name} 강사님!</h2>
                <p style={{ margin: '4px 0 8px 0', opacity: 0.9 }}>담당 클래스: Spring 2024 AI 부트캠프</p>
                <div style={{ display: 'inline-flex', alignItems: 'center', background: 'rgba(255,255,255,0.2)', padding: '4px 12px', borderRadius: '20px', fontSize: '0.85rem' }}>
                  <span className="material-icons-outlined" style={{ fontSize: '16px', marginRight: '4px', color: '#fcd34d' }}>star</span>
                  평균 만족도: 4.9 / 5.0
                </div>
              </div>
            </div>

            {/* 그리드 레이아웃: 좌측 알림/요약, 우측 액션/일정 */}
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '20px' }}>
              
              <div style={{ flex: '2 1 400px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '16px' }}>
                  <Card compact>
                    <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      <span style={{ fontSize: '0.9rem', color: 'var(--color-text-secondary)', fontWeight: 500 }}>전체 출석률</span>
                      <span style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'var(--color-primary)' }}>92%</span>
                    </div>
                  </Card>
                  <Card compact>
                    <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      <span style={{ fontSize: '0.9rem', color: 'var(--color-text-secondary)', fontWeight: 500 }}>과제 제출률</span>
                      <span style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'var(--color-success)' }}>88%</span>
                    </div>
                  </Card>
                </div>

                <Card title="할 일 및 알림">
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px', background: '#fee2e2', borderRadius: '8px', border: '1px solid #fecaca', flexWrap: 'wrap', gap: '12px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <span className="material-icons-outlined" style={{ color: '#ef4444', fontSize: '28px' }}>assignment_late</span>
                        <div>
                          <div style={{ fontSize: '1rem', fontWeight: 600, color: '#991b1b' }}>미채점 과제</div>
                          <div style={{ fontSize: '0.85rem', color: '#b91c1c', marginTop: '2px' }}>'React 상태관리 과제' 제출 5건 대기 중</div>
                        </div>
                      </div>
                      <button 
                        className="btn btn-sm" 
                        style={{ background: '#ef4444', color: 'white', border: 'none', padding: '6px 16px', fontSize: '0.85rem', transition: 'all 0.2s ease', cursor: 'pointer' }}
                        onMouseEnter={(e) => { e.currentTarget.style.transform = 'translateY(-2px)'; e.currentTarget.style.boxShadow = '0 4px 8px rgba(239, 68, 68, 0.4)'; e.currentTarget.style.filter = 'brightness(1.05)'; }}
                        onMouseLeave={(e) => { e.currentTarget.style.transform = 'translateY(0)'; e.currentTarget.style.boxShadow = 'none'; e.currentTarget.style.filter = 'brightness(1)'; }}
                        onClick={() => navigate('/instructor/assignments')}>채점하기</button>
                    </div>

                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px', background: '#fef3c7', borderRadius: '8px', border: '1px solid #fde68a', flexWrap: 'wrap', gap: '12px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <span className="material-icons-outlined" style={{ color: '#f59e0b', fontSize: '28px' }}>forum</span>
                        <div>
                          <div style={{ fontSize: '1rem', fontWeight: 600, color: '#92400e' }}>미답변 질문</div>
                          <div style={{ fontSize: '0.85rem', color: '#b45309', marginTop: '2px' }}>커뮤니티에 새로운 질문 3건 등록됨</div>
                        </div>
                      </div>
                      <button 
                        className="btn btn-sm" 
                        style={{ background: '#f59e0b', color: 'white', border: 'none', padding: '6px 16px', fontSize: '0.85rem', transition: 'all 0.2s ease', cursor: 'pointer' }}
                        onMouseEnter={(e) => { e.currentTarget.style.transform = 'translateY(-2px)'; e.currentTarget.style.boxShadow = '0 4px 8px rgba(245, 158, 11, 0.4)'; e.currentTarget.style.filter = 'brightness(1.05)'; }}
                        onMouseLeave={(e) => { e.currentTarget.style.transform = 'translateY(0)'; e.currentTarget.style.boxShadow = 'none'; e.currentTarget.style.filter = 'brightness(1)'; }}
                        onClick={() => navigate('/instructor/learning-questions')}>답변하기</button>
                    </div>
                  </div>
                </Card>
              </div>

              <div style={{ flex: '1 1 300px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <Card title="빠른 실행">
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                    <button className="btn btn-outline" style={{ display: 'flex', justifyContent: 'flex-start', alignItems: 'center', gap: '8px', width: '100%', padding: '12px' }} onClick={() => navigate('/instructor/assignments')}>
                      <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>add_task</span> 
                      <span style={{ fontWeight: 500 }}>새 과제 등록하기</span>
                    </button>
                    <button className="btn btn-outline" style={{ display: 'flex', justifyContent: 'flex-start', alignItems: 'center', gap: '8px', width: '100%', padding: '12px' }} onClick={() => navigate('/instructor/training-logs')}>
                      <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>edit_note</span> 
                      <span style={{ fontWeight: 500 }}>학습 일지 작성하기</span>
                    </button>
                    <button className="btn btn-outline" style={{ display: 'flex', justifyContent: 'flex-start', alignItems: 'center', gap: '8px', width: '100%', padding: '12px' }} onClick={() => navigate('/instructor/curriculum')}>
                      <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>route</span> 
                      <span style={{ fontWeight: 500 }}>커리큘럼 로드맵 수정하기</span>
                    </button>
                  </div>
                </Card>

                <Card title="금일 상담 학생 리스트">
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                    {/* 상담 학생 리스트 UI 목업 */}
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px', background: 'var(--color-bg-secondary)', borderRadius: '8px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=student1" alt="Student" style={{ width: '40px', height: '40px', borderRadius: '50%', background: 'white' }} />
                        <div>
                          <div style={{ fontSize: '0.95rem', fontWeight: 600 }}>김철수 학생</div>
                          <div style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>15:00 - 취업/진로 상담</div>
                        </div>
                      </div>
                      <button className="btn btn-sm btn-outline">상담일지 작성</button>
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px', background: 'var(--color-bg-secondary)', borderRadius: '8px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=student2" alt="Student" style={{ width: '40px', height: '40px', borderRadius: '50%', background: 'white' }} />
                        <div>
                          <div style={{ fontSize: '0.95rem', fontWeight: 600 }}>이영희 학생</div>
                          <div style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>17:30 - 학습 부진 면담</div>
                        </div>
                      </div>
                      <button className="btn btn-sm btn-outline">상담일지 작성</button>
                    </div>
                  </div>
                </Card>
              </div>

            </div>
          </div>
        );
      
      case 'tutor':
        return (
          <div style={{ padding: '24px' }}>
            <h2 style={{ fontSize: '1.5rem', fontWeight: 'bold', marginBottom: '24px' }}>멘토 마이 페이지</h2>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' }}>
              <Card title="멘토링 일정">
                <p style={{ color: 'var(--color-text-secondary)' }}>이번 주 예정된 세션: 5건</p>
              </Card>
              <Card title="집중 관리 학생">
                <p style={{ color: 'var(--color-text-secondary)' }}>연락 필요 학생: 2명</p>
              </Card>
              <Card title="최근 멘토링 로그" style={{ gridColumn: '1 / -1' }}>
                <p style={{ color: 'var(--color-text-secondary)' }}>최근 3일 내 작성된 피드백: 12건</p>
              </Card>
            </div>
          </div>
        );

      case 'ops':
        return (
          <div style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '24px' }}>
            {/* 프로필 히어로 섹션 */}
            <div style={{ 
              background: 'linear-gradient(135deg, #0f766e 0%, #0d9488 100%)',
              borderRadius: '16px',
              padding: '32px',
              color: 'white',
              display: 'flex',
              alignItems: 'center',
              gap: '24px',
              boxShadow: '0 10px 25px -5px rgba(13, 148, 136, 0.4)'
            }}>
              <div style={{ position: 'relative' }}>
                <img 
                  src={`https://api.dicebear.com/7.x/avataaars/svg?seed=${user.name}`} 
                  alt="Profile" 
                  style={{ width: '90px', height: '90px', borderRadius: '50%', border: '4px solid rgba(255,255,255,0.3)', background: 'white' }} 
                />
                <span style={{ position: 'absolute', bottom: '4px', right: '4px', width: '16px', height: '16px', backgroundColor: '#22c55e', border: '3px solid white', borderRadius: '50%' }}></span>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px' }}>
                  <h2 style={{ fontSize: '1.8rem', fontWeight: 'bold', margin: 0 }}>{user.nameKo || user.name}</h2>
                  <span style={{ background: 'rgba(255,255,255,0.2)', padding: '4px 12px', borderRadius: '20px', fontSize: '0.85rem', fontWeight: 500 }}>
                    EduOps Manager
                  </span>
                </div>
                <p style={{ margin: 0, opacity: 0.9, fontSize: '1.05rem' }}>오늘도 원활한 부트캠프 운영을 위해 힘써주셔서 감사합니다! ✨</p>
              </div>
              <button 
                onClick={() => navigate('/eduops')}
                style={{ background: 'rgba(255,255,255,0.2)', border: '1px solid rgba(255,255,255,0.4)', color: 'white', padding: '10px 20px', borderRadius: '8px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 600, transition: 'all 0.2s' }}
                onMouseOver={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.3)'}
                onMouseOut={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.2)'}
              >
                <span className="material-icons-outlined">dashboard</span>
                운영 대시보드 가기
              </button>
            </div>

            {/* 핵심 KPI 위젯 */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '20px' }}>
              <div 
                onClick={() => navigate('/eduops/sync')}
                style={{ background: '#fff', border: '1px solid var(--color-border)', borderRadius: '12px', padding: '20px', display: 'flex', alignItems: 'center', gap: '16px', cursor: 'pointer', transition: 'box-shadow 0.2s' }}
                onMouseOver={(e) => e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.05)'}
                onMouseOut={(e) => e.currentTarget.style.boxShadow = 'none'}
              >
                <div style={{ background: '#fef2f2', padding: '16px', borderRadius: '12px', color: '#ef4444' }}>
                  <span className="material-icons-outlined" style={{ fontSize: '32px' }}>sync_problem</span>
                </div>
                <div>
                  <p style={{ margin: 0, fontSize: '0.9rem', color: 'var(--color-text-secondary)', fontWeight: 600 }}>출결 동기화 오류</p>
                  <h3 style={{ margin: '4px 0 0 0', fontSize: '1.8rem', color: '#ef4444' }}>9건</h3>
                </div>
              </div>

              <div 
                onClick={() => navigate('/eduops/inquiries')}
                style={{ background: '#fff', border: '1px solid var(--color-border)', borderRadius: '12px', padding: '20px', display: 'flex', alignItems: 'center', gap: '16px', cursor: 'pointer', transition: 'box-shadow 0.2s' }}
                onMouseOver={(e) => e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.05)'}
                onMouseOut={(e) => e.currentTarget.style.boxShadow = 'none'}
              >
                <div style={{ background: '#fffbeb', padding: '16px', borderRadius: '12px', color: '#f59e0b' }}>
                  <span className="material-icons-outlined" style={{ fontSize: '32px' }}>support_agent</span>
                </div>
                <div>
                  <p style={{ margin: 0, fontSize: '0.9rem', color: 'var(--color-text-secondary)', fontWeight: 600 }}>미해결 문의사항</p>
                  <h3 style={{ margin: '4px 0 0 0', fontSize: '1.8rem', color: '#d97706' }}>5건</h3>
                </div>
              </div>

              <div 
                onClick={() => navigate('/eduops/ai')}
                style={{ background: '#fff', border: '1px solid var(--color-border)', borderRadius: '12px', padding: '20px', display: 'flex', alignItems: 'center', gap: '16px', cursor: 'pointer', transition: 'box-shadow 0.2s' }}
                onMouseOver={(e) => e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.05)'}
                onMouseOut={(e) => e.currentTarget.style.boxShadow = 'none'}
              >
                <div style={{ background: '#f0fdf4', padding: '16px', borderRadius: '12px', color: '#22c55e' }}>
                  <span className="material-icons-outlined" style={{ fontSize: '32px' }}>psychology</span>
                </div>
                <div>
                  <p style={{ margin: 0, fontSize: '0.9rem', color: 'var(--color-text-secondary)', fontWeight: 600 }}>AI 자동화 대기</p>
                  <h3 style={{ margin: '4px 0 0 0', fontSize: '1.8rem', color: '#15803d' }}>3건</h3>
                </div>
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '24px' }}>
              {/* Actionable Task List */}
              <Card title="Actionable Tasks (오늘의 할 일)" titleIcon="checklist" style={{ height: '100%' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px', padding: '16px', background: '#f8fafc', borderRadius: '8px', borderLeft: '4px solid #ef4444' }}>
                    <span className="material-icons-outlined" style={{ color: '#ef4444' }}>warning</span>
                    <div style={{ flex: 1 }}>
                      <h4 style={{ margin: '0 0 4px 0', fontSize: '1rem', color: 'var(--color-text-primary)' }}>김민수 외 13명 자동 경고 발송 필요</h4>
                      <p style={{ margin: 0, fontSize: '0.85rem', color: 'var(--color-text-secondary)' }}>무단 결석 3회 이상 대상자입니다. AI 자동화 탭에서 메시지를 맞춤 변환 후 발송하세요.</p>
                    </div>
                    <button onClick={() => navigate('/eduops/ai')} className="button button--outline btn-sm">이동</button>
                  </div>
                  
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px', padding: '16px', background: '#f8fafc', borderRadius: '8px', borderLeft: '4px solid #f59e0b' }}>
                    <span className="material-icons-outlined" style={{ color: '#f59e0b' }}>help_outline</span>
                    <div style={{ flex: 1 }}>
                      <h4 style={{ margin: '0 0 4px 0', fontSize: '1rem', color: 'var(--color-text-primary)' }}>새로운 장문 문의 2건 등록</h4>
                      <p style={{ margin: 0, fontSize: '0.85rem', color: 'var(--color-text-secondary)' }}>FAQ 의도 파악이 필요합니다. AI 답변 초안 생성을 진행하세요.</p>
                    </div>
                    <button onClick={() => navigate('/eduops/ai')} className="button button--outline btn-sm">이동</button>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px', padding: '16px', background: '#f8fafc', borderRadius: '8px', borderLeft: '4px solid #3b82f6' }}>
                    <span className="material-icons-outlined" style={{ color: '#3b82f6' }}>videocam</span>
                    <div style={{ flex: 1 }}>
                      <h4 style={{ margin: '0 0 4px 0', fontSize: '1rem', color: 'var(--color-text-primary)' }}>금일 스트리밍 링크 갱신 완료</h4>
                      <p style={{ margin: 0, fontSize: '0.85rem', color: 'var(--color-text-secondary)' }}>기술팀에서 방금 Zoom 및 YouTube 송출 링크를 갱신했습니다.</p>
                    </div>
                    <button onClick={() => navigate('/eduops/streams')} className="button button--outline btn-sm">확인</button>
                  </div>
                </div>
              </Card>

              {/* Recent Activity Log */}
              <Card title="Recent Activity" titleIcon="history" style={{ height: '100%' }}>
                <div style={{ position: 'relative', paddingLeft: '20px', marginLeft: '10px', borderLeft: '2px solid var(--color-border)' }}>
                  <div style={{ position: 'relative', marginBottom: '24px' }}>
                    <span style={{ position: 'absolute', left: '-27px', top: '2px', width: '12px', height: '12px', borderRadius: '50%', background: 'var(--color-primary)', border: '2px solid white' }}></span>
                    <p style={{ margin: '0 0 4px 0', fontSize: '0.9rem', color: 'var(--color-text-primary)', fontWeight: 500 }}>"10월 안내" 공지사항 등록</p>
                    <span style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>오늘 09:30 AM</span>
                  </div>
                  
                  <div style={{ position: 'relative', marginBottom: '24px' }}>
                    <span style={{ position: 'absolute', left: '-27px', top: '2px', width: '12px', height: '12px', borderRadius: '50%', background: 'var(--color-text-muted)', border: '2px solid white' }}></span>
                    <p style={{ margin: '0 0 4px 0', fontSize: '0.9rem', color: 'var(--color-text-primary)', fontWeight: 500 }}>주간 리포트 (Week 4) AI 요약 완료</p>
                    <span style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>어제 17:45 PM</span>
                  </div>

                  <div style={{ position: 'relative', marginBottom: '24px' }}>
                    <span style={{ position: 'absolute', left: '-27px', top: '2px', width: '12px', height: '12px', borderRadius: '50%', background: 'var(--color-text-muted)', border: '2px solid white' }}></span>
                    <p style={{ margin: '0 0 4px 0', fontSize: '0.9rem', color: 'var(--color-text-primary)', fontWeight: 500 }}>데이터 교차 검증 (Zoom vs 고용24)</p>
                    <span style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>어제 16:20 PM</span>
                  </div>
                </div>
              </Card>
            </div>
          </div>
        );

      case 'admin': // TechOps
        return (
          <div style={{ padding: '24px' }}>
            <h2 style={{ fontSize: '1.5rem', fontWeight: 'bold', marginBottom: '24px' }}>기술팀 마이 페이지</h2>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' }}>
              <Card title="시스템 상태 요약">
                <p style={{ color: 'var(--color-success)' }}>모든 시스템이 정상 작동 중입니다.</p>
              </Card>
              <Card title="할당된 티켓">
                <p style={{ color: 'var(--color-text-secondary)' }}>대기 중인 이슈: 1건</p>
              </Card>
              <Card title="장비 유지보수" style={{ gridColumn: '1 / -1' }}>
                <p style={{ color: 'var(--color-text-secondary)' }}>A강의실 마이크 배터리 교체 알림 (D-2)</p>
              </Card>
            </div>
          </div>
        );

      case 'owner':
        return (
          <div style={{ padding: '24px' }}>
            <h2 style={{ fontSize: '1.5rem', fontWeight: 'bold', marginBottom: '24px' }}>원장 마이 페이지</h2>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' }}>
              <Card title="핵심 지표">
                <p style={{ color: 'var(--color-text-secondary)' }}>전체 활성 수강생: 450명</p>
                <p style={{ color: 'var(--color-text-secondary)' }}>이번 달 신규 등록자: 120명</p>
              </Card>
              <Card title="과정 만족도">
                <p style={{ color: 'var(--color-text-secondary)' }}>수업별 평균 만족도: 4.8 / 5.0</p>
              </Card>
              <Card title="리포트 요약" style={{ gridColumn: '1 / -1' }}>
                <p style={{ color: 'var(--color-text-secondary)' }}>2024년 2분기 전략 리포트가 생성되었습니다.</p>
              </Card>
            </div>
          </div>
        );

      default:
        return (
          <div style={{ padding: '24px' }}>
            <BackButton />
            <h2 style={{ fontSize: '1.5rem', fontWeight: 'bold', marginBottom: '24px' }}>마이 페이지</h2>
            <p>권한에 따른 맞춤 정보가 없습니다.</p>
          </div>
        );
    }
  };

  /* ── 역할에 따른 레이아웃 분기 ── */
  if (user.role === 'student') {
    return (
      <MobileLayout title="마이 페이지" bottomNavItems={studentBottomNav} showFAB={true}>
        {renderContent()}
      </MobileLayout>
    );
  }

  // 관리자 계열: DesktopLayout
  let menuItems = instructorMenuItems;
  let brandTitle = "EduAI";

  switch (user.role) {
    case 'instructor':
    case 'tutor':
      menuItems = instructorMenuItems;
      brandTitle = "EduAI Instructor";
      break;
    case 'ops':
      menuItems = opsMenu;
      brandTitle = "EduAI Ops";
      break;
    case 'admin':
      menuItems = techMenu;
      brandTitle = "EduAI Tech";
      break;
    case 'owner':
      menuItems = executiveMenuItems;
      brandTitle = "EduAI Executive";
      break;
  }

  return (
    <DesktopLayout
      brandTitle={brandTitle}
      menuItems={menuItems}
      user={user}
      headerTitle="마이 페이지"
      headerAction={headerAction}
      headerActionIcon={headerActionIcon}
      onHeaderAction={handleBack}
    >
      {renderContent()}
    </DesktopLayout>
  );
}
