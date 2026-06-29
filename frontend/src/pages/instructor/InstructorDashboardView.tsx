import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import { useNavigate } from 'react-router-dom';
import {
  dashboardStats,
  assignmentTasks,
  counselingList,
  pendingQuestions,
  recentMaterials,
  recentLogs,
} from '../../data/instructor';

export default function InstructorDashboardView() {
  const navigate = useNavigate();

  return (
    <div className="instructor-dashboard-grid">
      {/* =========================================================
          High Priority (최상단, 강조, 크게)
      ========================================================= */}
      <div className="dashboard-section priority-high">
        {/* 1. 학습 질문 게시판 */}
        <Card 
          title="학습 질문 게시판" 
          titleIcon="question_answer" 
          className="card-highlight card-highlight-warning"
          action={<button className="button button--text" onClick={() => navigate('/instructor/learning-questions')}>View All</button>}
        >
          <div className="list-container">
            <h4 className="list-title text-warning">미답변 질문 ({pendingQuestions.length})</h4>
            {pendingQuestions.map(q => (
              <div key={q.id} className={`list-item ${q.urgent ? 'urgent-item' : ''}`}>
                <div className="list-item-header">
                  <strong className={q.urgent ? 'text-danger' : ''}>{q.title}</strong>
                  {q.urgent && <StatusTag label="Urgent" variant="danger" />}
                </div>
                <div className="list-item-desc text-muted">{q.student} - {q.time}</div>
              </div>
            ))}
          </div>
        </Card>

        {/* 2. 과제 (Assignments) */}
        <Card 
          title="과제 현황" 
          titleIcon="assignment" 
          className="card-highlight card-highlight-primary"
          action={<button className="button button--text" onClick={() => navigate('/instructor/assignments')}>Grade</button>}
        >
          <div className="stats-row">
            <div className="stat-item highlight-box">
              <span className="stat-label">To Grade</span>
              <span className="stat-value text-primary">{dashboardStats.assignmentsToGrade}</span>
            </div>
          </div>
          <div className="list-container">
            <h4 className="list-title">최근 과제 마감</h4>
            {assignmentTasks.slice(0, 2).map(task => (
              <div key={task.id} className="list-item compact">
                <div className="list-item-header">
                  <strong>{task.title}</strong>
                </div>
                <div className="list-item-desc text-muted">
                  Submitted: {task.submitted}/{task.total} | AI Graded: {task.aiGraded}
                </div>
                <div className="list-item-desc text-danger" style={{ fontSize: '11px', marginTop: 4 }}>Deadline: {task.deadline}</div>
              </div>
            ))}
          </div>
        </Card>

        {/* 3. 학생 상담 (Student Counseling) */}
        <Card 
          title="학생 상담 알림" 
          titleIcon="psychology" 
          className="card-highlight card-highlight-danger"
          action={<button className="button button--text" onClick={() => navigate('/instructor/counseling')}>Manage</button>}
        >
          <div className="list-container">
            <h4 className="list-title text-danger">AI 개입 요망 ({counselingList.length})</h4>
            {counselingList.map(c => (
              <div key={c.id} className="list-item danger-border">
                <div className="list-item-header">
                  <strong>{c.name}</strong>
                  <StatusTag label={c.urgency} variant={c.urgency === 'High' ? 'danger' : 'warning'} />
                </div>
                <div className="list-item-desc text-muted">Issue: {c.issue}</div>
                <div className="list-item-desc" style={{ fontSize: '12px', color: 'var(--color-primary)', marginTop: 4 }}>
                  💡 AI Suggestion: {c.aiSuggestion}
                </div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* =========================================================
          Medium Priority (중단 영역, 기본 카드)
      ========================================================= */}
      <div className="dashboard-section priority-medium">
        {/* 1. 학습 일지 */}
        <Card 
          title="학습 일지 현황" 
          titleIcon="menu_book"
          action={<button className="button button--text" onClick={() => navigate('/instructor/training-logs')}>Logs</button>}
        >
          <div className="list-container">
            {recentLogs.map(log => (
              <div key={log.id} className="list-item compact">
                <div className="list-item-header">
                  <strong>{log.title}</strong>
                  <StatusTag label={log.status} variant={log.status === 'Review Needed' ? 'warning' : 'success'} />
                </div>
                <div className="list-item-desc text-muted">{log.author} - {log.time}</div>
              </div>
            ))}
          </div>
        </Card>

        {/* 2. 강의 자료 관리 */}
        <Card 
          title="최근 업로드된 강의 자료" 
          titleIcon="library_books"
          action={<button className="button button--text" onClick={() => navigate('/instructor/materials')}>Materials</button>}
        >
          <div className="list-container">
            {recentMaterials.map(mat => (
              <div key={mat.id} className="list-item compact">
                <div className="list-item-header">
                  <strong>{mat.title}</strong>
                  <StatusTag label={mat.type} variant="info" />
                </div>
                <div className="list-item-desc text-muted">Uploaded: {mat.uploaded}</div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* =========================================================
          Low Priority (하단 영역, Quick Links)
      ========================================================= */}
      <div className="dashboard-section priority-low">
        <h3 className="section-heading">Quick Links</h3>
        <div className="quick-links-panel">
          <button className="quick-link-btn" onClick={() => navigate('/instructor/streams')}>
            <span className="material-icons text-primary">ondemand_video</span>
            <span>실시간 스트리밍</span>
          </button>
          <button className="quick-link-btn" onClick={() => navigate('/instructor/curriculum')}>
            <span className="material-icons text-primary">route</span>
            <span>커리큘럼 로드맵</span>
          </button>
        </div>
      </div>
    </div>
  );
}
