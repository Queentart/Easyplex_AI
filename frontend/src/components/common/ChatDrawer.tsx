import { useState } from 'react';

// 간단한 상태관리를 위해 로컬 상태만 사용하지만,
// 실제 구현에서는 Context나 Zustand 등 전역 상태관리를 통해 
// 어떤 페이지에서든 열 수 있도록 해야 합니다.
interface ChatDrawerProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function ChatDrawer({ isOpen, onClose }: ChatDrawerProps) {
  const [messages, setMessages] = useState<{sender: string, text: string}[]>([
    { sender: 'student', text: '선생님, 과제 질문 있습니다.' }
  ]);
  const [input, setInput] = useState('');

  const sendMessage = () => {
    if (!input.trim()) return;
    setMessages([...messages, { sender: 'me', text: input }]);
    setInput('');
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-y-0 right-0 z-50 w-80 bg-white shadow-2xl flex flex-col border-l border-gray-200 transform transition-transform duration-300 ease-in-out">
      <div className="flex items-center justify-between p-4 border-b border-gray-200 bg-blue-600 text-white">
        <h3 className="font-semibold">학생 채팅 (팝업)</h3>
        <button onClick={onClose} className="text-white hover:text-gray-200">
          <span className="material-icons">close</span>
        </button>
      </div>
      
      <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50">
        {messages.map((msg, idx) => (
          <div key={idx} className={`flex ${msg.sender === 'me' ? 'justify-end' : 'justify-start'}`}>
            <div className={`rounded-lg px-4 py-2 max-w-[80%] ${msg.sender === 'me' ? 'bg-blue-600 text-white' : 'bg-white border border-gray-200 text-gray-800'}`}>
              <p className="text-sm">{msg.text}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="p-4 bg-white border-t border-gray-200">
        <div className="flex space-x-2">
          <input
            type="text"
            className="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="메시지 입력..."
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
          />
          <button 
            className="bg-blue-600 text-white rounded-lg px-4 py-2 text-sm font-medium hover:bg-blue-700"
            onClick={sendMessage}
          >
            전송
          </button>
        </div>
      </div>
    </div>
  );
}
