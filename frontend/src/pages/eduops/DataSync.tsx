import { useState, useRef } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import DataTable from '../../components/common/Table';
import StatusTag from '../../components/common/StatusTag';
import Card from '../../components/common/Card';
import { opsUser, opsMenu } from '../../data/eduops';
import './EduOps.css';

interface SyncRecord {
  id: string;
  name: string;
  date: string;
  goyong24: string;
  zoom: string;
  status: 'matched' | 'mismatch';
}

const MOCK_RESULTS: SyncRecord[] = [
  { id: '1', name: '이시윤', date: '2026-06-25', goyong24: '09:00 AM', zoom: '09:15 AM', status: 'mismatch' },
  { id: '2', name: '김민수', date: '2026-06-25', goyong24: '08:55 AM', zoom: '08:54 AM', status: 'matched' },
  { id: '3', name: '박준영', date: '2026-06-25', goyong24: '08:50 AM', zoom: '08:48 AM', status: 'matched' },
];

export default function DataSync() {
  const [zoomFile, setZoomFile] = useState<File | null>(null);
  const [goyongFile, setGoyongFile] = useState<File | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [results, setResults] = useState<SyncRecord[] | null>(null);

  const zoomInputRef = useRef<HTMLInputElement>(null);
  const goyongInputRef = useRef<HTMLInputElement>(null);

  const handleProcess = () => {
    if (!zoomFile || !goyongFile) {
      alert('Zoom 로그와 고용24 로그 파일을 모두 업로드해주세요.');
      return;
    }
    
    setIsProcessing(true);
    // Simulate algorithm processing
    setTimeout(() => {
      setResults(MOCK_RESULTS);
      setIsProcessing(false);
    }, 1500);
  };

  const resetProcess = () => {
    setZoomFile(null);
    setGoyongFile(null);
    setResults(null);
  };

  const columns = [
    { key: 'name', header: 'STUDENT NAME' },
    { key: 'date', header: 'DATE' },
    { key: 'goyong24', header: 'GOYONG 24 RECORD' },
    { key: 'zoom', header: 'ZOOM LOG' },
    {
      key: 'status', header: 'STATUS',
      render: (val: string) => (
        <StatusTag
          label={val === 'matched' ? 'Matched' : 'Mismatch'}
          variant={val === 'matched' ? 'success' : 'danger'}
          icon={val === 'matched' ? 'check_circle' : 'error'}
        />
      ),
    },
  ];

  return (
    <DesktopLayout
      brandTitle="EduOps Center"
      brandSubtitle="운영 관리 대시보드"
      menuItems={opsMenu}
      user={opsUser}
      showFooterLinks={true}
      headerTitle="Data Sync & Attendance Verification"
      headerAction="Force Sync Now"
      headerActionIcon="sync"
    >
      <div className="eduops-layout">
        <div className="col-12" style={{ padding: 'var(--space-6)' }}>
          <header style={{ marginBottom: 'var(--space-6)' }}>
            <h1 className="text-2xl font-bold text-gray-800">Attendance Cross-Verification</h1>
            <p className="text-gray-500 mt-1">
              Zoom 출석 로그와 고용24(HRD-Net) 출결 기록 파일을 업로드하면 알고리즘이 자동으로 이름과 타임스탬프를 대조하여 불일치(Mismatch) 항목을 찾아냅니다.
            </p>
          </header>

          {!results ? (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', marginBottom: '2rem' }}>
              <Card title="Zoom Log (.csv)" titleIcon="videocam">
                <div 
                  onClick={() => zoomInputRef.current?.click()}
                  style={{
                    border: '2px dashed var(--color-border)',
                    borderRadius: '8px',
                    padding: '3rem 1rem',
                    textAlign: 'center',
                    cursor: 'pointer',
                    backgroundColor: zoomFile ? 'var(--color-bg-alt)' : 'transparent',
                    transition: 'all 0.2s ease'
                  }}
                >
                  <span className="material-icons-outlined" style={{ fontSize: '3rem', color: zoomFile ? 'var(--color-primary)' : 'var(--color-text-muted)' }}>
                    {zoomFile ? 'task' : 'upload_file'}
                  </span>
                  <p style={{ marginTop: '1rem', fontWeight: 500, color: 'var(--color-text-primary)' }}>
                    {zoomFile ? zoomFile.name : 'Click to upload Zoom CSV file'}
                  </p>
                  <input type="file" accept=".csv,.xlsx" hidden ref={zoomInputRef} onChange={(e) => { if (e.target.files?.[0]) setZoomFile(e.target.files[0]); }} />
                </div>
              </Card>

              <Card title="고용24 Log (.csv)" titleIcon="fact_check">
                <div 
                  onClick={() => goyongInputRef.current?.click()}
                  style={{
                    border: '2px dashed var(--color-border)',
                    borderRadius: '8px',
                    padding: '3rem 1rem',
                    textAlign: 'center',
                    cursor: 'pointer',
                    backgroundColor: goyongFile ? 'var(--color-bg-alt)' : 'transparent',
                    transition: 'all 0.2s ease'
                  }}
                >
                  <span className="material-icons-outlined" style={{ fontSize: '3rem', color: goyongFile ? 'var(--color-success)' : 'var(--color-text-muted)' }}>
                    {goyongFile ? 'task' : 'upload_file'}
                  </span>
                  <p style={{ marginTop: '1rem', fontWeight: 500, color: 'var(--color-text-primary)' }}>
                    {goyongFile ? goyongFile.name : 'Click to upload 고용24 CSV file'}
                  </p>
                  <input type="file" accept=".csv,.xlsx" hidden ref={goyongInputRef} onChange={(e) => { if (e.target.files?.[0]) setGoyongFile(e.target.files[0]); }} />
                </div>
              </Card>

              <div style={{ gridColumn: '1 / -1', textAlign: 'center', marginTop: '1rem' }}>
                <button 
                  className={`button ${zoomFile && goyongFile ? 'button--primary' : 'button--outline'}`} 
                  style={{ padding: '0.75rem 3rem', fontSize: '1.1rem' }}
                  onClick={handleProcess}
                  disabled={isProcessing}
                >
                  {isProcessing ? '비교 알고리즘 실행 중...' : '데이터 대조 시작'}
                </button>
              </div>
            </div>
          ) : (
            <div>
              <div className="sync-status-bar" style={{ marginBottom: '1.5rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div className="sync-status-info">
                  <span className="sync-indicator" />
                  <span>알고리즘 대조 완료: <strong>방금 전</strong></span>
                </div>
                <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
                  <StatusTag
                    label={`${results.filter(r => r.status === 'mismatch').length} Mismatches Found`}
                    variant="danger"
                    icon="warning"
                  />
                  <button className="button button--outline btn-sm" onClick={resetProcess}>다시 업로드</button>
                </div>
              </div>
              <Card compact>
                <DataTable columns={columns} data={results} />
              </Card>
            </div>
          )}
        </div>
      </div>
    </DesktopLayout>
  );
}
