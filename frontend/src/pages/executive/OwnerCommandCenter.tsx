/* ==========================================================
 * OwnerCommandCenter 페이지 (Owner Executive Command Center)
 * ----------------------------------------------------------
 * 오너/경영진용 총괄 현황판 대시보드.
 *
 * [화면 구성]
 * - 전략 인텔리전스 센터 타이틀 + 테넌트 셀렉터 + 상태 태그
 * - Strategic Intelligence 섹션:
 *   · Profitability & Utilization 차트 카드
 *   · Employment Performance & ROI 카드
 *   · Dropout Risk Prediction 카드
 *   · Curriculum Optimization (AI Agent) 카드
 * - Governance & System Control 섹션:
 *   · Enterprise Security 토글 카드
 *   · API & Infrastructure Cost 카드
 *   · Tenant Subscriptions 리스트 카드
 * ========================================================== */

import { useState } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import Toggle from '../../components/common/Toggle';
import BarChart from '../../components/charts/BarChart';
import { useQuery } from '@tanstack/react-query';
import { dashboardApi } from '../../api/client';
import {
  executiveUser, executiveMenuItems,
  overviewStatusTags, profitabilityChartData,
  dropoutRisk, curriculumSuggestion,
  securityToggles, tenantSubscriptions,
} from '../../data/executive';
import './Executive.css';

/**
 * OwnerCommandCenter 페이지
 *
 * 경영진이 전체 플랫폼 현황을 한눈에 파악할 수 있는 전략 대시보드입니다.
 */
export default function OwnerCommandCenter() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['executiveDashboard'],
    queryFn: dashboardApi.getExecutive
  });

  const [secToggles, setSecToggles] = useState(securityToggles);

  const handleToggleChange = (id: string, checked: boolean): void => {
    setSecToggles(prev => prev.map(t => t.id === id ? { ...t, value: checked } : t));
  };

  const handleApplyOptimization = (): void => {
    // TODO: API 연동
    console.log('Apply Curriculum Optimization');
  };

  const handleDismiss = (): void => {
    console.log('Dismiss suggestion');
  };

  if (isLoading) return <div className="p-8">Loading Command Center...</div>;
  if (error) return <div className="p-8 text-red-500">Error loading data.</div>;

  const metrics = data?.kpiCards || [];
  const infraCostData = metrics.find((m: any) => m.id === 'cloud_infra_spend') || { value: '$12,450', trendValue: '0%' };
  const roiData = metrics.find((m: any) => m.id === 'global_roi') || { value: '320%' };
  const placementData = metrics.find((m: any) => m.id === 'avg_placement_rate') || { value: '94%' };

  return (
    <DesktopLayout
      brandTitle="EduAI Executive"
      brandSubtitle="Strategic Oversight"
      menuItems={executiveMenuItems}
      user={executiveUser}
      sidebarAction="Generate Report"
      sidebarActionIcon="description"
      showFooterLinks={true}
      headerTitle="Owner Command Center"
      headerTabs={[
        { id: 'dashboard', label: 'Command Center', active: true },
        { id: 'tenancy', label: 'Tenancy Controls', active: false },
        { id: 'metrics', label: 'Global Metrics', active: false },
      ]}
      headerAction="Strategic Intelligence"
      headerActionIcon="auto_fix_high"
      headerExtraIcons={[{ icon: 'grid_view' }]}
    >
      {/* ── 페이지 헤더 ── */}
      <div className="content-section">
        <div className="content-section__header">
          <div>
            <h2 className="content-section__title">Strategic Intelligence Center</h2>
            <p className="content-section__subtitle">오너 경영 지휘소</p>
          </div>
          <div className="tenant-selector">
            <select defaultValue="dong-a">
              <option value="dong-a">Dong-A AI Lab</option>
              <option value="sk">SK Tech Academy</option>
              <option value="national">National University</option>
            </select>
            {overviewStatusTags.map((tag, i) => (
              <span key={i} className={`status-tag status-tag--${tag.color}`}>{tag.label}</span>
            ))}
          </div>
        </div>
      </div>

      {/* ── Strategic Intelligence 섹션 ── */}
      <div className="content-section">
        <h3 className="exec-section-title">
          <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>auto_awesome</span>
          Strategic Intelligence
        </h3>

        <div className="exec-cards exec-cards--2">
          <Card title="Profitability & Utilization" titleIcon="trending_up">
            <BarChart data={profitabilityChartData} height={160} />
          </Card>

          <Card title="Employment Performance & ROI" titleIcon="work">
            <div style={{ display: 'flex', gap: 'var(--space-6)', marginTop: 'var(--space-3)' }}>
              <div>
                <div className="card__label">Target ROI</div>
                <div className="card__value card__value--primary">{roiData.value}</div>
              </div>
              <div>
                <div className="card__label">Placement Rate</div>
                <div className="card__value">{placementData.value}</div>
              </div>
            </div>
          </Card>

          <Card title="Dropout Risk Prediction" titleIcon="warning_amber">
            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-4)', marginTop: 'var(--space-3)' }}>
              <div className="card__value card__value--primary">{dropoutRisk.riskPercent}</div>
              <span className="status-tag status-tag--success">Risk Level: {dropoutRisk.riskLevel}</span>
            </div>
          </Card>

          <Card title="Curriculum Optimization (AI Agent)" titleIcon="auto_fix_high">
            <p style={{ fontSize: 'var(--font-size-base)', color: 'var(--color-text-secondary)', marginTop: 'var(--space-2)' }}>
              {curriculumSuggestion.message}
            </p>
            <div className="card__actions">
              <button className="btn btn-primary btn-sm" onClick={handleApplyOptimization}>
                Apply Optimization
              </button>
              <button className="btn btn-outline btn-sm" onClick={handleDismiss}>
                Dismiss
              </button>
            </div>
          </Card>
        </div>
      </div>

      {/* ── Governance & System Control 섹션 ── */}
      <div className="content-section">
        <h3 className="exec-section-title">
          <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>security</span>
          Governance & System Control
        </h3>

        <div className="exec-cards exec-cards--3">
          <Card title="Enterprise Security" titleIcon="shield">
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

          <Card title="API & Infrastructure Cost" titleIcon="cloud">
            <div className="card__value" style={{ marginTop: 'var(--space-3)' }}>{infraCostData.value}</div>
            <p style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-secondary)', marginTop: 'var(--space-2)' }}>
              Compared to last month: {infraCostData.trendValue}
            </p>
          </Card>

          <Card title="Tenant Subscriptions" titleIcon="business">
            <div className="tenant-list">
              {tenantSubscriptions.map(tenant => (
                <div key={tenant.id} className="tenant-list-item">
                  <div>
                    <div className="tenant-list-item__name">{tenant.name}</div>
                    <div className="tenant-list-item__type">{tenant.licenseType}</div>
                  </div>
                  <span className="status-tag status-tag--active">Active</span>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </div>
    </DesktopLayout>
  );
}
