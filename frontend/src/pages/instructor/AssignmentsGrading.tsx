/* ==========================================================
 * AssignmentsGrading 페이지
 * ----------------------------------------------------------
 * (목업 화면 #3) Assignments & Grading Dashboard
 * 과제 제출 현황 및 AI 자동 채점 시스템
 * ========================================================== */

import { useState, useEffect } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import Modal from '../../components/common/Modal';
import { useAuth } from '../../contexts/AuthContext';
import { instructorUser, instructorMenuItems } from '../../data/instructor';
import { assignmentApi, type AssignmentTask, type AssignmentSubmission } from '../../api/assignmentApi';
import './Instructor.css';

export default function AssignmentsGrading() {
  const { user } = useAuth();
  const currentUser = user || instructorUser;
  
  const [tasks, setTasks] = useState<AssignmentTask[]>([]);
  const [submissions, setSubmissions] = useState<AssignmentSubmission[]>([]);
  const [selectedTask, setSelectedTask] = useState<AssignmentTask | null>(null);
  
  // Modals state
  const [isNewAssignmentOpen, setIsNewAssignmentOpen] = useState(false);
  const [selectedSubmission, setSelectedSubmission] = useState<AssignmentSubmission | null>(null);

  // New assignment form state
  const [newTitle, setNewTitle] = useState('');
  const [newDescription, setNewDescription] = useState('');
  const [newDeadline, setNewDeadline] = useState('');

  // Grading form state
  const [finalScore, setFinalScore] = useState<number | ''>('');
  const [finalFeedback, setFinalFeedback] = useState('');
  const [isGrading, setIsGrading] = useState(false);

  useEffect(() => {
    const loadTasks = async () => {
      try {
        const data = await assignmentApi.getTasks();
        setTasks(data);
      } catch (err) {
        console.error(err);
      }
    };
    loadTasks();
  }, []);

  const fetchTasks = async () => {
    try {
      const data = await assignmentApi.getTasks();
      setTasks(data);
    } catch (err) {
      console.error(err);
    }
  };

  const handleTaskSelect = async (task: AssignmentTask) => {
    setSelectedTask(task);
    try {
      const data = await assignmentApi.getSubmissions(task.id);
      setSubmissions(data);
    } catch (err) {
      console.error(err);
    }
  };

  const handleCreateAssignment = async () => {
    if (!newTitle || !newDescription) {
      alert("Title and description are required");
      return;
    }
    try {
      const deadline = newDeadline ? new Date(newDeadline).toISOString() : new Date().toISOString();
      await assignmentApi.createTask({ title: newTitle, description: newDescription, deadline });
      setIsNewAssignmentOpen(false);
      setNewTitle('');
      setNewDescription('');
      setNewDeadline('');
      fetchTasks();
    } catch (err) {
      console.error(err);
      alert("Failed to create assignment");
    }
  };

  const handleOpenGrading = (sub: AssignmentSubmission) => {
    setSelectedSubmission(sub);
    setFinalScore(sub.final_score ?? sub.ai_score ?? '');
    setFinalFeedback(sub.final_feedback ?? sub.ai_feedback ?? '');
  };

  const handleRunAIGrading = async () => {
    if (!selectedSubmission || !selectedTask) return;
    setIsGrading(true);
    try {
      const data = await assignmentApi.generateGrading(
        selectedSubmission.student_name,
        selectedTask.title,
        selectedSubmission.content,
        selectedSubmission.file_url,
        selectedSubmission.file_name
      );
      setFinalScore(data.score);
      setFinalFeedback(data.feedback);
      
      // Update local state to reflect AI score preview
      setSelectedSubmission({
        ...selectedSubmission,
        ai_score: data.score,
        ai_confidence: data.ai_confidence,
        ai_feedback: data.feedback
      });
    } catch (err) {
      console.error(err);
      alert('Failed to run AI grading.');
    } finally {
      setIsGrading(false);
    }
  };

  const handleFinalizeGrading = async () => {
    if (!selectedSubmission || finalScore === '') return;
    try {
      await assignmentApi.finalizeGrading(
        selectedSubmission.id,
        Number(finalScore),
        finalFeedback
      );
      alert('Grading finalized successfully!');
      setSelectedSubmission(null);
      // refresh submissions
      if (selectedTask) {
        const data = await assignmentApi.getSubmissions(selectedTask.id);
        setSubmissions(data);
      }
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } catch (err: any) {
      console.error(err);
      alert('Failed to save grading: ' + (err.response?.data?.detail || err.message));
    }
  };

  return (
    <DesktopLayout
      brandTitle="EduAI Instructor"
      brandSubtitle="AI Co-pilot"
      menuItems={instructorMenuItems}
      user={currentUser}
      showFooterLinks={true}
      headerTitle="Assignments & Grading"
      headerAction="New Assignment"
      headerActionIcon="add"
      onHeaderAction={() => setIsNewAssignmentOpen(true)}
    >
      <div className="instructor-grid">
        {/* ── 과제 목록 ── */}
        <div className="col-12">
          <Card title="Active Assignments">
            <table className="data-table" style={{ width: '100%' }}>
              <thead>
                <tr>
                  <th>Assignment Title</th>
                  <th>Deadline</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {tasks.map(t => (
                  <tr key={t.id} style={{ backgroundColor: selectedTask?.id === t.id ? 'var(--color-background)' : 'transparent' }}>
                    <td>{t.title}</td>
                    <td>{t.deadline ? new Date(t.deadline).toLocaleDateString() : 'N/A'}</td>
                    <td>
                      <button className="btn btn-outline btn-sm" onClick={() => handleTaskSelect(t)}>
                        View Submissions
                      </button>
                    </td>
                  </tr>
                ))}
                {tasks.length === 0 && (
                  <tr><td colSpan={3} style={{ textAlign: 'center' }}>No assignments found.</td></tr>
                )}
              </tbody>
            </table>
          </Card>
        </div>

        {/* ── 학생 제출 대기열 (선택된 과제가 있을 때만 표시) ── */}
        {selectedTask && (
          <div className="col-12">
            <Card title={`Submissions for: ${selectedTask.title}`}>
              <table className="data-table" style={{ width: '100%' }}>
                <thead>
                  <tr>
                    <th>Student</th>
                    <th>Submitted At</th>
                    <th>Status</th>
                    <th>Final Score</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {submissions.map(s => (
                    <tr key={s.id}>
                      <td>{s.student_name}</td>
                      <td>{s.submitted_at ? new Date(s.submitted_at).toLocaleString() : 'N/A'}</td>
                      <td>
                        <StatusTag
                          label={s.status}
                          variant={s.status === 'graded' ? 'success' : 'warning'}
                        />
                      </td>
                      <td>{s.final_score !== null ? s.final_score : '-'}</td>
                      <td>
                        <button 
                          className="btn btn-primary btn-sm"
                          onClick={() => handleOpenGrading(s)}
                        >
                          Review & Grade
                        </button>
                      </td>
                    </tr>
                  ))}
                  {submissions.length === 0 && (
                    <tr><td colSpan={5} style={{ textAlign: 'center' }}>No submissions yet.</td></tr>
                  )}
                </tbody>
              </table>
            </Card>
          </div>
        )}
      </div>

      {/* ── New Assignment Modal ── */}
      <Modal
        isOpen={isNewAssignmentOpen}
        onClose={() => setIsNewAssignmentOpen(false)}
        title="Create New Assignment"
        footer={
          <>
            <button className="btn btn-outline" onClick={() => setIsNewAssignmentOpen(false)}>Cancel</button>
            <button className="btn btn-primary" onClick={handleCreateAssignment}>Create Task</button>
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>Title</label>
            <input 
              type="text" 
              className="input" 
              style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid var(--color-border)' }} 
              value={newTitle} onChange={e => setNewTitle(e.target.value)} 
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>Description</label>
            <textarea 
              className="input" 
              style={{ width: '100%', minHeight: '100px', padding: '8px', borderRadius: '4px', border: '1px solid var(--color-border)', resize: 'vertical' }} 
              value={newDescription} onChange={e => setNewDescription(e.target.value)} 
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>Deadline</label>
            <input 
              type="datetime-local" 
              className="input" 
              style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid var(--color-border)' }} 
              value={newDeadline} onChange={e => setNewDeadline(e.target.value)} 
            />
          </div>
        </div>
      </Modal>

      {/* ── Grading Review Modal ── */}
      <Modal
        isOpen={selectedSubmission !== null}
        onClose={() => setSelectedSubmission(null)}
        title={`Review Submission: ${selectedSubmission?.student_name}`}
        footer={
          <>
            <button className="btn btn-outline" onClick={() => handleRunAIGrading()} disabled={isGrading}>
              {isGrading ? 'AI is grading...' : 'Run AI Auto-Grade'}
            </button>
            <button className="btn btn-primary" onClick={handleFinalizeGrading}>
              Approve & Save Grade
            </button>
          </>
        }
      >
        {selectedSubmission && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <div style={{ background: 'var(--color-surface-hover)', padding: '16px', borderRadius: '8px' }}>
              <h4 style={{ margin: '0 0 12px 0' }}>Student's Content</h4>
              {selectedSubmission.content ? (
                <p style={{ margin: '0 0 12px 0', whiteSpace: 'pre-wrap', fontSize: '14px' }}>{selectedSubmission.content}</p>
              ) : (
                <p style={{ margin: '0 0 12px 0', fontSize: '14px', color: 'var(--color-text-secondary)', fontStyle: 'italic' }}>No text content provided.</p>
              )}
              
              {selectedSubmission.file_url && (
                <div style={{ marginTop: '12px', paddingTop: '12px', borderTop: '1px solid var(--color-border)' }}>
                  <h4 style={{ margin: '0 0 8px 0', fontSize: '14px' }}>Attached File</h4>
                  <a 
                    href={`http://localhost:8000${selectedSubmission.file_url}`} 
                    target="_blank" 
                    rel="noreferrer"
                    style={{ color: 'var(--color-primary)', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '14px' }}
                  >
                    <span className="material-icons-outlined" style={{ fontSize: '16px' }}>attach_file</span>
                    {selectedSubmission.file_name || 'Download File'}
                  </a>
                </div>
              )}
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>AI Score Predict</label>
                <div style={{ padding: '8px', background: 'var(--color-background)', borderRadius: '4px' }}>
                  {selectedSubmission.ai_score !== null ? `${selectedSubmission.ai_score} (Confidence: ${selectedSubmission.ai_confidence})` : 'Not run yet'}
                </div>
              </div>
              <div>
                <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>Final Score</label>
                <input 
                  type="number" 
                  min="0" max="100" 
                  style={{ width: '100%', padding: '8px', borderRadius: '4px', border: '1px solid var(--color-border)' }} 
                  value={finalScore} 
                  onChange={e => setFinalScore(e.target.value !== '' ? Number(e.target.value) : '')} 
                />
              </div>
            </div>

            <div>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>AI Feedback</label>
              <div style={{ padding: '8px', background: 'var(--color-background)', borderRadius: '4px', minHeight: '60px' }}>
                {selectedSubmission.ai_feedback || 'No feedback yet'}
              </div>
            </div>

            <div>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>Final Feedback (Manual Edit)</label>
              <textarea 
                style={{ width: '100%', minHeight: '80px', padding: '8px', borderRadius: '4px', border: '1px solid var(--color-border)', resize: 'vertical' }} 
                value={finalFeedback} 
                onChange={e => setFinalFeedback(e.target.value)} 
              />
            </div>
          </div>
        )}
      </Modal>

    </DesktopLayout>
  );
}
