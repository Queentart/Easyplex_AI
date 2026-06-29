/* ==========================================================
 * AICopilot.tsx - AI 채팅 코파일럿 페이지
 * ----------------------------------------------------------
 * 강사용 AI 채팅 인터페이스 페이지.
 * 현재 instructor.ts의 데이터 구조에 맞게 정렬됨.
 *
 * [주요 기능]
 * - 강사가 AI와 자연어로 대화
 * - 빠른 질문 버튼(QuickAction) 제공
 * - 채팅 메시지 송신 및 표시
 * ========================================================== */

import { useRef, useState } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import { useAuth } from '../../contexts/AuthContext';
import {
  instructorUser,
  instructorMenuItems,
} from '../../data/instructor';
import './AICopilot.css';

/* ─────────────────────────────────────────
 * 타입 정의
 * ───────────────────────────────────────── */

/** 채팅 메시지 단건 */
interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
}

/** 빠른 질문 버튼 */
interface QuickAction {
  id: string;
  label: string;
  icon: string;
}

/* ─────────────────────────────────────────
 * 초기 목업 데이터
 * ───────────────────────────────────────── */

/** 초기 채팅 이력 (목업) */
const INITIAL_MESSAGES: ChatMessage[] = [
  {
    id: 'msg-1',
    role: 'assistant',
    content: 'Hello Dr. Thorne! I\'m your AI teaching assistant. How can I help you today?',
    timestamp: '09:00 AM',
  },
  {
    id: 'msg-2',
    role: 'user',
    content: 'Can you summarize today\'s attendance status?',
    timestamp: '09:01 AM',
  },
  {
    id: 'msg-3',
    role: 'assistant',
    content: '94.2% attendance rate today. 3 students marked absent: Park Min-woo, and 2 others. Park Min-woo\'s rate has dropped to 75% — would you like me to send an automated check-in message?',
    timestamp: '09:01 AM',
  },
];

/** 빠른 질문 버튼 목록 */
const QUICK_ACTIONS: QuickAction[] = [
  { id: 'qa-1', label: 'Summarize Attendance', icon: 'how_to_reg' },
  { id: 'qa-2', label: 'List Pending Grades', icon: 'grading' },
  { id: 'qa-3', label: 'Flag At-Risk Students', icon: 'warning' },
  { id: 'qa-4', label: 'Generate Weekly Report', icon: 'summarize' },
];

/* ─────────────────────────────────────────
 * 컴포넌트
 * ───────────────────────────────────────── */

/**
 * AICopilot 페이지
 *
 * 강사가 AI와 직접 대화할 수 있는 채팅 인터페이스.
 * QuickAction 버튼으로 자주 쓰는 질문을 빠르게 전송할 수 있습니다.
 */
export default function AICopilot() {
  const { user } = useAuth();
  const currentUser = user || instructorUser;

  /** 채팅 메시지 상태 */
  const [messages, setMessages] = useState<ChatMessage[]>(INITIAL_MESSAGES);

  /** 입력창 상태 */
  const [input, setInput] = useState<string>('');

  /**
   * 메시지 전송 핸들러
   * @param text - 전송할 메시지 문자열
   */
  /**
   * 메시지 ID 생성용 카운터 ref
   * - useRef를 사용하여 렌더링에 영향 없이 고유 ID를 생성합니다.
   * - React Compiler의 impure function 규칙을 준수합니다.
   */
  const msgIdRef = useRef<number>(INITIAL_MESSAGES.length);

  const handleSend = (text: string): void => {
    const trimmed = text.trim();
    if (!trimmed) return;

    /**
     * 타임스탬프는 이벤트 핸들러 진입 시 한 번만 계산합니다.
     * Date 객체를 이벤트 핸들러(렌더 사이클 밖)에서만 사용하여
     * React Compiler의 purity 경고를 방지합니다.
     */
    const timestamp = new Date().toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
    });

    /* crypto.randomUUID() — W3C 표준 UUID 생성 API */
    /* Date.now() 대신 사용: React Compiler가 Date.now를 impure로 감지함 */
    const userMsg: ChatMessage = {
      id: `msg-${crypto.randomUUID()}`,
      role: 'user',
      content: trimmed,
      timestamp,
    };

    // TODO: 실제 AI API 호출로 교체
    const aiMsg: ChatMessage = {
      id: `msg-${crypto.randomUUID()}`,
      role: 'assistant',
      content: `(AI response to: "${trimmed}") — This is a placeholder response. Backend integration pending.`,
      timestamp,
    };

    msgIdRef.current += 1;
    setMessages(prev => [...prev, userMsg, aiMsg]);
    setInput('');
  };

  /**
   * QuickAction 버튼 클릭 핸들러
   * @param action - 클릭된 QuickAction 객체
   */
  const handleQuickAction = (action: QuickAction): void => {
    handleSend(action.label);
  };

  return (
    <DesktopLayout
      brandTitle="EduAI Instructor"
      brandSubtitle="AI Co-pilot"
      menuItems={instructorMenuItems}
      user={currentUser}
      showFooterLinks={true}
      headerTitle="AI Copilot"
      headerAction="Clear Chat"
      headerActionIcon="delete_sweep"
    >
      <div className="copilot-layout">
        {/* ── 채팅 영역 ── */}
        <Card title="AI Assistant Chat">
          <div className="copilot-messages" aria-label="Chat messages">
            {messages.map((msg: ChatMessage) => (
              <div
                key={msg.id}
                className={`copilot-bubble copilot-bubble--${msg.role}`}
              >
                <div className="copilot-bubble__content">{msg.content}</div>
                <div className="copilot-bubble__time">{msg.timestamp}</div>
              </div>
            ))}
          </div>

          {/* ── 빠른 질문 버튼 ── */}
          <div className="copilot-quick-actions">
            {QUICK_ACTIONS.map((qa: QuickAction) => (
              <button
                key={qa.id}
                className="copilot-quick-btn"
                onClick={() => handleQuickAction(qa)}
                aria-label={`Quick action: ${qa.label}`}
              >
                <span className="material-icons-outlined">{qa.icon}</span>
                {qa.label}
              </button>
            ))}
          </div>

          {/* ── 메시지 입력창 ── */}
          <div className="copilot-input-row">
            <input
              className="copilot-input"
              type="text"
              placeholder="Ask your AI assistant anything..."
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') handleSend(input);
              }}
              aria-label="Chat input"
            />
            <button
              className="button button--primary"
              onClick={() => handleSend(input)}
              aria-label="Send message"
            >
              <span className="material-icons-outlined">send</span>
            </button>
          </div>
        </Card>
      </div>
    </DesktopLayout>
  );
}
