import { useState, useEffect, useRef } from 'react';
import { helpBotMessages } from '../../data/student';
import './Student.css';
import type { ChatMessage } from '../../types';
import { useAuth } from '../../hooks/useAuth';
type SupportMode = 'faq' | 'ops' | 'tech' | 'instructor';

const MODE_CONFIG = {
  faq: { title: 'AI Help Bot', icon: 'smart_toy', color: 'var(--color-primary)', bg: '#f0fdfa' },
  ops: { title: 'Operations Team', icon: 'support_agent', color: '#2563eb', bg: '#eff6ff' },
  tech: { title: 'Tech Support', icon: 'computer', color: '#9333ea', bg: '#faf5ff' },
  instructor: { title: 'Instructor Q&A', icon: 'school', color: '#ea580c', bg: '#fff7ed' }
};

interface AIHelpBotModalProps {
  isOpen: boolean;
  onClose: () => void;
  onUnreadChange?: (total: number) => void;
}

interface FAQ {
  id: number;
  category: string;
  question: string;
  answer: string;
}

export default function AIHelpBot({ isOpen, onClose, onUnreadChange }: AIHelpBotModalProps) {
  const { user } = useAuth();
  const studentName = user?.name || 'Current Student';
  const [inputValue, setInputValue] = useState('');
  const [chatMode, setChatMode] = useState<SupportMode>('faq');
  const [messages, setMessages] = useState<Record<SupportMode, ChatMessage[]>>({
    faq: helpBotMessages,
    ops: [],
    tech: [],
    instructor: []
  });
  const [isMobileView, setIsMobileView] = useState(window.innerWidth < 768);
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [faqs, setFaqs] = useState<FAQ[]>([]);
  const [opsCategory, setOpsCategory] = useState<string | null>(null);
  const [opsTickets, setOpsTickets] = useState<{ id: string | number; message?: string; status?: string; reply?: string; created_at?: string; replied_at?: string; timestamp?: string }[]>([]);
  const [techCategory, setTechCategory] = useState<string | null>(null);
  const [instructorCategory, setInstructorCategory] = useState<string | null>(null);
  const [instructorTickets, setInstructorTickets] = useState<{ id: string | number; message?: string; status?: string; reply?: string; created_at?: string; replied_at?: string; timestamp?: string }[]>([]);
  const [isEquipmentModalOpen, setIsEquipmentModalOpen] = useState(false);
  const [equipmentForm, setEquipmentForm] = useState({ phone: '', address: '' });

  const handleEquipmentSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!equipmentForm.phone || !equipmentForm.address) return;
    
    // Save to localStorage
    const existing = JSON.parse(localStorage.getItem('easyplex_equipment_requests') || '[]');
    const newRequest = {
      id: `EQR-${new Date().getTime()}`,
      student: studentName,
      phone: equipmentForm.phone,
      address: equipmentForm.address,
      status: 'Pending',
      date: new Date().toISOString()
    };
    localStorage.setItem('easyplex_equipment_requests', JSON.stringify([...existing, newRequest]));
    
    setIsEquipmentModalOpen(false);
    
    // Auto reply to tech chat
    setMessages(prev => ({
      ...prev,
      tech: [...prev.tech, {
        id: `msg_${new Date().getTime()}`,
        sender: 'student',
        content: `[장비 신청 완료] 신청서가 성공적으로 접수되었습니다.\n연락처: ${equipmentForm.phone}\n주소: ${equipmentForm.address}`,
        timestamp: new Date().toISOString()
      }]
    }));
    
    setEquipmentForm({ phone: '', address: '' });
    scrollToBottom();
  };
  const initialLoadRef = useRef({ ops: true, tech: true, instructor: true });
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    setTimeout(() => {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, 50);
  };

  const currentMessagesLength = messages[chatMode]?.length || 0;

  useEffect(() => {
    scrollToBottom();
  }, [currentMessagesLength, chatMode, isOpen]);

  const [unreadCounts, setUnreadCounts] = useState<Record<SupportMode, number>>({
    faq: 0, ops: 0, tech: 0, instructor: 0
  });

  const playChatSound = () => {
    try {
      const AudioContextClass = window.AudioContext || (window as typeof window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!AudioContextClass) return;
      const audioCtx = new AudioContextClass();
      
      const playTone = (freq: number, startTime: number, duration: number) => {
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.type = 'triangle';
        osc.frequency.value = freq;
        gain.gain.setValueAtTime(0, startTime);
        gain.gain.linearRampToValueAtTime(0.2, startTime + 0.05);
        gain.gain.exponentialRampToValueAtTime(0.01, startTime + duration);
        osc.start(startTime);
        osc.stop(startTime + duration);
      };
      
      const now = audioCtx.currentTime;
      playTone(523.25, now, 0.1); // C5
      playTone(659.25, now + 0.1, 0.15); // E5
    } catch (e) {
      console.error('Audio play failed', e);
    }
  };

  useEffect(() => {
    if (onUnreadChange) {
      const total = Object.values(unreadCounts).reduce((a, b) => a + b, 0);
      onUnreadChange(total);
    }
  }, [unreadCounts, onUnreadChange]);

  useEffect(() => {
    if (isOpen) {
      setTimeout(() => {
        setUnreadCounts(prev => ({ ...prev, [chatMode]: 0 }));
        setMessages(prev => ({ ...prev, faq: helpBotMessages }));
      }, 0);
    }
  }, [isOpen, chatMode]);

  useEffect(() => {
    const handleResize = () => setIsMobileView(window.innerWidth < 768);
    window.addEventListener('resize', handleResize);
    
    // Fetch FAQs
    fetch('http://localhost:8000/api/v1/student/support/faqs')
      .then(res => res.json())
      .then(data => {
        if (data.status === 'success' && data.data) {
          setFaqs(data.data);
        }
      })
      .catch(err => console.error("FAQ fetch error:", err));

    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // Poll for Ops Tickets
  useEffect(() => {
    const fetchTickets = () => {
      fetch(`http://localhost:8000/api/v1/student/support/tickets?student_name=${encodeURIComponent(studentName)}`)
        .then(res => res.json())
        .then(data => {
          if (data.status === 'success' && data.data) {
            setOpsTickets(data.data);
          }
        })
        .catch(err => console.error("Tickets fetch error:", err));
    };
    
    fetchTickets();
    const interval = setInterval(fetchTickets, 5000); // 5초마다 폴링
    return () => clearInterval(interval);
  }, [studentName]);

  // Sync Ops messages from tickets
  useEffect(() => {
    const newOpsMessages: ChatMessage[] = [];
    const sortedTickets = [...opsTickets].sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
    
    sortedTickets.forEach(ticket => {
      newOpsMessages.push({
        id: `ops_msg_${ticket.id}`,
        sender: 'student',
        content: ticket.message,
        timestamp: ticket.created_at
      });
      if (ticket.reply) {
        newOpsMessages.push({
          id: `ops_reply_${ticket.id}`,
          sender: 'ops',
          content: ticket.reply,
          timestamp: ticket.replied_at || ticket.created_at
        });
      }
    });
    
    setMessages(prev => {
      const prevDbMessagesLength = prev.ops.filter(m => m.sender !== 'system').length;
      if (prevDbMessagesLength !== newOpsMessages.length) {
        const newCount = newOpsMessages.length - prevDbMessagesLength;
        if (!initialLoadRef.current.ops && newCount > 0 && (!isOpen || chatMode !== 'ops')) {
          setUnreadCounts(u => ({ ...u, ops: u.ops + newCount }));
          playChatSound();
        }
        initialLoadRef.current.ops = false;
        const systemMessages = prev.ops.filter(m => m.sender === 'system');
        const merged = [...newOpsMessages, ...systemMessages].sort((a,b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());
        return { ...prev, ops: merged };
      }
      initialLoadRef.current.ops = false;
      return prev;
    });
  }, [opsTickets, isOpen, chatMode]);

  // Poll for Instructor Tickets
  useEffect(() => {
    const fetchTickets = () => {
      fetch(`http://localhost:8000/api/v1/student/support/instructor-tickets?student_name=${encodeURIComponent(studentName)}`)
        .then(res => res.json())
        .then(data => {
          if (data.status === 'success' && data.data) {
            setInstructorTickets(data.data);
          }
        })
        .catch(err => console.error("Instructor tickets fetch error:", err));
    };
    
    fetchTickets();
    const interval = setInterval(fetchTickets, 5000);
    return () => clearInterval(interval);
  }, [studentName]);

  // Sync Instructor messages from tickets
  useEffect(() => {
    const newInstructorMessages: ChatMessage[] = [];
    const sortedTickets = [...instructorTickets].sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
    
    sortedTickets.forEach(ticket => {
      newInstructorMessages.push({
        id: `inst_msg_${ticket.id}`,
        sender: 'student',
        content: ticket.message,
        timestamp: ticket.created_at
      });
      if (ticket.reply) {
        newInstructorMessages.push({
          id: `inst_reply_${ticket.id}`,
          sender: 'instructor',
          content: ticket.reply,
          timestamp: ticket.replied_at || ticket.created_at
        });
      }
    });
    
    setMessages(prev => {
      const prevDbMessagesLength = prev.instructor.filter(m => m.sender !== 'system').length;
      if (prevDbMessagesLength !== newInstructorMessages.length) {
        const newCount = newInstructorMessages.length - prevDbMessagesLength;
        if (!initialLoadRef.current.instructor && newCount > 0 && (!isOpen || chatMode !== 'instructor')) {
          setUnreadCounts(u => ({ ...u, instructor: u.instructor + newCount }));
          playChatSound();
        }
        initialLoadRef.current.instructor = false;
        const systemMessages = prev.instructor.filter(m => m.sender === 'system');
        const merged = [...newInstructorMessages, ...systemMessages].sort((a,b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());
        return { ...prev, instructor: merged };
      }
      initialLoadRef.current.instructor = false;
      return prev;
    });
  }, [instructorTickets, isOpen, chatMode]);

  // Poll for Tech Messages
  useEffect(() => {
    const fetchTechMessages = () => {
      fetch(`http://localhost:8000/api/v1/student/support/tech-messages?student_name=${encodeURIComponent(studentName)}`)
        .then(res => res.json())
        .then(data => {
          if (data.status === 'success' && data.data) {
            setMessages(prev => {
              const newTechMessages = data.data.map((m: { id: string; sender: string; content: string; timestamp: string }) => ({
                id: `tech_${m.id}`,
                sender: m.sender,
                content: m.content,
                timestamp: m.timestamp
              }));
              const prevDbMessagesLength = prev.tech.filter(m => m.sender !== 'system').length;
              if (prevDbMessagesLength !== newTechMessages.length) {
                const newCount = newTechMessages.length - prevDbMessagesLength;
                if (!initialLoadRef.current.tech && newCount > 0 && (!isOpen || chatMode !== 'tech')) {
                  setUnreadCounts(u => ({ ...u, tech: u.tech + newCount }));
                  playChatSound();
                }
                initialLoadRef.current.tech = false;
                const systemMessages = prev.tech.filter(m => m.sender === 'system');
                const merged = [...newTechMessages, ...systemMessages].sort((a,b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());
                return { ...prev, tech: merged };
              }
              initialLoadRef.current.tech = false;
              return prev;
            });
          }
        })
        .catch(console.error);
    };
    
    fetchTechMessages();
    const interval = setInterval(fetchTechMessages, 3000);
    return () => clearInterval(interval);
  }, [studentName, isOpen, chatMode]);

  const handleSend = async (overrideMessage?: string) => {
    let finalMessage = inputValue;
    if (!overrideMessage && chatMode === 'tech' && techCategory) {
      finalMessage = `[${techCategory}] ${inputValue}`;
    } else if (!overrideMessage && chatMode === 'ops' && opsCategory) {
      finalMessage = `[${opsCategory}] ${inputValue}`;
    } else if (!overrideMessage && chatMode === 'instructor' && instructorCategory) {
      finalMessage = `[${instructorCategory}] ${inputValue}`;
    }
    const userMessage = overrideMessage || finalMessage;
    if (!userMessage.trim()) return;
    
    // Add user message to UI immediately
    const newMsg: ChatMessage = {
      id: `msg_${new Date().getTime()}`,
      sender: 'student',
      content: userMessage,
      timestamp: new Date().toISOString()
    };
    setMessages(prev => ({
      ...prev,
      [chatMode]: [...prev[chatMode], newMsg]
    }));
    if (!overrideMessage) {
      setInputValue('');
      setTechCategory(null);
      setOpsCategory(null);
      setInstructorCategory(null);
    }

    try {
      const response = await fetch('http://localhost:8000/api/v1/student/support/message', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mode: chatMode, message: userMessage, student_name: studentName })
      });
      
      const data = await response.json();
      
      if (data.status === 'success') {
        const replyMsg: ChatMessage = {
          id: `msg_resp_${new Date().getTime()}`,
          sender: data.sender || 'system',
          content: data.reply,
          timestamp: new Date().toISOString()
        };
        setMessages(prev => ({
          ...prev,
          [chatMode]: [...prev[chatMode], replyMsg]
        }));
      }
    } catch (error) {
      console.error("Support message error:", error);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleFaqClick = (question: string) => {
    // 카카오톡처럼 클릭 시 바로 전송
    handleSend(question);
  };

  const currentConfig = MODE_CONFIG[chatMode];

  return (
    <div 
      className="mobile-chat-modal-wrapper"
      style={{
        position: 'fixed', 
        bottom: 'calc(var(--bottom-nav-height, 60px) + 80px)', // Above FAB
        right: '20px',
        zIndex: 9999,
        display: isOpen ? 'flex' : 'none',
        alignItems: 'flex-end',
        gap: '16px',
        pointerEvents: isOpen ? 'none' : 'none', // wrapper is none, children auto
      }}
    >
      {/* ── 데스크톱 뷰: 왼쪽 세로 플로팅 메뉴 ── */}
      {!isMobileView && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', paddingBottom: '16px', pointerEvents: 'auto' }}>
          {(Object.keys(MODE_CONFIG) as SupportMode[]).map(mode => {
            const isActive = chatMode === mode;
            return (
              <button
                key={mode}
                onClick={() => setChatMode(mode)}
                title={MODE_CONFIG[mode].title}
                style={{
                  width: '48px',
                  height: '48px',
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  border: isActive ? 'none' : '1px solid #e2e8f0',
                  backgroundColor: isActive ? MODE_CONFIG[mode].color : '#ffffff',
                  color: isActive ? '#ffffff' : '#64748b',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                  cursor: 'pointer',
                  transition: 'all 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275)',
                  transform: isActive ? 'scale(1.1)' : 'scale(1)',
                  padding: 0,
                  position: 'relative'
                }}
              >
                <span className="material-icons-outlined" style={{ fontSize: 24 }}>{MODE_CONFIG[mode].icon}</span>
                {unreadCounts[mode] > 0 && (
                  <span style={{
                    position: 'absolute', top: -4, right: -4, background: 'var(--color-danger)', color: 'white',
                    fontSize: '10px', fontWeight: 'bold', width: '18px', height: '18px', borderRadius: '50%',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px solid white'
                  }}>
                    {unreadCounts[mode] > 99 ? '99+' : unreadCounts[mode]}
                  </span>
                )}
              </button>
            )
          })}
        </div>
      )}

      {/* ── 메인 챗봇 모달 본체 ── */}
      <div 
        className="mobile-chat-modal" 
        style={{ 
          width: '380px',
          height: '600px',
          maxWidth: 'calc(100vw - 40px)',
          maxHeight: 'calc(100vh - var(--bottom-nav-height, 60px) - 100px)',
          borderRadius: '24px',
          overflow: 'hidden',
          boxShadow: '0 10px 40px rgba(0,0,0,0.2), 0 4px 12px rgba(0,0,0,0.1)',
          display: 'flex', 
          flexDirection: 'column', 
          backgroundColor: currentConfig.bg, 
          transition: 'background-color 0.3s',
          pointerEvents: 'auto'
        }}
      >
        {/* ── 헤더 ── */}
        <header className="header" style={{ background: currentConfig.color, color: 'white', transition: 'background 0.3s', padding: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexShrink: 0 }}>
          <div className="header__left" style={{ display: 'flex', alignItems: 'center' }}>
            <h1 className="header__title" style={{ color: 'white', margin: 0, fontSize: '1.1rem', display: 'flex', alignItems: 'center' }}>
              <span className="material-icons" style={{ fontSize: 20, marginRight: 8 }}>{currentConfig.icon}</span>
              {currentConfig.title}
            </h1>
          </div>
          <div className="header__right">
            <button className="header__icon-btn" style={{ color: 'white', background: 'none', border: 'none', cursor: 'pointer', padding: 0, display: 'flex' }} onClick={onClose}>
              <span className="material-icons">close</span>
            </button>
          </div>
        </header>

        {/* ── 모바일 뷰: 상단 가로 스크롤 메뉴 ── */}
        {isMobileView && (
          <div style={{ position: 'relative', background: '#ffffff', borderBottom: '1px solid #e2e8f0', flexShrink: 0 }}>
            <div 
              style={{ 
                display: 'flex', 
                overflowX: 'auto', 
                padding: '12px 48px 12px 16px', // 48px right padding for the more button
                gap: '8px', 
                scrollSnapType: 'x mandatory',
                scrollBehavior: 'smooth',
                WebkitOverflowScrolling: 'touch'
              }}
              className="hide-scrollbar" // assuming hide-scrollbar hides scrollbar in Student.css
            >
              {(Object.keys(MODE_CONFIG) as SupportMode[]).map(mode => {
                const isActive = chatMode === mode;
                return (
                  <button
                    key={mode}
                    onClick={(e) => {
                      setChatMode(mode);
                      e.currentTarget.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
                    }}
                    style={{
                      scrollSnapAlign: 'center',
                      flexShrink: 0,
                      padding: '8px 14px',
                      borderRadius: '20px',
                      fontSize: '13px',
                      fontWeight: 600,
                      whiteSpace: 'nowrap',
                      border: isActive ? `1px solid ${MODE_CONFIG[mode].color}` : '1px solid #e2e8f0',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      backgroundColor: isActive ? MODE_CONFIG[mode].color : '#f8fafc',
                      color: isActive ? '#ffffff' : '#64748b',
                      transition: 'all 0.2s ease-in-out'
                    }}
                  >
                    <span className="material-icons-outlined" style={{ fontSize: 16 }}>{MODE_CONFIG[mode].icon}</span>
                    {MODE_CONFIG[mode].title}
                    {unreadCounts[mode] > 0 && (
                      <span style={{
                        background: 'var(--color-danger)', color: 'white',
                        fontSize: '10px', fontWeight: 'bold', width: '16px', height: '16px', borderRadius: '50%',
                        display: 'flex', alignItems: 'center', justifyContent: 'center', marginLeft: '4px'
                      }}>
                        {unreadCounts[mode] > 99 ? '99+' : unreadCounts[mode]}
                      </span>
                    )}
                  </button>
                )
              })}
            </div>
            {/* Visual Hint / Dropdown button ('더보기') */}
            <div style={{ 
              position: 'absolute', 
              right: 0, top: 0, bottom: 0, 
              width: '48px', 
              background: 'linear-gradient(to right, rgba(255,255,255,0) 0%, rgba(255,255,255,1) 40%)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              pointerEvents: 'none',
              zIndex: 10
            }}>
              <button 
                style={{ pointerEvents: 'auto', background: 'white', border: '1px solid #e2e8f0', borderRadius: '50%', width: 28, height: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', boxShadow: '0 2px 4px rgba(0,0,0,0.05)' }}
                title="더보기"
                onClick={() => setIsDropdownOpen(!isDropdownOpen)}
              >
                <span className="material-icons" style={{ fontSize: 16, color: '#64748b' }}>more_vert</span>
              </button>
              
              {/* 드롭다운 메뉴 */}
              {isDropdownOpen && (
                <div 
                  style={{
                    position: 'absolute',
                    top: '100%',
                    right: '8px',
                    marginTop: '4px',
                    backgroundColor: 'white',
                    borderRadius: '12px',
                    boxShadow: '0 10px 25px rgba(0,0,0,0.1)',
                    border: '1px solid #e2e8f0',
                    padding: '8px 0',
                    minWidth: '160px',
                    pointerEvents: 'auto',
                    zIndex: 20
                  }}
                >
                  <div style={{ padding: '4px 16px', fontSize: '11px', color: '#94a3b8', fontWeight: 600, letterSpacing: '0.5px' }}>
                    전체 채널
                  </div>
                  {(Object.keys(MODE_CONFIG) as SupportMode[]).map(mode => (
                    <button
                      key={mode}
                      onClick={() => {
                        setChatMode(mode);
                        setIsDropdownOpen(false);
                      }}
                      style={{
                        width: '100%',
                        textAlign: 'left',
                        padding: '10px 16px',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        background: 'none',
                        border: 'none',
                        cursor: 'pointer',
                        fontSize: '13px',
                        fontWeight: 500,
                        color: chatMode === mode ? MODE_CONFIG[mode].color : '#475569',
                        backgroundColor: chatMode === mode ? `${MODE_CONFIG[mode].color}10` : 'transparent',
                        transition: 'background-color 0.2s'
                      }}
                    >
                      <span className="material-icons-outlined" style={{ fontSize: 16, color: chatMode === mode ? MODE_CONFIG[mode].color : '#94a3b8' }}>
                        {MODE_CONFIG[mode].icon}
                      </span>
                      {MODE_CONFIG[mode].title}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {/* ── 메시지 목록 ── */}
        <div className="mobile-chat__messages" style={{ flex: 1, overflowY: 'auto', padding: '20px' }}>
          {messages[chatMode].map(msg => {
            const isMe = msg.sender === 'student';
            const isSystem = msg.sender === 'system';
            
            if (isSystem) {
              return (
                <div key={msg.id} style={{ display: 'flex', justifyContent: 'center', margin: '16px 0' }}>
                  <div style={{ background: 'rgba(0,0,0,0.05)', color: '#64748b', fontSize: '12px', padding: '6px 12px', borderRadius: '12px', textAlign: 'center', maxWidth: '80%' }}>
                    {msg.content}
                  </div>
                </div>
              );
            }

            return (
              <div key={msg.id} className={`chat-bubble chat-bubble--${isMe ? 'user' : msg.sender}`} style={{ marginBottom: '16px' }}>
                <div className="chat-bubble__sender" style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px', justifyContent: isMe ? 'flex-end' : 'flex-start' }}>
                  {!isMe && (
                    <div 
                      className={`chat-bubble__avatar chat-bubble__avatar--${msg.sender}`}
                      style={{ width: '28px', height: '28px', borderRadius: '50%', background: currentConfig.color, color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
                    >
                      <span className="material-icons" style={{ fontSize: 14 }}>{currentConfig.icon}</span>
                    </div>
                  )}
                  <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 600 }}>
                    {isMe ? 'You' : currentConfig.title}
                  </span>
                </div>
                <div 
                  className="chat-bubble__content"
                  style={{ 
                    background: isMe ? 'white' : '#f8fafc',
                    border: isMe ? `1px solid ${currentConfig.color}` : '1px solid #e2e8f0',
                    color: isMe ? currentConfig.color : '#334155',
                    padding: '12px 16px',
                    borderRadius: isMe ? '16px 4px 16px 16px' : '4px 16px 16px 16px',
                    boxShadow: '0 2px 4px rgba(0,0,0,0.02)',
                    maxWidth: '85%',
                    marginLeft: isMe ? 'auto' : '0'
                  }}
                >
                  {msg.content?.includes('[ACTION:EQUIPMENT_FORM]') ? (
                    <div>
                      <p style={{ margin: 0, lineHeight: 1.5, wordBreak: 'break-word', whiteSpace: 'pre-wrap', marginBottom: '8px' }}>
                        {msg.content.replace('[ACTION:EQUIPMENT_FORM]', '')}
                      </p>
                      <button 
                        onClick={() => setIsEquipmentModalOpen(true)}
                        style={{ background: currentConfig.color, color: 'white', border: 'none', padding: '8px 16px', borderRadius: '8px', fontSize: '0.85rem', fontWeight: 600, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', width: '100%', justifyContent: 'center' }}
                      >
                        <span className="material-icons" style={{ fontSize: '16px' }}>feed</span>
                        장비 신청 하기
                      </button>
                    </div>
                  ) : (
                    <p style={{ margin: 0, lineHeight: 1.5, wordBreak: 'break-word', whiteSpace: 'pre-wrap' }}>{msg.content}</p>
                  )}
                </div>
              </div>
            );
          })}
          <div ref={messagesEndRef} />
        </div>

        {/* ── 자주 묻는 질문(FAQ) 퀵 배너 (AI 채널 전용) ── */}
        {chatMode === 'faq' && faqs.length > 0 && (
          <div style={{ background: '#f8fafc', padding: '8px 16px', borderTop: '1px solid #e2e8f0', flexShrink: 0, overflowX: 'auto', whiteSpace: 'nowrap' }} className="hide-scrollbar">
            <div style={{ display: 'flex', gap: '8px' }}>
              {faqs.map(faq => (
                <button
                  key={faq.id}
                  onClick={() => handleFaqClick(faq.question)}
                  style={{
                    background: 'white',
                    border: `1px solid ${MODE_CONFIG['faq'].color}`,
                    color: MODE_CONFIG['faq'].color,
                    padding: '6px 12px',
                    borderRadius: '16px',
                    fontSize: '12px',
                    fontWeight: 500,
                    cursor: 'pointer',
                    boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
                    transition: 'all 0.2s',
                    flexShrink: 0
                  }}
                  onMouseOver={(e) => {
                    e.currentTarget.style.background = MODE_CONFIG['faq'].color;
                    e.currentTarget.style.color = 'white';
                  }}
                  onMouseOut={(e) => {
                    e.currentTarget.style.background = 'white';
                    e.currentTarget.style.color = MODE_CONFIG['faq'].color;
                  }}
                >
                  {faq.question}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* ── 기술지원 카테고리 퀵 배너 (Tech 채널 전용) ── */}
        {chatMode === 'tech' && (
          <div style={{ background: '#f8fafc', padding: '8px 16px', borderTop: '1px solid #e2e8f0', flexShrink: 0, overflowX: 'auto', whiteSpace: 'nowrap' }} className="hide-scrollbar">
            <div style={{ display: 'flex', gap: '8px' }}>
              {['하드웨어 이슈', '라이센스 이슈', 'API 이슈', '장비 신청'].map(cat => (
                <button
                  key={cat}
                  onClick={() => setTechCategory(cat === techCategory ? null : cat)}
                  style={{
                    background: techCategory === cat ? MODE_CONFIG['tech'].color : 'white',
                    border: `1px solid ${MODE_CONFIG['tech'].color}`,
                    color: techCategory === cat ? 'white' : MODE_CONFIG['tech'].color,
                    padding: '6px 12px',
                    borderRadius: '16px',
                    fontSize: '12px',
                    fontWeight: 500,
                    cursor: 'pointer',
                    boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
                    transition: 'all 0.2s',
                    flexShrink: 0
                  }}
                >
                  {cat}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* ── 운영지원 카테고리 퀵 배너 (Ops 채널 전용) ── */}
        {chatMode === 'ops' && (
          <div style={{ background: '#f8fafc', padding: '8px 16px', borderTop: '1px solid #e2e8f0', flexShrink: 0, overflowX: 'auto', whiteSpace: 'nowrap' }} className="hide-scrollbar">
            <div style={{ display: 'flex', gap: '8px' }}>
              {['결석/외출/조퇴', '기타 문의'].map(cat => (
                <button
                  key={cat}
                  onClick={() => setOpsCategory(cat === opsCategory ? null : cat)}
                  style={{
                    background: opsCategory === cat ? MODE_CONFIG['ops'].color : 'white',
                    border: `1px solid ${MODE_CONFIG['ops'].color}`,
                    color: opsCategory === cat ? 'white' : MODE_CONFIG['ops'].color,
                    padding: '6px 12px',
                    borderRadius: '16px',
                    fontSize: '12px',
                    fontWeight: 500,
                    cursor: 'pointer',
                    boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
                    transition: 'all 0.2s',
                    flexShrink: 0
                  }}
                >
                  {cat}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* ── 강사진 질문 카테고리 퀵 배너 (Instructor 채널 전용) ── */}
        {chatMode === 'instructor' && (
          <div style={{ background: '#f8fafc', padding: '8px 16px', borderTop: '1px solid #e2e8f0', flexShrink: 0, overflowX: 'auto', whiteSpace: 'nowrap' }} className="hide-scrollbar">
            <div style={{ display: 'flex', gap: '8px' }}>
              {['학습 관련 질문', '기타 질의 사항'].map(cat => (
                <button
                  key={cat}
                  onClick={() => setInstructorCategory(cat === instructorCategory ? null : cat)}
                  style={{
                    background: instructorCategory === cat ? MODE_CONFIG['instructor'].color : 'white',
                    border: `1px solid ${MODE_CONFIG['instructor'].color}`,
                    color: instructorCategory === cat ? 'white' : MODE_CONFIG['instructor'].color,
                    padding: '6px 12px',
                    borderRadius: '16px',
                    fontSize: '12px',
                    fontWeight: 500,
                    cursor: 'pointer',
                    boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
                    transition: 'all 0.2s',
                    flexShrink: 0
                  }}
                >
                  {cat}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* ── 입력 영역 ── */}
        <div className="mobile-chat__input" style={{ background: 'white', padding: '12px 16px', borderTop: chatMode !== 'faq' || faqs.length === 0 ? '1px solid #e2e8f0' : 'none', flexShrink: 0 }}>
          <div className="chat-input-wrapper" style={{ display: 'flex', alignItems: 'flex-end', background: '#f8fafc', borderRadius: '24px', padding: '8px 16px', border: '1px solid #e2e8f0' }}>
            <textarea
              placeholder={`${currentConfig.title}에게 메시지 보내기...`}
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              onKeyDown={handleKeyDown}
              rows={1}
              style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', resize: 'none', padding: '8px 0', fontSize: '15px', color: '#334155', maxHeight: '100px' }}
            />
            <button 
              onClick={() => handleSend()}
              style={{ 
                background: inputValue.trim() ? currentConfig.color : '#cbd5e1', 
                color: 'white', 
                border: 'none', 
                borderRadius: '50%', 
                width: '40px', 
                height: '40px', 
                display: 'flex', 
                alignItems: 'center', 
                justifyContent: 'center', 
                cursor: inputValue.trim() ? 'pointer' : 'default',
                transition: 'background 0.2s',
                marginLeft: '12px',
                flexShrink: 0
              }}
            >
              <span className="material-icons" style={{ fontSize: 20 }}>send</span>
            </button>
          </div>
        </div>
      </div>
      {/* ── 장비 신청 폼 모달 ── */}
      {isEquipmentModalOpen && (
        <div style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 10000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px', pointerEvents: 'auto' }}>
          <div style={{ background: 'white', borderRadius: '16px', padding: '24px', width: '100%', maxWidth: '400px', pointerEvents: 'auto' }}>
            <h3 style={{ margin: '0 0 16px 0', fontSize: '1.2rem', color: '#1e293b' }}>장비 신청서 작성</h3>
            <form onSubmit={handleEquipmentSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: '#475569', marginBottom: '4px' }}>이름</label>
                <input type="text" value={studentName} disabled style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #e2e8f0', background: '#f8fafc', color: '#94a3b8' }} />
              </div>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: '#475569', marginBottom: '4px' }}>연락처</label>
                <input type="text" value={equipmentForm.phone} onChange={e => setEquipmentForm({...equipmentForm, phone: e.target.value})} placeholder="010-0000-0000" required style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #cbd5e1' }} />
              </div>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: '#475569', marginBottom: '4px' }}>배송 받을 주소</label>
                <input type="text" value={equipmentForm.address} onChange={e => setEquipmentForm({...equipmentForm, address: e.target.value})} placeholder="서울특별시 강남구..." required style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #cbd5e1' }} />
              </div>
              <div style={{ display: 'flex', gap: '8px', marginTop: '8px' }}>
                <button type="button" onClick={() => setIsEquipmentModalOpen(false)} style={{ flex: 1, padding: '12px', background: '#f1f5f9', color: '#64748b', border: 'none', borderRadius: '8px', fontWeight: 600, cursor: 'pointer' }}>취소</button>
                <button type="submit" style={{ flex: 1, padding: '12px', background: currentConfig.color, color: 'white', border: 'none', borderRadius: '8px', fontWeight: 600, cursor: 'pointer' }}>신청 완료</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
