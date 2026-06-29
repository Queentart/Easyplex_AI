/* ==========================================================
 * OpsSettings 페이지 (EduOps 운영 설정)
 * ----------------------------------------------------------
 * (목업 화면 #9) API & Data Integration, AI Chatbot, Monitoring 설정
 * ========================================================== */

import { useState } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import Toggle from '../../components/common/Toggle';
import type { ToggleSetting } from '../../types';
import {
  opsUser,
  apiSettings, apiInputSettings,
  chatbotSettings, chatbotInputSettings,
  monitoringSettings, monitoringInputSettings,
  opsMenu
} from '../../data/eduops';
import './EduOps.css';

export default function OpsSettings() {
  const [apiToggles, setApiToggles] = useState<ToggleSetting[]>(apiSettings);
  const [chatToggles, setChatToggles] = useState<ToggleSetting[]>(chatbotSettings);
  const [monToggles, setMonToggles] = useState<ToggleSetting[]>(monitoringSettings);

  /** 토글 업데이트 헬퍼 */
  const updateToggle = (
    setter: React.Dispatch<React.SetStateAction<ToggleSetting[]>>,
    id: string,
    checked: boolean,
  ) => {
    setter(prev => prev.map(t => t.id === id ? { ...t, value: checked } : t));
  };

  type InputSetting = {
    id: string;
    label: string;
    type: 'select' | 'text' | 'password' | 'number' | string;
    value: string;
    options?: string[];
    unit?: string;
  };

  /** 입력 필드 렌더링 헬퍼 */
  const renderInputSettings = (inputs: InputSetting[]) => (
    <div className="settings-input-group">
      {inputs.map(input => (
        <div key={input.id} className="settings-input-item">
          <label>{input.label}</label>
          {input.type === 'select' && input.options ? (
            <select defaultValue={input.value}>
              {input.options.map((opt: string) => (
                <option key={opt} value={opt}>{opt}</option>
              ))}
            </select>
          ) : (
            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
              <input type={input.type} defaultValue={input.value} />
              {input.unit && <span style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-secondary)' }}>{input.unit}</span>}
            </div>
          )}
        </div>
      ))}
    </div>
  );

  return (
    <DesktopLayout
      brandTitle="EduOps Center"
      brandSubtitle="운영 관리 대시보드"
      menuItems={opsMenu}
      user={opsUser}
      showFooterLinks={true}
      headerTitle="EduOps Settings"
      headerAction="Deploy Updates"
      headerActionIcon="cloud_upload"
    >
      {/* ── API & Data Integration ── */}
      <div className="settings-section">
        <h3 className="settings-section__title">
          <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>cloud_sync</span>
          API & Data Integration
        </h3>
        <Card compact>
          {apiToggles.map(t => (
            <Toggle key={t.id} label={t.label} checked={t.value} onChange={(c) => updateToggle(setApiToggles, t.id, c)} />
          ))}
          {renderInputSettings(apiInputSettings)}
        </Card>
      </div>

      {/* ── AI Chatbot Configuration ── */}
      <div className="settings-section">
        <h3 className="settings-section__title">
          <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>smart_toy</span>
          AI Chatbot Configuration
        </h3>
        <Card compact>
          {chatToggles.map(t => (
            <Toggle key={t.id} label={t.label} checked={t.value} onChange={(c) => updateToggle(setChatToggles, t.id, c)} />
          ))}
          {renderInputSettings(chatbotInputSettings)}
        </Card>
      </div>

      {/* ── Monitoring & Alerting ── */}
      <div className="settings-section">
        <h3 className="settings-section__title">
          <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>monitoring</span>
          Monitoring & Alerting
        </h3>
        <Card compact>
          {monToggles.map(t => (
            <Toggle key={t.id} label={t.label} checked={t.value} onChange={(c) => updateToggle(setMonToggles, t.id, c)} />
          ))}
          {renderInputSettings(monitoringInputSettings)}
        </Card>
      </div>
    </DesktopLayout>
  );
}
