import { QRCodeSVG } from 'qrcode.react';
import Modal from './Modal';
import { useAuth } from '../../contexts/AuthContext';

interface AttendanceQRModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function AttendanceQRModal({ isOpen, onClose }: AttendanceQRModalProps) {
  const { user } = useAuth();

  // 매번 모달이 열릴 때마다 토큰(시간 기반 등)을 재생성한다고 가정.
  // 여기서는 임시로 학생의 이메일(식별자)과 현재 날짜를 결합하여 사용.
  let qrValue = '';
  if (isOpen && user) {
    const todayStr = new Date().toISOString().split('T')[0];
    const tokenObj = {
      studentId: user.email.split('@')[0], // e.g. "24-001"
      date: todayStr,
      type: 'attendance_check'
    };
    qrValue = JSON.stringify(tokenObj);
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="출석 체크 QR">
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '24px 0' }}>
        <p style={{ marginBottom: '24px', color: 'var(--color-text-secondary)', fontSize: '0.9rem', textAlign: 'center' }}>
          학원 입구의 QR 스캐너에<br/>아래 화면을 인식시켜주세요.
        </p>
        
        {/* 고해상도 SVG 형식의 QR 코드 렌더링 */}
        <div style={{ background: 'white', padding: '16px', borderRadius: '12px', boxShadow: '0 4px 12px rgba(0,0,0,0.05)' }}>
          <QRCodeSVG 
            value={qrValue || 'loading'} 
            size={200}
            level="H" // High error correction
            includeMargin={true}
          />
        </div>
        
        <p style={{ marginTop: '24px', fontSize: '1.2rem', fontWeight: 'bold', color: 'var(--color-primary)' }}>
          {user?.name || '학생'}
        </p>
        <p style={{ fontSize: '0.9rem', color: 'var(--color-text-tertiary)', marginTop: '4px' }}>
          {user?.email.split('@')[0]}
        </p>
      </div>
    </Modal>
  );
}
