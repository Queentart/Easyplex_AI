import { useState, useEffect } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import { mockTechUser, techMenu } from '../../data/techops';
import { useAuth } from '../../hooks/useAuth';

interface Ticket {
  id: string | number;
  student: string;
  issue: string;
  priority: string;
  status: string;
  date: string;
}

interface Message {
  id: string | number;
  message: string;
  sender_type: string;
  sender_name: string;
}

export default function StudentsMgmt() {
  const { user } = useAuth();
  const adminName = user?.name || 'Tech Admin';
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [selectedTicket, setSelectedTicket] = useState<Ticket | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputValue, setInputValue] = useState('');

  // Fetch Tickets
  const fetchTickets = () => {
    fetch('http://localhost:8000/api/v1/tech/student-mgmt/tickets')
      .then(res => res.json())
      .then(data => {
        if (data.status === 'success' && data.data) {
          setTickets(data.data);
        }
      })
      .catch(console.error);
  };

  useEffect(() => {
    fetchTickets();
    const interval = setInterval(fetchTickets, 5000);
    return () => clearInterval(interval);
  }, []);

  // Fetch Messages for selected ticket
  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;
    if (selectedTicket) {
      const fetchMessages = () => {
        fetch(`http://localhost:8000/api/v1/tech/student-mgmt/tickets/${selectedTicket.id}/messages`)
          .then(res => res.json())
          .then(data => {
            if (data.status === 'success' && data.data) {
              setMessages(data.data);
            }
          })
          .catch(console.error);
      };
      fetchMessages();
      interval = setInterval(fetchMessages, 3000);
    }
    return () => clearInterval(interval);
  }, [selectedTicket]);

  const handleSendReply = () => {
    if (!inputValue.trim() || !selectedTicket) return;
    
    fetch(`http://localhost:8000/api/v1/tech/student-mgmt/tickets/${selectedTicket.id}/messages`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: inputValue, admin_name: adminName })
    })
      .then(() => {
        setInputValue('');
        // Trigger immediate fetch
        fetch(`http://localhost:8000/api/v1/tech/student-mgmt/tickets/${selectedTicket.id}/messages`)
          .then(res => res.json())
          .then(data => {
            if (data.status === 'success' && data.data) {
              setMessages(data.data);
            }
          });
      })
      .catch(console.error);
  };

  return (
    <DesktopLayout
      brandTitle="TechOps Center"
      brandSubtitle="Systems & Infrastructure"
      menuItems={techMenu}
      user={mockTechUser}
      sidebarAction="Export Logs"
      sidebarActionIcon="download"
    >
      <div className="flex flex-col gap-6">
        <header>
          <h1 className="text-2xl font-bold text-gray-800">Students Tech Management</h1>
          <p className="text-gray-500">Manage student technical issues, accounts, and access controls.</p>
        </header>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card title="Active Users" titleIcon="groups" value="3,492" />
          <Card title="Auth Errors" titleIcon="gpp_bad" value="24" trend="down" trendValue="5" />
          <Card title="Password Resets" titleIcon="password" value="15" />
          <Card title="Sync Failures" titleIcon="sync_problem" value="0" />
        </div>

        <Card title="Recent Technical Support Tickets" titleIcon="support_agent">
          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left">
              <thead className="bg-gray-50 text-gray-600">
                <tr>
                  <th className="px-4 py-3">Ticket ID</th>
                  <th className="px-4 py-3">Student Name</th>
                  <th className="px-4 py-3">Issue</th>
                  <th className="px-4 py-3">Priority</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Time</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {tickets.map((tkt) => (
                  <tr key={tkt.id} className="hover:bg-gray-50/50 cursor-pointer" onClick={() => setSelectedTicket(tkt)}>
                    <td className="px-4 py-3 font-medium text-blue-600">TKT-{tkt.id}</td>
                    <td className="px-4 py-3 font-medium">{tkt.student}</td>
                    <td className="px-4 py-3 truncate max-w-[200px]">{tkt.issue}</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-1 rounded text-xs font-bold ${
                        tkt.priority === 'High' ? 'text-red-600 bg-red-50' :
                        tkt.priority === 'Medium' ? 'text-yellow-600 bg-yellow-50' : 'text-gray-600 bg-gray-50'
                      }`}>
                        {tkt.priority}
                      </span>
                    </td>
                    <td className="px-4 py-3">{tkt.status}</td>
                    <td className="px-4 py-3 text-gray-500">{new Date(tkt.date).toLocaleString()}</td>
                  </tr>
                ))}
                {tickets.length === 0 && (
                  <tr>
                    <td colSpan={6} className="px-4 py-8 text-center text-gray-500">
                      No recent technical support tickets found.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </Card>
      </div>

      {/* Chat Modal */}
      {selectedTicket && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-[9999] p-4">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-lg overflow-hidden flex flex-col h-[600px]">
            <header style={{ background: '#9333ea', padding: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexShrink: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span className="material-icons" style={{ color: 'white', fontSize: 20 }}>computer</span>
                <div>
                  <h2 style={{ color: 'white', margin: 0, fontSize: '1.1rem', fontWeight: 600, lineHeight: 1.2 }}>Chat with {selectedTicket.student}</h2>
                  <p style={{ color: 'rgba(255,255,255,0.8)', margin: 0, fontSize: '0.75rem', maxWidth: '250px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>TKT-{selectedTicket.id}: {selectedTicket.issue}</p>
                </div>
              </div>
              <button 
                onClick={() => setSelectedTicket(null)} 
                style={{ background: 'none', border: 'none', cursor: 'pointer', display: 'flex', padding: 0 }}
              >
                <span className="material-icons" style={{ color: 'white' }}>close</span>
              </button>
            </header>
            
            <div style={{ flex: 1, overflowY: 'auto', padding: '20px', background: 'white' }}>
              {messages.map(msg => {
                const isAdmin = msg.sender_type === 'admin';
                return (
                  <div key={msg.id} style={{ marginBottom: '16px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px', justifyContent: isAdmin ? 'flex-end' : 'flex-start' }}>
                      {!isAdmin && (
                        <div style={{ width: '28px', height: '28px', borderRadius: '50%', background: '#9333ea', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                          <span className="material-icons" style={{ fontSize: 14 }}>face</span>
                        </div>
                      )}
                      <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 600 }}>
                        {isAdmin ? 'You' : msg.sender_name}
                      </span>
                    </div>
                    <div 
                      style={{ 
                        background: isAdmin ? 'white' : '#f8fafc',
                        border: isAdmin ? `1px solid #9333ea` : '1px solid #e2e8f0',
                        padding: '12px 16px',
                        borderRadius: isAdmin ? '16px 4px 16px 16px' : '4px 16px 16px 16px',
                        boxShadow: '0 2px 4px rgba(0,0,0,0.02)',
                        maxWidth: '85%',
                        marginLeft: isAdmin ? 'auto' : '0'
                      }}
                    >
                      <p style={{ margin: 0, lineHeight: 1.5, wordBreak: 'break-word', whiteSpace: 'pre-wrap', color: isAdmin ? '#9333ea' : '#334155', fontSize: '14px' }}>
                        {msg.message}
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>

            <div style={{ background: 'white', padding: '12px 16px', borderTop: '1px solid #e2e8f0', flexShrink: 0 }}>
              {selectedTicket?.issue?.includes('[장비 신청]') && (
                <div style={{ marginBottom: '8px' }}>
                  <button 
                    onClick={() => setInputValue('장비 접수를 진행합니다. 아래 버튼을 눌러 배송 주소와 연락처를 기재해 주세요!\\n[ACTION:EQUIPMENT_FORM]')}
                    style={{ background: '#f3e8ff', color: '#9333ea', border: '1px solid #d8b4fe', padding: '6px 12px', borderRadius: '4px', fontSize: '0.8rem', fontWeight: 600, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', transition: 'background 0.2s' }}
                    onMouseOver={(e) => e.currentTarget.style.background = '#e9d5ff'}
                    onMouseOut={(e) => e.currentTarget.style.background = '#f3e8ff'}
                  >
                    <span className="material-icons-outlined" style={{ fontSize: '14px' }}>feed</span>
                    장비 신청 폼 보내기
                  </button>
                </div>
              )}
              <div style={{ display: 'flex', alignItems: 'flex-end', background: '#f8fafc', borderRadius: '24px', padding: '8px 16px', border: '1px solid #e2e8f0' }}>
                <textarea
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' && !e.shiftKey) {
                      e.preventDefault();
                      handleSendReply();
                    }
                  }}
                  placeholder="Type your reply to the student..."
                  style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', resize: 'none', padding: '8px 0', fontSize: '15px', color: '#334155', maxHeight: '100px' }}
                  rows={1}
                />
                <button 
                  onClick={handleSendReply}
                  disabled={!inputValue.trim()}
                  style={{ 
                    background: inputValue.trim() ? '#9333ea' : '#cbd5e1', 
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
        </div>
      )}
    </DesktopLayout>
  );
}
