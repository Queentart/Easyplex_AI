import Modal from '../../../components/common/Modal';
import { type AssignmentTask } from '../../../api/assignmentApi';

interface AssignmentReviewModalProps {
  isOpen: boolean;
  onClose: () => void;
  selectedTask: AssignmentTask | null;
}

export default function AssignmentReviewModal({ isOpen, onClose, selectedTask }: AssignmentReviewModalProps) {
  if (!selectedTask) return null;

  return (
    <Modal 
      isOpen={isOpen} 
      onClose={onClose}
      title={`${selectedTask.title} - 리뷰 결과`}
      footer={
        <button className="btn btn-primary" onClick={onClose}>확인</button>
      }
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        {/* 점수 표시 */}
        <div style={{ textAlign: 'center', padding: '24px', background: 'var(--color-bg-secondary)', borderRadius: '12px' }}>
          <h3 style={{ margin: '0 0 8px 0', color: 'var(--color-text-secondary)', fontSize: '1.1rem' }}>최종 점수</h3>
          <div style={{ fontSize: '2.5rem', fontWeight: 'bold', color: 'var(--color-success)' }}>
            {selectedTask.final_score !== null && selectedTask.final_score !== undefined ? `${selectedTask.final_score}점` : '미채점'}
          </div>
        </div>

        {/* 피드백 표시 */}
        <div>
          <h4 style={{ margin: '0 0 12px 0', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>feedback</span>
            강사진 피드백
          </h4>
          <div style={{ 
            padding: '16px', 
            border: '1px solid var(--color-border)', 
            borderRadius: '8px', 
            background: 'var(--color-bg-secondary)',
            minHeight: '100px'
          }}>
            {selectedTask.final_feedback ? (
              <p style={{ margin: 0, lineHeight: '1.6', whiteSpace: 'pre-wrap' }}>
                {selectedTask.final_feedback}
              </p>
            ) : (
              <p style={{ margin: 0, color: 'var(--color-text-tertiary)', fontStyle: 'italic', textAlign: 'center', paddingTop: '20px' }}>
                아직 등록된 피드백이 없습니다.
              </p>
            )}
          </div>
        </div>
      </div>
    </Modal>
  );
}
