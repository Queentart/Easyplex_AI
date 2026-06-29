/* ==========================================================
 * TechSupport 페이지 (기술 지원)
 * ----------------------------------------------------------
 * (목업 화면 #15) 매뉴얼 카드, 이슈 제출 폼
 * ========================================================== */

import { useState } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import type { MenuItem } from '../../types';
import { executiveUser } from '../../data/executive';
import { supportManuals } from '../../data/student';
import '../student/Student.css';

const adminMenu: MenuItem[] = [
  { id: 'global', label: 'Global Overview', icon: 'dashboard', path: '/executive' },
  { id: 'kpis', label: 'Strategic KPIs', icon: 'insights', path: '/executive/kpis' },
  { id: 'ai', label: 'AI Intelligence', icon: 'psychology', path: '/executive/ai' },
  { id: 'governance', label: 'Governance & Cost', icon: 'admin_panel_settings', path: '/executive/governance' },
];

export default function TechSupport() {
  const [formData, setFormData] = useState({
    submitter: '',
    category: '',
    urgency: '',
    description: '',
  });

  /** TODO: 이슈 제출 핸들러 (백엔드 API 연동 필요) */
  const handleSubmitIssue = () => {
    console.log('Submit issue:', formData);
  };

  return (
    <DesktopLayout
      brandTitle="EduAI Executive"
      brandSubtitle="Strategic Oversight"
      menuItems={adminMenu}
      user={executiveUser}
      showFooterLinks={true}
      headerTitle="Technical Support & Manuals"
    >
      {/* ── 매뉴얼 카드 그리드 ── */}
      <h3 className="settings-group__title">Quick Access Manuals</h3>
      <div className="support-card-grid">
        {supportManuals.map(manual => (
          <div key={manual.id} className="support-card">
            <div className="support-card__icon">
              <span className="material-icons-outlined" style={{ fontSize: 24 }}>{manual.icon}</span>
            </div>
            <div className="support-card__title">{manual.title}</div>
            <div className="support-card__desc">{manual.description}</div>
          </div>
        ))}
      </div>

      {/* ── 이슈 제출 폼 ── */}
      <div style={{ marginTop: 'var(--space-6)' }}>
        <Card title="Submit an Issue" titleIcon="bug_report">
          <div className="issue-form">
            <div>
              <label>Submitter</label>
              <input
                type="text"
                placeholder="Your name"
                value={formData.submitter}
                onChange={(e) => setFormData(prev => ({ ...prev, submitter: e.target.value }))}
              />
            </div>
            <div>
              <label>Category</label>
              <select
                value={formData.category}
                onChange={(e) => setFormData(prev => ({ ...prev, category: e.target.value }))}
              >
                <option value="">Select category...</option>
                <option value="auth">Authentication</option>
                <option value="data">Data Sync</option>
                <option value="ai">AI Agent</option>
                <option value="ui">UI/UX</option>
                <option value="other">Other</option>
              </select>
            </div>
            <div>
              <label>Urgency</label>
              <select
                value={formData.urgency}
                onChange={(e) => setFormData(prev => ({ ...prev, urgency: e.target.value }))}
              >
                <option value="">Select urgency...</option>
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
                <option value="critical">Critical</option>
              </select>
            </div>
            <div>
              <label>Description</label>
              <textarea
                placeholder="Describe the issue in detail..."
                value={formData.description}
                onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
              />
            </div>
            <button className="btn btn-primary" onClick={handleSubmitIssue}>
              <span className="material-icons" style={{ fontSize: 18 }}>send</span>
              Submit Issue
            </button>
          </div>
        </Card>
      </div>
    </DesktopLayout>
  );
}
