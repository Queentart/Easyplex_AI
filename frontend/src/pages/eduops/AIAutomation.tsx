import { useState } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import ProgressBar from '../../components/common/ProgressBar';
import { opsUser, opsMenu, warningTargetGroup } from '../../data/eduops';
import './EduOps.css';

interface FAQ {
  id: string;
  query: string;
  issue: string;
  confidence: number;
  draft?: string;
  isDrafting?: boolean;
}

interface Report {
  id: string;
  filename: string;
  generatedAt: string;
  status: 'ready' | 'processing';
  progress?: number;
}

const INITIAL_FAQS: FAQ[] = [
  { id: '1', query: '퇴실 처리 언제까지 가능한가요?', issue: 'Missing specific attendance policy context.', confidence: 42 },
  { id: '2', query: '오늘 결석하면 어떻게 되나요?', issue: 'Vague intent (Sick leave vs Unexcused).', confidence: 38 },
];

const INITIAL_REPORTS: Report[] = [
  { id: 'r1', filename: 'CS_Fall2024_Kim_Minsu_Profile.pdf', generatedAt: 'Oct 24, 06:41 AM', status: 'ready' },
  { id: 'r2', filename: 'CS_Fall2024_Batch_Generation.pdf', generatedAt: 'Oct 24, 06:45 AM', status: 'processing', progress: 45 },
];

