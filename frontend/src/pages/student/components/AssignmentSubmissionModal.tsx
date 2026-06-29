import { useState, useEffect } from 'react';
import Modal from '../../../components/common/Modal';
import { assignmentApi, type AssignmentTask } from '../../../api/assignmentApi';

interface AssignmentSubmissionModalProps {
  isOpen: boolean;
  onClose: () => void;
  selectedTask: AssignmentTask | null;
  onSuccess?: () => void;
}

export default function AssignmentSubmissionModal({ isOpen, onClose, selectedTask, onSuccess }: AssignmentSubmissionModalProps) {
  const [submissionContent, setSubmissionContent] = useState('');
  const [submissionFile, setSubmissionFile] = useState<File | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Reset form when modal opens with a new task
  useEffect(() => {
    let isMounted = true;
    if (isOpen && isMounted) {
      setTimeout(() => {
        setSubmissionContent('');
        setSubmissionFile(null);
      }, 0);
    }
    return () => { isMounted = false; };
  }, [isOpen, selectedTask]);

  const handleSubmit = async () => {
    if (!selectedTask) return;
    if (!submissionContent.trim() && !submissionFile) {
      alert('과제 내용이나 첨부 파일을 입력해주세요.');
      return;
    }

    try {
      setIsSubmitting(true);
      await assignmentApi.submitAssignment(selectedTask.id, submissionContent, submissionFile);
      alert('과제가 성공적으로 제출되었습니다!');
      if (onSuccess) onSuccess();
      onClose();
    } catch (error) {
      console.error('Submission failed', error);
      alert('과제 제출에 실패했습니다.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal 
      isOpen={isOpen && selectedTask !== null} 
      onClose={onClose}
      title={selectedTask?.title || '과제 상세 및 제출'}
      footer={
        <>
          <button className="btn btn-outline" onClick={onClose}>취소</button>
          <button className="btn btn-primary" onClick={handleSubmit} disabled={isSubmitting}>
            {isSubmitting ? '제출 중...' : '과제 제출하기'}
          </button>
        </>
      }
    >
      {selectedTask && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div>
            <h4 style={{ margin: '0 0 8px 0', color: 'var(--color-text-secondary)' }}>설명 (Description)</h4>
            <p style={{ margin: 0, fontSize: '14px', lineHeight: '1.6', whiteSpace: 'pre-wrap' }}>{selectedTask.description}</p>
          </div>
          
          <div style={{ borderTop: '1px solid var(--color-border)', paddingTop: '16px' }}>
            <h4 style={{ margin: '0 0 8px 0', color: 'var(--color-text-secondary)' }}>내 제출물 (Your Submission)</h4>
            <textarea
              value={submissionContent}
              onChange={(e) => setSubmissionContent(e.target.value)}
              placeholder="여기에 답변이나 코드를 작성하세요... (파일 첨부 시 선택 사항)"
              style={{
                width: '100%',
                minHeight: '100px',
                padding: '12px',
                borderRadius: '8px',
                border: '1px solid var(--color-border)',
                resize: 'vertical',
                fontFamily: 'inherit',
                fontSize: '14px',
                marginBottom: '12px'
              }}
            />
            <div style={{ marginTop: '8px' }}>
              <label style={{ display: 'block', fontWeight: 'bold', marginBottom: '8px', fontSize: '14px', color: 'var(--color-text-secondary)' }}>
                파일 업로드 (코드, 문서, 이미지, 비디오, 오디오)
              </label>
              <input 
                type="file" 
                onChange={(e) => {
                  if (e.target.files && e.target.files.length > 0) {
                    setSubmissionFile(e.target.files[0]);
                  }
                }} 
                style={{ width: '100%' }}
              />
            </div>
          </div>
        </div>
      )}
    </Modal>
  );
}
