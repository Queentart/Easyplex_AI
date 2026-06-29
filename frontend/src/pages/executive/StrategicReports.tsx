/* ==========================================================
 * StrategicReports 페이지 (Strategic Reports & Insights Dashboard)
 * ----------------------------------------------------------
 * 전략 리포트 & 인사이트 대시보드.
 *
 * [화면 구성]
 * - 비용 카드 (인프라, 토큰, 예산 임계값)
 * - 보안 & 거버넌스 토글
 * - 감사 로그 타임라인
 * - 테넌트 계약 테이블
 * ========================================================== */

import { useState } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import Toggle from '../../components/common/Toggle';
import {
  executiveUser, executiveMenuItems,
  costCards, governanceSecurityToggles,
  auditLogs, tenantContracts,
} from '../../data/executive';
import './Executive.css';

/**
 * StrategicReports 페이지
 *
 * 거버넌스, 비용, 보안, 테넌트 계약을 통합 관리하는 리포트 대시보드입니다.
 */
export default function StrategicReports() {
  const [secToggles, setSecToggles] = useState(governanceSecurityToggles);

  const handleToggleChange = (id: string, checked: boolean): void => {
    setSecToggles(prev => prev.map(t => t.id === id ? { ...t, value: checked } : t));
  };

  return (
    <DesktopLayout
      brandTitle="EduAI Executive"
      brandSubtitle="Strategic Oversight"
      menuItems={executiveMenuItems}
      user={executiveUser}
      sidebarAction="Generate Report"
      sidebarActionIcon="description"
      showFooterLinks={true}
      headerTitle="Reports & Insights"
      headerAction="Download Report"
      headerActionIcon="download"
    >
      {/* ── 페이지 헤더 ── */}
      <div className="content-section">
        <h2 className="content-section__title">Strategic Reports & Insights</h2>
        <p className="content-section__subtitle">전략 리포트 & 인사이트 대시보드</p>
      </div>

      {/* ── 비용 카드 ── */}
      <div className="content-section">
        <h3 className="exec-section-title">
          <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>payments</span>
          Cost & Budget Overview
        </h3>

        <div className="exec-cards exec-cards--3">
          {costCards.map((card, i) => (
            <Card key={i}>
              <div className="card__label">{card.title}</div>
              <div className="card__value card__value--primary">{card.value}</div>
              {card.change && (
                <span className={`cost-change cost-change--${card.changeType}`}>
                  <span className="material-icons-outlined" style={{ fontSize: '16px' }}>
                    {card.changeType === 'increase' ? 'arrow_upward' : 'arrow_downward'}
                  </span>
                  {card.change}
                </span>
              )}
              {card.progress !== undefined && (
                <div style={{ marginTop: 'var(--space-3)' }}>
                  <div className="progress-bar">
                    <div className="progress-bar__fill" style={{ width: `${card.progress}%` }} />
                  </div>
                  <div style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-tertiary)', marginTop: 'var(--space-1)' }}>
                    {card.progressLabel}
                  </div>
                </div>
              )}
            </Card>
          ))}
        </div>
      </div>

      {/* ── 거버넌스 + 감사 로그 ── */}
      <div className="content-section">
        <div className="exec-cards exec-cards--2">
          {/* 보안 거버넌스 토글 */}
          <Card title="Security & Governance" titleIcon="shield">
            <div className="security-toggles">
              {secToggles.map(toggle => (
                <Toggle
                  key={toggle.id}
                  label={toggle.label}
                  checked={toggle.value}
                  onChange={(checked) => handleToggleChange(toggle.id, checked)}
                />
              ))}
            </div>
          </Card>

          {/* 감사 로그 */}
          <Card title="Audit Trail" titleIcon="history">
            <div className="audit-log-list">
              {auditLogs.map(log => (
                <div key={log.id} className="audit-log-item">
                  <div className="audit-log-item__icon">
                    <span className="material-icons-outlined" style={{ fontSize: '18px', color: log.iconColor }}>
                      {log.icon}
                    </span>
                  </div>
                  <div className="audit-log-item__content">
                    <div className="audit-log-item__message">{log.message}</div>
                    <div className="audit-log-item__time">{log.time}</div>
                  </div>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </div>

      {/* ── 테넌트 계약 테이블 ── */}
      <div className="content-section">
        <Card title="Tenant Contracts" titleIcon="business">
          <table className="exec-table">
            <thead>
              <tr>
                <th>TENANT</th>
                <th>LICENSE</th>
                <th>ACTIVE USERS</th>
                <th>RENEWAL DATE</th>
                <th>STATUS</th>
              </tr>
            </thead>
            <tbody>
              {tenantContracts.map(tenant => (
                <tr key={tenant.id}>
                  <td className="exec-table__name">{tenant.name}</td>
                  <td>{tenant.licenseType}</td>
                  <td>{tenant.activeUsers.toLocaleString()}</td>
                  <td className="exec-table__meta">{tenant.renewalDate}</td>
                  <td>
                    <span className={`status-tag status-tag--${tenant.status}`}>
                      {tenant.status === 'active' ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      </div>
    </DesktopLayout>
  );
}
