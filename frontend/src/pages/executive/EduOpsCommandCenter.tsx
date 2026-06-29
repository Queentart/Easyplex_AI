/* ==========================================================
 * EduOpsCommandCenter 페이지 (Edu Ops Command Center Dashboard)
 * ----------------------------------------------------------
 * 교육 운영 총괄 대시보드.
 *
 * [화면 구성]
 * - 운영 KPI 카드 4개 (활성 배치, 출석률, 상담 대기, 동기화 상태)
 * - 코호트별 진행 현황 프로그레스 바
 * - 최근 동기화 로그
 * - 자동화 상태 요약
 * ========================================================== */

import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import {
  executiveUser, executiveMenuItems,
  opsKpiCards, syncLogs, automationStatus,
  placementCohorts,
} from '../../data/executive';
import './Executive.css';

/**
 * EduOpsCommandCenter 페이지
 *
 * 교육 운영 전반을 모니터링하는 Command Center 대시보드입니다.
 * 배치 현황, 출석, 동기화, 자동화 상태를 한눈에 볼 수 있습니다.
 */
export default function EduOpsCommandCenter() {
  return (
    <DesktopLayout
      brandTitle="EduAI Executive"
      brandSubtitle="Strategic Oversight"
      menuItems={executiveMenuItems}
      user={executiveUser}
      sidebarAction="Generate Report"
      sidebarActionIcon="description"
      showFooterLinks={true}
      headerTitle="Edu Ops Command Center"
      headerAction="Sync All"
      headerActionIcon="sync"
    >
      {/* ── 페이지 헤더 ── */}
      <div className="content-section">
        <h2 className="content-section__title">Edu Ops Command Center</h2>
        <p className="content-section__subtitle">교육 운영 총괄 대시보드</p>
      </div>

      {/* ── 운영 KPI 카드 ── */}
      <div className="content-section">
        <h3 className="exec-section-title">
          <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>speed</span>
          Operational KPIs
        </h3>
        <div className="exec-cards exec-cards--4">
          {opsKpiCards.map(kpi => (
            <Card key={kpi.id}>
              <div className="card__label">{kpi.title}</div>
              <div className="card__value card__value--primary">{kpi.value}</div>
              <div className="card__subtitle">
                {kpi.trend === 'up' && <span className="material-icons-outlined" style={{ fontSize: '16px', color: 'var(--color-success)' }}>trending_up</span>}
                {kpi.subtitle}
              </div>
            </Card>
          ))}
        </div>
      </div>

      {/* ── 코호트 진행 현황 + 동기화 로그 ── */}
      <div className="content-section">
        <div className="exec-cards exec-cards--2">
          {/* 코호트 진행 현황 */}
          <Card title="Cohort Progress" titleIcon="groups">
            <div className="cohort-progress-list">
              {placementCohorts.map(cohort => (
                <div key={cohort.id} className="cohort-progress-item">
                  <div className="cohort-progress-item__header">
                    <span className="cohort-progress-item__name">{cohort.name}</span>
                    <span className="cohort-progress-item__rate">{cohort.placementRate}%</span>
                  </div>
                  <div className="progress-bar">
                    <div
                      className="progress-bar__fill"
                      style={{ width: `${cohort.placementRate}%` }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </Card>

          {/* 최근 동기화 로그 */}
          <Card title="Recent Sync Logs" titleIcon="sync">
            <div className="sync-log-list">
              {syncLogs.map(log => (
                <div key={log.id} className="sync-log-item">
                  <div className="sync-log-item__icon">
                    <span
                      className="material-icons-outlined"
                      style={{ fontSize: '18px', color: log.status === 'success' ? 'var(--color-success)' : 'var(--color-warning)' }}
                    >
                      {log.status === 'success' ? 'check_circle' : 'warning'}
                    </span>
                  </div>
                  <div className="sync-log-item__content">
                    <div className="sync-log-item__source">{log.source}</div>
                    <div className="sync-log-item__meta">{log.records.toLocaleString()} records · {log.time}</div>
                  </div>
                  <span className={`status-tag status-tag--${log.status}`}>
                    {log.status === 'success' ? 'Synced' : 'Partial'}
                  </span>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </div>

      {/* ── 자동화 상태 ── */}
      <div className="content-section">
        <h3 className="exec-section-title">
          <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>smart_toy</span>
          Automation Status
        </h3>
        <Card>
          <div className="automation-table">
            <table className="exec-table">
              <thead>
                <tr>
                  <th>AUTOMATION</th>
                  <th>STATUS</th>
                  <th>LAST RUN</th>
                  <th>NEXT RUN</th>
                </tr>
              </thead>
              <tbody>
                {automationStatus.map(auto => (
                  <tr key={auto.id}>
                    <td className="exec-table__name">{auto.name}</td>
                    <td>
                      <span className={`status-tag status-tag--${auto.enabled ? 'success' : 'inactive'}`}>
                        {auto.enabled ? 'Active' : 'Disabled'}
                      </span>
                    </td>
                    <td className="exec-table__meta">{auto.lastRun}</td>
                    <td className="exec-table__meta">{auto.nextRun}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </DesktopLayout>
  );
}
