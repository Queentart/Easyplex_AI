import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import { useNavigate } from 'react-router-dom';
import { 
  opsUser, opsMenu, studentStats, counselingLogs, 
  pendingInquiries, recentAnnouncements, syncStatus, flaggedQueries 
} from '../../data/eduops';
import './EduOps.css';

export default function EduOpsDashboard() {
  const navigate = useNavigate();

  return (
    <DesktopLayout
      brandTitle="EduOps Center"
      brandSubtitle="운영 관리 대시보드"
      menuItems={opsMenu}
      user={opsUser}
      sidebarAction="Quick Report"
      sidebarActionIcon="description"
      showFooterLinks={true}
      headerTitle="EduOps Dashboard"
      showSearch={true}
      searchPlaceholder="Search dashboard..."
    >
      <div className="eduops-dashboard-grid">
        {/* =========================================================
            High Priority (최상단, 강조)
        ========================================================= */}
        <div className="dashboard-section high-priority">
          <Card 
            title="학생 관리 요약" 
            titleIcon="people" 
            className="card-high-priority"
            action={<button className="button button--text" onClick={() => navigate('/eduops/students')}>View All</button>}
          >
            <div className="stats-row">
              <div className="stat-item">
                <span className="stat-label">Total Active Students</span>
                <span className="stat-value">{studentStats.totalActive}</span>
              </div>
              <div className="stat-item danger-highlight">
                <span className="stat-label">Attendance Warnings</span>
                <span className="stat-value text-danger">{studentStats.attendanceWarning}</span>
              </div>
            </div>
            <div className="recent-list">
              <h4 className="list-title">최근 상담 로그</h4>
              {counselingLogs.slice(0, 2).map((log, i) => (
                <div key={i} className="list-item">
                  <div className="list-item-header">
                    <strong>{log.studentName}</strong> <span className="text-muted">({log.date})</span>
                    <StatusTag label={log.type} variant={log.type === 'Intervention' ? 'warning' : 'info'} />
                  </div>
                  <div className="list-item-desc text-muted">{log.summary}</div>
                </div>
              ))}
            </div>
          </Card>

          <Card 
            title="문의 및 공지사항" 
            titleIcon="campaign" 
            className="card-high-priority"
            action={<button className="button button--text" onClick={() => navigate('/eduops/inquiries')}>Manage</button>}
          >
            <div className="split-list">
              <div className="list-section">
                <h4 className="list-title text-warning">미해결 문의 ({pendingInquiries.length})</h4>
                {pendingInquiries.map(inq => (
                  <div key={inq.id} className="list-item">
                    <div className="list-item-header">
                      <strong>{inq.title}</strong>
                    </div>
                    <div className="list-item-desc text-muted">{inq.student} - {inq.date}</div>
                  </div>
                ))}
              </div>
              <div className="list-section">
                <h4 className="list-title">최근 공지사항</h4>
                {recentAnnouncements.map(ann => (
                  <div key={ann.id} className="list-item">
                    <div className="list-item-header">
                      <strong style={{ color: ann.important ? 'var(--color-danger)' : 'inherit' }}>{ann.title}</strong>
                    </div>
                    <div className="list-item-desc text-muted">{ann.date}</div>
                  </div>
                ))}
              </div>
            </div>
          </Card>
        </div>

        {/* =========================================================
            Medium Priority (중단, 기본 카드 크기)
        ========================================================= */}
        <div className="dashboard-section medium-priority">
          <Card 
            title="데이터 동기화" 
            titleIcon="sync"
            action={<button className="button button--text" onClick={() => navigate('/eduops/sync')}>Check</button>}
          >
            <div className="stats-row sync-status">
              <div className="stat-item">
                <span className="stat-label">Last Synced</span>
                <span className="stat-value small-text">{syncStatus.lastSynced}</span>
              </div>
              <div className={`stat-item ${syncStatus.dataMismatches > 0 ? 'warning-highlight' : ''}`}>
                <span className="stat-label">Mismatches</span>
                <span className={`stat-value ${syncStatus.dataMismatches > 0 ? 'text-warning' : ''}`}>{syncStatus.dataMismatches}</span>
              </div>
            </div>
          </Card>

          <Card 
            title="AI 자동화" 
            titleIcon="smart_toy"
            action={<button className="button button--text" onClick={() => navigate('/eduops/ai')}>View AI</button>}
          >
            <div className="recent-list">
              <h4 className="list-title">Flagged Queries ({flaggedQueries.length})</h4>
              {flaggedQueries.slice(0, 2).map(fq => (
                <div key={fq.id} className="list-item compact">
                  <div className="list-item-header">"{fq.query}"</div>
                  <div className="list-item-desc text-danger">Issue: {fq.issue}</div>
                </div>
              ))}
            </div>
          </Card>
          
          <Card 
            title="강의 자료 및 일지" 
            titleIcon="library_books"
            action={<button className="button button--text" onClick={() => navigate('/eduops/instructor-logs')}>Logs</button>}
          >
            <div className="empty-state">
              <span className="material-icons text-success" style={{ fontSize: 32, opacity: 0.8, marginBottom: 8 }}>check_circle</span>
              <p className="text-muted">모든 강사 일지가 정상 등록되었습니다.</p>
            </div>
          </Card>
        </div>

        {/* =========================================================
            Low Priority (하단, Quick Links)
        ========================================================= */}
        <div className="dashboard-section low-priority">
          <h3 className="section-heading">Quick Links</h3>
          <div className="quick-links-grid">
            <button className="quick-link-btn" onClick={() => navigate('/eduops/streams')}>
              <span className="material-icons">ondemand_video</span>
              <span>실시간 강의 링크</span>
            </button>
            <button className="quick-link-btn" onClick={() => navigate('/eduops/curriculum')}>
              <span className="material-icons">route</span>
              <span>커리큘럼 로드맵</span>
            </button>
            <button className="quick-link-btn" onClick={() => navigate('/eduops/settings')}>
              <span className="material-icons">settings</span>
              <span>운영팀 설정</span>
            </button>
          </div>
        </div>
      </div>
    </DesktopLayout>
  );
}
