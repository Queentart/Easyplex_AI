/* ==========================================================
 * Assignments 페이지
 * ----------------------------------------------------------
 * (목업 화면 #12) 과제 목록 + 제출 현황
 * ========================================================== */

import { useState, useEffect } from 'react';
import MobileLayout from '../../components/layout/MobileLayout';
import StatusTag from '../../components/common/StatusTag';
import { studentBottomNav } from '../../data/student';
import { assignmentApi, type AssignmentTask } from '../../api/assignmentApi';
import AssignmentSubmissionModal from './components/AssignmentSubmissionModal';
import './Student.css';

export default function Assignments() {
  const [tasks, setTasks] = useState<AssignmentTask[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedTask, setSelectedTask] = useState<AssignmentTask | null>(null);

  useEffect(() => {
    const loadTasks = async () => {
      try {
        const data = await assignmentApi.getTasks();
        setTasks(data);
      } catch (error) {
        console.error('Failed to fetch assignments', error);
      } finally {
        setLoading(false);
      }
    };
    loadTasks();
  }, []);

  const fetchTasks = async () => {
    try {
      setLoading(true);
      const data = await assignmentApi.getTasks();
      setTasks(data);
    } catch (error) {
      console.error('Failed to fetch assignments', error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenModal = (task: AssignmentTask) => {
    setSelectedTask(task);
  };

  return (
    <MobileLayout title="Assignments" bottomNavItems={studentBottomNav}>
      {/* ── 과제 목록 ── */}
      <div className="mobile-card">
        <div className="mobile-card__title">
          <span className="material-icons-outlined" style={{ fontSize: 18, color: 'var(--color-primary)' }}>assignment</span>
          Pending Assignments
        </div>

        {loading ? (
          <p style={{ padding: '20px', textAlign: 'center' }}>Loading assignments...</p>
        ) : tasks.length === 0 ? (
          <p style={{ padding: '20px', textAlign: 'center', color: 'var(--color-text-secondary)' }}>No assignments found.</p>
        ) : (
          tasks.map(a => (
            <div key={a.id} className="assignment-card">
              <div className="assignment-card__header">
                <span className="assignment-card__title">{a.title}</span>
                <StatusTag label={a.status || 'pending'} variant={a.status === 'pending' ? 'warning' : a.status === 'submitted' ? 'info' : 'success'} />
              </div>
              <div className="assignment-card__deadline">
                <span className="material-icons-outlined" style={{ fontSize: 16 }}>schedule</span>
                {a.deadline ? new Date(a.deadline).toLocaleString() : 'No deadline'}
              </div>
              <div className="card__actions" style={{ marginTop: 'var(--space-3)' }}>
                {(() => {
                  const isPastDeadline = a.deadline ? new Date() > new Date(a.deadline) : false;
                  return (
                    <button 
                      className={`btn btn-sm ${isPastDeadline ? 'btn-outline' : 'btn-primary'}`}
                      onClick={() => handleOpenModal(a)}
                      disabled={isPastDeadline}
                      style={isPastDeadline ? { cursor: 'not-allowed', opacity: 0.6 } : {}}
                    >
                      {isPastDeadline ? 'Expired' : (a.status === 'pending' ? 'Start Assignment' : 'Edit Submission')}
                    </button>
                  );
                })()}
              </div>
            </div>
          ))
        )}
      </div>

      {/* ── 과제 상세 및 제출 모달 ── */}
      <AssignmentSubmissionModal
        isOpen={selectedTask !== null}
        onClose={() => setSelectedTask(null)}
        selectedTask={selectedTask}
        onSuccess={fetchTasks}
      />
    </MobileLayout>
  );
}
