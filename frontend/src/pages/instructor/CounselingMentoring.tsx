/* ==========================================================
 * CounselingMentoring 페이지
 * ----------------------------------------------------------
 * (목업 화면 #4) Counseling & AI Mentoring dashboard
 * AI가 식별한 요주의 학생 목록과 상담 제안
 * ========================================================== */

import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import {
  instructorUser,
  instructorMenuItems,
  counselingList,
} from '../../data/instructor';
import './Instructor.css';

export default function CounselingMentoring() {
  const { user } = useAuth();
  const currentUser = user || instructorUser;
  const [suggestions, setSuggestions] = useState<Record<string, string>>({});
  const [loadingId, setLoadingId] = useState<string | null>(null);

  const handleGenerateSuggestion = async (item: { id: string | number; name: string; issue: string }) => {
    setLoadingId(String(item.id));
    try {
      const response = await fetch('http://localhost:8000/api/v1/counseling/generate-suggestion', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          student_name: item.name,
          issue: item.issue,
        }),
      });
      const data = await response.json();
      setSuggestions(prev => ({ ...prev, [item.id]: data.ai_suggestion }));
    } catch (err) {
      console.error(err);
      setSuggestions(prev => ({ ...prev, [item.id]: 'Failed to connect to AI server.' }));
    } finally {
      setLoadingId(null);
    }
  };

  return (
    <DesktopLayout
      brandTitle="EduAI Instructor"
      brandSubtitle="AI Co-pilot"
      menuItems={instructorMenuItems}
      user={currentUser}
      showFooterLinks={true}
      headerTitle="Counseling & AI Mentoring"
      headerAction="Schedule Session"
      headerActionIcon="calendar_today"
    >
      <div className="instructor-grid">
        <div className="col-12">
          <Card title="Students Needing Attention (AI Flagged)">
            <div className="alert-list">
              {counselingList.map(item => (
                <div key={item.id} className="alert-item" style={{ borderLeftColor: item.urgency === 'High' ? 'var(--color-danger)' : 'var(--color-warning)' }}>
                  <div className="alert-item__content">
                    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)', marginBottom: 'var(--space-1)' }}>
                      <span className="alert-item__title">{item.name}</span>
                      <StatusTag
                        label={`${item.urgency} Urgency`}
                        variant={item.urgency === 'High' ? 'danger' : 'warning'}
                      />
                    </div>
                    <div className="alert-item__desc"><strong>Identified Issue:</strong> {item.issue}</div>
                    
                    {/* 실시간 AI 생성 내용 또는 기존 더미 표시 */}
                    <div className="alert-item__desc" style={{ marginTop: 'var(--space-1)', color: 'var(--color-primary)' }}>
                      <strong>AI Suggestion:</strong> {suggestions[item.id] || item.aiSuggestion}
                    </div>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <button 
                      className="button button--primary" 
                      onClick={() => handleGenerateSuggestion(item)}
                      disabled={loadingId === item.id}
                    >
                      {loadingId === item.id ? 'Generating...' : 'Refresh AI Suggestion'}
                    </button>
                    <button className="button button--outline">Action</button>
                  </div>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </div>
    </DesktopLayout>
  );
}
