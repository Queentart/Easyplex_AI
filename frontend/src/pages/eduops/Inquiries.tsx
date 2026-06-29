import { useState, useEffect, useCallback } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import { opsMenu, opsUser } from '../../data/eduops';
import type { OpsTicket } from '../../types';

export default function Inquiries() {
  const [tickets, setTickets] = useState<OpsTicket[]>([]);
  const [loading, setLoading] = useState(true);
  const [replyText, setReplyText] = useState('');
  const [selectedTicketId, setSelectedTicketId] = useState<number | null>(null);

  const fetchTickets = useCallback(async () => {
    try {
      const res = await fetch('http://localhost:8000/api/v1/ops/inquiries');
      if (res.ok) {
        const data = await res.json();
        setTickets(data.data);
      }
    } catch (err) {
      console.error('Failed to fetch tickets:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchTickets();
  }, [fetchTickets]);

  const handleReplySubmit = async (ticketId: number) => {
    if (!replyText.trim()) return;

    try {
      const res = await fetch(`http://localhost:8000/api/v1/ops/inquiries/${ticketId}/reply`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reply: replyText }),
      });

      if (res.ok) {
        setReplyText('');
        setSelectedTicketId(null);
        fetchTickets(); // Refresh list
      }
    } catch (err) {
      console.error('Failed to submit reply:', err);
    }
  };

  return (
    <DesktopLayout
      brandTitle="Easyplex"
      brandSubtitle="EduOps Portal"
      menuItems={opsMenu}
      user={opsUser}
      headerTitle="문의사항 (Inquiries)"
      headerSubtitle="수강생들이 운영팀에 남긴 문의 내역을 확인하고 답변합니다."
      showSearch
      searchPlaceholder="Search tickets..."
    >
      <div className="w-full h-full p-6 bg-gray-50" style={{ minHeight: 'calc(100vh - 70px)' }}>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden w-full">
          <div className="border-b border-gray-200 bg-white flex justify-between items-center" style={{ padding: '24px 32px' }}>
            <h2 className="text-xl font-bold text-gray-800 tracking-tight">티켓 목록</h2>
            <span className="bg-gray-100 rounded-full border border-gray-200 text-sm font-medium text-gray-700 shadow-sm" style={{ padding: '6px 16px' }}>
              총 <span className="text-blue-600 font-bold">{tickets.length}</span> 건
            </span>
          </div>

          {loading ? (
            <div className="flex flex-col items-center justify-center text-gray-400" style={{ padding: '80px' }}>
              <span className="material-icons-outlined animate-spin text-4xl mb-4 text-blue-500">autorenew</span>
              <p>Loading tickets...</p>
            </div>
          ) : tickets.length === 0 ? (
            <div className="flex flex-col items-center justify-center text-gray-400" style={{ padding: '80px' }}>
              <span className="material-icons-outlined text-5xl mb-4 text-gray-300">inbox</span>
              <p className="text-lg">새로운 문의 내역이 없습니다.</p>
            </div>
          ) : (
            <div className="divide-y divide-gray-200">
              {tickets.map(ticket => (
                <div key={ticket.id} className="hover:bg-gray-50 transition-colors duration-300" style={{ padding: '40px 48px' }}>
                  <div className="flex justify-between items-start" style={{ marginBottom: '32px' }}>
                    <div className="flex items-center gap-4">
                      <div className="rounded-full bg-blue-100 text-blue-600 flex items-center justify-center font-bold shadow-inner" style={{ width: '56px', height: '56px', fontSize: '18px' }}>
                        {ticket.student_name.substring(0, 2)}
                      </div>
                      <div>
                        <h3 className="font-bold text-gray-900" style={{ fontSize: '20px' }}>{ticket.student_name}</h3>
                        <p className="text-gray-500 font-medium" style={{ fontSize: '14px', marginTop: '4px' }}>
                          {new Date(ticket.created_at).toLocaleString()} <span className="mx-2 text-gray-300">|</span> Ticket #{ticket.id}
                        </p>
                      </div>
                    </div>
                    <div>
                      <span className={`rounded-full font-bold shadow-sm ${
                        ticket.status === 'answered' ? 'bg-green-100 text-green-700 border border-green-200' : 'bg-amber-100 text-amber-800 border border-amber-200'
                      }`} style={{ padding: '8px 20px', fontSize: '14px' }}>
                        {ticket.status === 'answered' ? '답변 완료' : '대기 중'}
                      </span>
                    </div>
                  </div>

                  <div className="bg-white rounded-xl text-gray-800 border border-gray-200 shadow-sm" style={{ padding: '32px', marginBottom: '24px', fontSize: '16px', lineHeight: '1.8' }}>
                    <div className="flex items-center gap-2 font-bold text-gray-500 tracking-wide" style={{ marginBottom: '16px', fontSize: '15px' }}>
                      <span className="material-icons-outlined" style={{ fontSize: '20px' }}>help_outline</span>
                      문의 내용
                    </div>
                    <div className="border-l-4 border-gray-200" style={{ paddingLeft: '24px', color: '#334155' }}>
                      {ticket.message}
                    </div>
                  </div>

                  {ticket.status === 'answered' ? (
                    <div className="bg-blue-50 rounded-xl text-blue-900 border border-blue-200 shadow-sm" style={{ padding: '32px', fontSize: '16px', lineHeight: '1.8' }}>
                      <div className="flex items-center gap-2 font-bold text-blue-600 tracking-wide" style={{ marginBottom: '16px', fontSize: '15px' }}>
                        <span className="material-icons-outlined" style={{ fontSize: '20px' }}>quickreply</span>
                        운영팀 답변 ({new Date(ticket.replied_at!).toLocaleString()})
                      </div>
                      <div className="border-l-4 border-blue-300" style={{ paddingLeft: '24px', color: '#1e3a8a' }}>
                        {ticket.reply}
                      </div>
                    </div>
                  ) : (
                    <div style={{ marginTop: '16px' }}>
                      {selectedTicketId === ticket.id ? (
                        <div className="bg-white border border-blue-200 rounded-xl shadow-sm" style={{ padding: '24px' }}>
                          <div className="flex items-center gap-2 font-bold text-blue-600 tracking-wide" style={{ marginBottom: '16px', fontSize: '15px' }}>
                            <span className="material-icons-outlined" style={{ fontSize: '20px' }}>edit</span>
                            답변 작성하기
                          </div>
                          <textarea
                            className="w-full border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-shadow"
                            rows={1}
                            style={{ minHeight: '100px', overflow: 'hidden', resize: 'none', padding: '20px', fontSize: '16px', lineHeight: '1.8' }}
                            placeholder="답변을 입력하세요... (Enter로 전송, Shift+Enter로 줄바꿈)"
                            value={replyText}
                            onChange={(e) => {
                              setReplyText(e.target.value);
                              e.target.style.height = 'auto';
                              e.target.style.height = `${e.target.scrollHeight}px`;
                            }}
                            onKeyDown={(e) => {
                              if (e.key === 'Enter' && !e.shiftKey) {
                                e.preventDefault();
                                handleReplySubmit(ticket.id);
                              }
                            }}
                          ></textarea>
                          <div className="flex justify-end gap-3" style={{ marginTop: '20px' }}>
                            <button
                              className="font-bold rounded-lg transition-all"
                              style={{ padding: '12px 24px', fontSize: '15px', backgroundColor: '#f1f5f9', color: '#475569', border: '1px solid #e2e8f0' }}
                              onClick={() => {
                                setSelectedTicketId(null);
                                setReplyText('');
                              }}
                            >
                              작성 취소
                            </button>
                            <button
                              className="rounded-lg transition-all shadow-md flex items-center gap-2 hover:shadow-lg transform hover:-translate-y-0.5"
                              style={{ padding: '12px 28px', fontSize: '15px', backgroundColor: '#2563eb', color: '#ffffff', fontWeight: 600 }}
                              onClick={() => handleReplySubmit(ticket.id)}
                            >
                              <span className="material-icons-outlined" style={{ fontSize: '20px' }}>send</span>
                              답변 즉시 등록
                            </button>
                          </div>
                        </div>
                      ) : (
                        <button
                          className="bg-blue-50 border border-blue-100 font-bold text-blue-700 hover:bg-blue-100 hover:text-blue-800 flex items-center gap-2 rounded-lg transition-colors"
                          style={{ padding: '12px 24px', fontSize: '15px' }}
                          onClick={() => setSelectedTicketId(ticket.id)}
                        >
                          <span className="material-icons-outlined" style={{ fontSize: '20px' }}>reply</span>
                          이 문의에 답변하기
                        </button>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </DesktopLayout>
  );
}
