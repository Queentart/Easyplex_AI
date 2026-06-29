import { useState, useEffect, useRef, useMemo } from 'react';
import type { UserRole, IntranetMessage } from '../../types';
import { intranetMessageService } from '../../api/intranetMessageService';
import { useAuth } from '../../contexts/AuthContext';

interface IntranetChatDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  userRole: UserRole;
}

const ROLE_LABELS: Record<string, string> = {
  instructor: '주강사',
  tutor: '멘토',
  ops: '운영팀',
  eduops: '운영팀',
  tech: '기술팀',
  techops: '기술팀',
  owner: '오너'
};

export default function IntranetChatDrawer({ isOpen, onClose, userRole }: IntranetChatDrawerProps) {
  const { user } = useAuth();
  const [messages, setMessages] = useState<IntranetMessage[]>([]);
  const [input, setInput] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const allowedRoles = useMemo(() => {
    let roles: UserRole[] = [];
    const r = userRole.toLowerCase();
    if (r === 'instructor') roles = ['tutor', 'ops', 'eduops', 'tech', 'techops', 'owner'] as UserRole[];
    else if (r === 'tutor') roles = ['instructor', 'ops', 'eduops', 'tech', 'techops', 'tutor'] as UserRole[];
    else if (r === 'ops' || r === 'eduops') roles = ['instructor', 'tutor', 'tech', 'techops', 'owner'] as UserRole[];
    else if (r === 'tech' || r === 'techops') roles = ['instructor', 'tutor', 'ops', 'eduops', 'owner'] as UserRole[];
    else if (r === 'owner') roles = ['instructor', 'tutor', 'ops', 'eduops', 'tech', 'techops'] as UserRole[];
    
    return Array.from(new Set(roles.map(role => {
      if (role === 'ops') return 'eduops' as UserRole;
      if (role === 'tech') return 'techops' as UserRole;
      return role;
    })));
  }, [userRole]);

  const [selectedRole, setSelectedRole] = useState<UserRole | ''>(allowedRoles.length > 0 ? allowedRoles[0] : '');

  useEffect(() => {
    if (allowedRoles.length > 0 && !allowedRoles.includes(selectedRole as UserRole)) {
      // eslint-disable-next-line
      setSelectedRole(allowedRoles[0]);
    }
  }, [allowedRoles, selectedRole]);

  const fetchMessages = async () => {
    try {
      const data = await intranetMessageService.getMessages();
      setMessages(data);
    } catch (error) {
      console.error('Failed to fetch intranet messages', error);
    }
  };

  useEffect(() => {
    if (isOpen) {
      // eslint-disable-next-line
      fetchMessages();
      // 폴링 (실시간성 흉내)
      const interval = setInterval(fetchMessages, 5000);
      return () => clearInterval(interval);
    }
  }, [isOpen]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const sendMessage = async () => {
    if (!input.trim() || !selectedRole) return;
    
    try {
      await intranetMessageService.sendMessage(selectedRole, input);
      setInput('');
      fetchMessages();
    } catch (error) {
      console.error('Failed to send message', error);
      alert('메시지 전송에 실패했습니다.');
    }
  };

  // 선택된 탭(role)의 메시지만 필터링
  const filteredMessages = messages.filter(msg => {
    return (
      (msg.sender_id === (user?.id || 0) && msg.receiver_role.toLowerCase() === selectedRole.toLowerCase()) ||
      (msg.receiver_role.toLowerCase() === userRole.toLowerCase())
    );
  });

  return (
    <div 
      className={`fixed z-[60] bottom-[160px] right-6 transition-all duration-300 ease-in-out transform ${
        isOpen ? 'opacity-100 translate-y-0 scale-100' : 'opacity-0 translate-y-10 scale-95 pointer-events-none'
      }`}
      style={{ 
        width: '380px',
        height: '600px',
        maxWidth: 'calc(100vw - 40px)',
        maxHeight: 'calc(100vh - 180px)',
        borderRadius: '24px',
        overflow: 'hidden',
        boxShadow: '0 10px 40px rgba(0,0,0,0.2), 0 4px 12px rgba(0,0,0,0.1)',
        display: 'flex', 
        flexDirection: 'column', 
        backgroundColor: '#fff'
      }}
    >
      {/* 헤더 */}
      <div 
        style={{ background: '#4f46e5', color: 'white', padding: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexShrink: 0 }}
      >
        <h3 style={{ color: 'white', margin: 0, fontSize: '1.1rem', display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 600 }}>
          <span className="material-icons">corporate_fare</span>
          사내 메신저
        </h3>
        <button onClick={onClose} style={{ color: 'white', background: 'none', border: 'none', cursor: 'pointer', padding: 0, display: 'flex' }}>
          <span className="material-icons">close</span>
        </button>
      </div>

      {/* 대상 직군 선택 탭 */}
      <div 
        style={{ display: 'flex', overflowX: 'auto', padding: '12px 16px', gap: '8px', borderBottom: '1px solid #e2e8f0', background: '#f8fafc', flexShrink: 0 }}
        className="hide-scrollbar"
      >
        {allowedRoles.map(role => {
          const isActive = selectedRole === role;
          return (
            <button
              key={role}
              className="whitespace-nowrap"
              style={{
                padding: '6px 14px',
                borderRadius: '20px',
                fontSize: '13px',
                fontWeight: 600,
                border: isActive ? `1px solid #4f46e5` : '1px solid #e2e8f0',
                backgroundColor: isActive ? '#4f46e5' : '#ffffff',
                color: isActive ? '#ffffff' : '#64748b',
                cursor: 'pointer',
                transition: 'all 0.2s'
              }}
              onClick={() => setSelectedRole(role)}
            >
              {ROLE_LABELS[role.toLowerCase()] || role}
            </button>
          )
        })}
      </div>
      
      {/* 메시지 영역 */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px', backgroundColor: '#fcfcfc' }}>
        {filteredMessages.length === 0 ? (
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%', color: '#94a3b8', fontSize: '13px' }}>
            아직 대화 내역이 없습니다.
          </div>
        ) : (
          filteredMessages.map((msg, idx) => {
            const isMe = msg.sender_id === (user?.id || 0);
            return (
              <div key={idx} style={{ marginBottom: '16px', display: 'flex', flexDirection: 'column', alignItems: isMe ? 'flex-end' : 'flex-start' }}>
                {!isMe && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
                    <div style={{ width: '24px', height: '24px', borderRadius: '50%', background: '#e0e7ff', color: '#4f46e5', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px', fontWeight: 'bold' }}>
                      {msg.sender_name.charAt(0)}
                    </div>
                    <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 600 }}>{msg.sender_name}</span>
                  </div>
                )}
                <div 
                  style={{ 
                    background: isMe ? '#4f46e5' : '#ffffff',
                    border: isMe ? '1px solid #4f46e5' : '1px solid #e2e8f0',
                    color: isMe ? '#ffffff' : '#334155',
                    padding: '12px 16px',
                    borderRadius: isMe ? '16px 4px 16px 16px' : '4px 16px 16px 16px',
                    boxShadow: '0 2px 4px rgba(0,0,0,0.02)',
                    maxWidth: '85%',
                    fontSize: '14px',
                    lineHeight: 1.5,
                    whiteSpace: 'pre-wrap',
                    wordBreak: 'break-word'
                  }}
                >
                  {msg.content}
                </div>
              </div>
            );
          })
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* 입력 영역 */}
      <div style={{ padding: '16px', background: 'white', borderTop: '1px solid #e2e8f0' }}>
        <div style={{ display: 'flex', gap: '8px', background: '#f8fafc', padding: '8px 16px', borderRadius: '24px', border: '1px solid #e2e8f0', alignItems: 'center' }}>
          <input
            type="text"
            style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', fontSize: '14px', color: '#334155' }}
            placeholder={`${ROLE_LABELS[selectedRole.toLowerCase()] || ''}에게 메시지 보내기...`}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                sendMessage();
              }
            }}
          />
          <button 
            style={{ background: input.trim() ? '#4f46e5' : '#cbd5e1', color: 'white', border: 'none', borderRadius: '50%', width: '32px', height: '32px', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: input.trim() ? 'pointer' : 'default', transition: 'background 0.2s' }}
            onClick={sendMessage}
          >
            <span className="material-icons" style={{ fontSize: '16px' }}>send</span>
          </button>
        </div>
      </div>
    </div>
  );
}
