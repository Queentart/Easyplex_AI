import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import { useNavigate } from 'react-router-dom';
import {
  dashboardStats,
  assignmentTasks,
  pendingQuestions,
  recentMaterials,
  tutorMentoringSessions,
  tutorPendingLogs,
} from '../../data/instructor';

export default function TutorDashboardView() {
  const navigate = useNavigate();

  return (
    <div className="instructor-dashboard-grid">
      {/* =========================================================
          High Priority (최상단, 강조, 크게)
      ========================================================= */}
      <div className="dashboard-section priority-high">
        {/* 1. 멘토링 일지 (Mentoring Logs) */}
        <Card 
          title="멘토링 일지 현황" 
          titleIcon="import_contacts" 
          className="card-highlight card-highlight-success"
          action={<button className="button button--text" onClick={() => navigate('/instructor/mentoring-logs')}>Write Log</button>}
        >
          <div className="list-container">
            <h4 className="list-title text-success">작성 대기중인 일지 ({tutorPendingLogs.length})</h4>
            {tutorPendingLogs.map(log => (
              <div key={log.id} className={`list-item ${log.urgent ? 'urgent-item' : ''}`}>
                <div className="list-item-header">
                  <strong className={log.urgent ? 'text-danger' : ''}>{log.title}</strong>
                  {log.urgent && <StatusTag label="Urgent" variant="danger" />}
                </div>
                <div className="list-item-desc text-muted">Due: {log.dueDate}</div>
              </div>
            ))}
          </div>
        </Card>

        {/* 2. 학생 상담 알림 (Student Counseling) */}
        <Card 
          title="진행 예정 멘토링" 
          titleIcon="psychology" 
          className="card-highlight card-highlight-danger"
          action={<button className="button button--text" onClick={() => navigate('/instructor/counseling')}>Manage</button>}
        >
          <div className="list-container">
            <h4 className="list-title text-danger">Upcoming Sessions ({tutorMentoringSessions.length})</h4>
            {tutorMentoringSessions.map(session => (
              <div key={session.id} className="list-item danger-border">
                <div className="list-item-header">
                  <strong>{session.student}</strong>
                  <StatusTag label={session.status} variant="warning" />
                </div>
                <div className="list-item-desc text-muted">{session.time}</div>
                <div className="list-item-desc" style={{ fontSize: '12px', color: 'var(--color-primary)', marginTop: 4 }}>
                  Topic: {session.topic}
                </div>
              </div>
            ))}
          </div>
        </Card>

        {/* 3. 학습 질문 게시판 (Learning Questions) */}
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
      </div>

      {/* =========================================================
          Medium Priority (중단 영역, 기본 카드)
      ========================================================= */}
      <div className="dashboard-section priority-medium">
        {/* 1. 과제 (Assignments) - 보조 채점 */}
        <Card 
          title="과제 보조 채점" 
          titleIcon="assignment"
          action={<button className="button button--text" onClick={() => navigate('/instructor/assignments')}>Grade</button>}
        >
          <div className="stats-row" style={{ marginBottom: 'var(--space-3)' }}>
            <div className="stat-item highlight-box">
              <span className="stat-label">To Grade (Assigned to you)</span>
              <span className="stat-value text-primary">{Math.floor(dashboardStats.assignmentsToGrade / 2)}</span>
            </div>
          </div>
          <div className="list-container">
            {assignmentTasks.slice(0, 2).map(task => (
              <div key={task.id} className="list-item compact">
                <div className="list-item-header">
                  <strong>{task.title}</strong>
                </div>
                <div className="list-item-desc text-muted">
                  Submitted: {task.submitted}/{task.total}
                </div>
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