export default function AIAutomation() {
  const [faqs, setFaqs] = useState<FAQ[]>(INITIAL_FAQS);
  const [reports, setReports] = useState<Report[]>(INITIAL_REPORTS);
  const [isGeneratingReport, setIsGeneratingReport] = useState(false);

  const [messageMode, setMessageMode] = useState<'template' | 'personalized'>('template');
  const [warningMessage, setWarningMessage] = useState('Dear [Student_Name], this is an official notification regarding your recent academic standing...');
  const [isPersonalizing, setIsPersonalizing] = useState(false);

  // 시뮬레이션: LLM을 호출하여 답변 초안 작성 (Local Model, keep_alive: 0 파라미터 적용)
  const generateDraft = (faqId: string) => {
    setFaqs(prev => prev.map(f => f.id === faqId ? { ...f, isDrafting: true } : f));

    // 실제 백엔드 연동 시 아래와 같은 페이로드가 전송됩니다:
    /*
    apiClient.post('/ai/generate', {
      prompt: `다음 학생 문의에 대한 규정집 기반 답변 초안을 작성해 줘: ${faq.query}`,
      extra_body: { keep_alive: 0 } // 로컬 모델 메모리 절약을 위한 필수 파라미터
    });
    */

    setTimeout(() => {
      setFaqs(prev => prev.map(f => {
        if (f.id === faqId) {
          let mockDraft = '안녕하세요, 규정에 따르면 퇴실 처리는 수업 종료 후 10분 이내에 완료하셔야 합니다.';
          if (f.id === '2') mockDraft = '질병으로 인한 결석의 경우 병원 진단서를 제출하시면 출석으로 인정될 수 있습니다. 단순 변심인 경우 무단 결석 처리됩니다.';
          return { ...f, isDrafting: false, draft: mockDraft };
        }
        return f;
      }));
    }, 2000);
  };

  // 시뮬레이션: 다수의 일지(Training/Mentoring Logs)를 분석하여 주간/월간 리포트 생성
  const handleGenerateReport = () => {
    setIsGeneratingReport(true);
    
    // 백엔드 비동기 작업 지시 시뮬레이션 (extra_body: { keep_alive: 0 })
    setTimeout(() => {
      const newReport: Report = {
        id: `r${Date.now()}`,
        filename: `CS_Fall2024_Weekly_Summary_${new Date().getDate()}.pdf`,
        generatedAt: new Date().toLocaleTimeString(),
        status: 'processing',
        progress: 0
      };
      setReports([newReport, ...reports]);
      setIsGeneratingReport(false);

      // 프로그레스 바 시뮬레이션
      let currentProgress = 0;
      const interval = setInterval(() => {
        currentProgress += 20;
        setReports(prev => prev.map(r => r.id === newReport.id ? { ...r, progress: currentProgress } : r));
        if (currentProgress >= 100) {
          clearInterval(interval);
          setReports(prev => prev.map(r => r.id === newReport.id ? { ...r, status: 'ready' } : r));
        }
      }, 1000);
    }, 500);
  };

  // 시뮬레이션: 경고 대상자들의 멘토링 특이사항을 반영하여 단호하지만 부드러운 개인화 메시지 생성
  const handlePersonalizeWarning = () => {
    setIsPersonalizing(true);

    // 실제 백엔드 연동 시 아래와 같은 페이로드가 전송됩니다:
    /*
    apiClient.post('/ai/personalize-warning', {
      template: warningMessage,
      target_group_context: warningTargetGroup,
      extra_body: { keep_alive: 0 } // 로컬 모델 메모리 절약을 위한 필수 파라미터
    });
    */

    setTimeout(() => {
      setWarningMessage('안녕하세요 [학생명]님, 최근 [결석일자]에 무단 결석하신 기록이 확인되었습니다. 멘토링 일지에 따르면 평소 수업에 성실히 참여하고 계신 만큼, 향후 수료에 불이익이 없도록 출결 관리에 각별히 신경 써 주시기를 당부드립니다.');
      setMessageMode('personalized');
      setIsPersonalizing(false);
    }, 2500);
  };

  return (
    <DesktopLayout
      brandTitle="EduOps Center"
      brandSubtitle="운영 관리 대시보드"
      menuItems={opsMenu}
      user={opsUser}
      showFooterLinks={true}
      headerTitle="AI Automation & Report Generation"
      headerAction="Generate New Report"
      headerActionIcon="description"
      onHeaderActionClick={handleGenerateReport}
    >
      <div className="exec-cards exec-cards--2">
        {/* ── Flagged FAQ Queries (의도 파악 및 초안 작성) ── */}
        <Card title="Flagged FAQ Queries (LLM Draft)" titleIcon="psychology">
          <div className="flagged-query-list" style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
            {faqs.map(q => (
              <div key={q.id} style={{ border: '1px solid var(--color-border)', borderRadius: '8px', padding: '1rem', backgroundColor: '#fff' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.5rem' }}>
                  <span style={{ fontWeight: 600, color: 'var(--color-text-primary)' }}>"{q.query}"</span>
                  <StatusTag label={`Confidence: ${q.confidence}%`} variant="warning" />
                </div>
                <div style={{ fontSize: '0.85rem', color: 'var(--color-text-secondary)', marginBottom: '1rem' }}>
                  Issue: {q.issue}
                </div>
                
                {q.draft ? (
                  <div style={{ backgroundColor: '#f0fdf4', padding: '1rem', borderRadius: '4px', border: '1px solid #bbf7d0', marginTop: '0.5rem' }}>
                    <p style={{ fontSize: '0.8rem', fontWeight: 'bold', color: '#166534', marginBottom: '0.5rem' }}>✨ AI Suggested Draft</p>
                    <p style={{ fontSize: '0.9rem', color: '#15803d', margin: 0 }}>{q.draft}</p>
                    <div style={{ display: 'flex', gap: '0.5rem', marginTop: '1rem' }}>
                      <button className="button button--primary btn-sm" style={{ padding: '0.2rem 0.5rem', fontSize: '0.8rem' }}>승인 및 발송</button>
                      <button className="button button--outline btn-sm" style={{ padding: '0.2rem 0.5rem', fontSize: '0.8rem' }}>직접 수정</button>
                    </div>
                  </div>
                ) : (
                  <button 
                    className="button button--outline btn-sm" 
                    onClick={() => generateDraft(q.id)}
                    disabled={q.isDrafting}
                    style={{ width: '100%' }}
                  >
                    {q.isDrafting ? '로컬 LLM 응답 생성 중...' : '✨ AI 답변 초안 생성'}
                  </button>
                )}
              </div>
            ))}
          </div>
        </Card>

        {/* ── Generated Reports (학습/멘토링 일지 기반 자동 요약) ── */}
        <Card title="Generated Reports (LLM Summary)" titleIcon="folder">
          <div className="report-list" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            {reports.map(report => (
              <div key={report.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '1rem', border: '1px solid var(--color-border)', borderRadius: '8px', backgroundColor: '#fff' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                  <span className="material-icons-outlined" style={{ fontSize: '24px', color: report.status === 'ready' ? 'var(--color-primary)' : 'var(--color-text-muted)' }}>
                    {report.status === 'ready' ? 'picture_as_pdf' : 'hourglass_top'}
                  </span>
                  <div>
                    <div style={{ fontWeight: 500, color: 'var(--color-text-primary)' }}>{report.filename}</div>
                    <div style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>{report.generatedAt}</div>
                  </div>
                </div>
                {report.status === 'ready' ? (
                  <StatusTag label="Ready" variant="success" icon="check_circle" />
                ) : (
                  <div style={{ minWidth: '100px' }}>
                    <ProgressBar value={report.progress || 0} size="sm" />
                    <div style={{ fontSize: '0.75rem', color: 'var(--color-text-secondary)', textAlign: 'right', marginTop: '0.25rem' }}>{report.progress}%</div>
                  </div>
                )}
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* ── Automated Warning System (개인화 메시지 변환) ── */}
      <div style={{ marginTop: 'var(--space-6)' }}>
        <Card title="Automated Warning System (LLM Personalization)" titleIcon="notifications_active">
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', padding: '1rem', backgroundColor: '#fff7ed', border: '1px solid #fdba74', borderRadius: '4px', color: '#c2410c', fontWeight: 500, marginBottom: '1.5rem' }}>
            <span className="material-icons-outlined">warning</span>
            알고리즘 추출: {warningTargetGroup}
          </div>
          
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '0.5rem' }}>
              <h4 style={{ margin: 0 }}>Message Content</h4>
              {messageMode === 'template' && (
                <button 
                  className="button button--outline btn-sm"
                  onClick={handlePersonalizeWarning}
                  disabled={isPersonalizing}
                  style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}
                >
                  <span className="material-icons-outlined" style={{ fontSize: '16px' }}>auto_awesome</span>
                  {isPersonalizing ? '로컬 LLM 생성 중...' : '학생별 맞춤형(따뜻한 어조) 자동 변환'}
                </button>
              )}
            </div>
            <textarea 
              className="message-template" 
              style={{ width: '100%', minHeight: '120px', padding: '1rem', borderRadius: '4px', border: `1px solid ${messageMode === 'personalized' ? '#bbf7d0' : 'var(--color-border)'}`, backgroundColor: messageMode === 'personalized' ? '#f0fdf4' : '#f9fafb', fontSize: '0.95rem', resize: 'vertical' }}
              value={warningMessage}
              onChange={(e) => setWarningMessage(e.target.value)}
            />
          </div>
          
          <div style={{ display: 'flex', gap: '1rem', marginTop: '1.5rem' }}>
            <button className="button button--primary" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <span className="material-icons-outlined" style={{ fontSize: '18px' }}>send</span>
              알림 일괄 발송
            </button>
            {messageMode === 'personalized' && (
              <button 
                className="button button--outline" 
                onClick={() => {
                  setMessageMode('template');
                  setWarningMessage('Dear [Student_Name], this is an official notification regarding your recent academic standing...');
                }}
              >
                원래 템플릿으로 복구
              </button>
            )}
          </div>
        </Card>
      </div>
    </DesktopLayout>
  );
}
