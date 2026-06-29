/* ==========================================================
 * AdminSettings 페이지 (관리자 설정)
 * ----------------------------------------------------------
 * (목업 화면 #14) Enterprise Security, API Key, 시스템 설정
 * ========================================================== */

import { useState } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import Toggle from '../../components/common/Toggle';
import type { MenuItem, ToggleSetting } from '../../types';
import { executiveUser } from '../../data/executive';
import { adminSecuritySettings } from '../../data/student';
import '../student/Student.css';

const adminMenu: MenuItem[] = [
  { id: 'global', label: 'Global Overview', icon: 'dashboard', path: '/executive' },
  { id: 'kpis', label: 'Strategic KPIs', icon: 'insights', path: '/executive/kpis' },
  { id: 'ai', label: 'AI Intelligence', icon: 'psychology', path: '/executive/ai' },
  { id: 'governance', label: 'Governance & Cost', icon: 'admin_panel_settings', path: '/executive/governance' },
];

export default function AdminSettings() {
  const [secToggles, setSecToggles] = useState<ToggleSetting[]>(adminSecuritySettings);

  const handleToggle = (id: string, checked: boolean) => {
    setSecToggles(prev => prev.map(t => t.id === id ? { ...t, value: checked } : t));
  };

  return (
    <DesktopLayout
      brandTitle="EduAI Executive"
      brandSubtitle="Strategic Oversight"
      menuItems={adminMenu}
      user={executiveUser}
      showFooterLinks={true}
      headerTitle="Admin Settings"
      headerAction="Save Changes"
      headerActionIcon="save"
    >
      <div className="settings-group">
        <h3 className="settings-group__title">Enterprise Security</h3>
        <Card compact>
          {secToggles.map(t => (
            <Toggle key={t.id} label={t.label} checked={t.value} onChange={(c) => handleToggle(t.id, c)} />
          ))}
        </Card>
      </div>

      <div className="settings-group">
        <h3 className="settings-group__title">System Configuration</h3>
        <Card compact>
          <div className="settings-input-group">
            <div className="settings-input-item">
              <label>Platform Name</label>
              <input type="text" defaultValue="EduAI Platform" style={{ maxWidth: 240 }} />
            </div>
            <div className="settings-input-item">
              <label>Support Email</label>
              <input type="email" defaultValue="admin@eduai.com" style={{ maxWidth: 240 }} />
            </div>
            <div className="settings-input-item">
              <label>Default Language</label>
              <select defaultValue="ko" style={{ maxWidth: 240 }}>
                <option value="ko">한국어</option>
                <option value="en">English</option>
              </select>
            </div>
          </div>
        </Card>
      </div>
    </DesktopLayout>
  );
}
