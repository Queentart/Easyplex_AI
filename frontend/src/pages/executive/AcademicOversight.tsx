/* ==========================================================
 * AcademicOversight 페이지 (Strategic Academic Oversight Dashboard)
 * ----------------------------------------------------------
 * 학사 전략 감독 대시보드.
 *
 * [화면 구성]
 * - KPI 통계 카드 (수익성, 취업률, ROI)
 * - 수익성 & 활용 트렌드 바 차트
 * - 코호트별 취업 성과 프로그레스
 * - ROI 분석 테이블
 * - AI 커리큘럼 인사이트
 * ========================================================== */

import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import BarChart from '../../components/charts/BarChart';
import {
  executiveUser, executiveMenuItems,
  kpiCards, profitTrendData,
  placementCohorts, roiAnalysisTable, roiInsight,
} from '../../data/executive';
import './Executive.css';

/**
 * AcademicOversight 페이지
 *
 * 학사 전략 감독 대시보드 — KPI, 취업 성과, ROI 분석, 커리큘럼 인사이트.
 */
export default function AcademicOversight() {
  return (
    <DesktopLayout
      brandTitle="EduAI Executive"
      brandSubtitle="Strategic Oversight"
      menuItems={executiveMenuItems}
      user={executiveUser}
      sidebarAction="Generate Report"
      sidebarActionIcon="description"
      showFooterLinks={true}
      headerTitle="Academic Oversight"
      headerAction="Export KPIs"
      headerActionIcon="download"
    >
      {/* ── 페이지 헤더 ── */}
      <div className="content-section">
        <h2 className="content-section__title">Strategic Academic Oversight</h2>
        <p className="content-section__subtitle">학사 전략 감독 대시보드</p>
      </div>

      {/* ── KPI 요약 카드 ── */}
      <div className="content-section">
        <div className="exec-cards exec-cards--3">
          {kpiCards.map(kpi => (
            <Card key={kpi.id}>
              <div className="card__label">{kpi.title}</div>
              <div className="card__value card__value--primary">{kpi.value}</div>
              <div className="card__subtitle">
                {kpi.trend === 'up' && (
                  <span className="material-icons-outlined" style={{ fontSize: '16px', color: 'var(--color-success)' }}>trending_up</span>
                )}
                {kpi.trendValue && <span style={{ color: 'var(--color-success)', marginRight: 'var(--space-1)' }}>{kpi.trendValue}</span>}
                {kpi.subtitle}
              </div>
            </Card>
          ))}
        </div>
      </div>

      {/* ── 트렌드 + 코호트 취업률 ── */}
      <div className="content-section">
        <div className="exec-cards exec-cards--2">
          {/* 수익성 & 활용 트렌드 */}
          <Card title="Profitability & Utilization Trend" titleIcon="trending_up">
            <BarChart data={profitTrendData} height={200} />
          </Card>

          {/* 코호트별 취업 성과 */}
          <Card title="Cohort Placement Performance" titleIcon="work">
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
        </div>
      </div>

      {/* ── ROI 분석 + 인사이트 ── */}
      <div className="content-section">
        <div className="exec-cards exec-cards--2">
          {/* ROI 분석 테이블 */}
          <Card title="AI ROI Analysis" titleIcon="analytics">
            <table className="exec-table">
              <thead>
                <tr>
                  {roiAnalysisTable.headers.map((h, i) => (
                    <th key={i}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {roiAnalysisTable.rows.map((row, i) => (
                  <tr key={i}>
                    {row.map((cell, j) => (
                      <td key={j} className={j === 3 ? 'exec-table__status' : ''}>{cell}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </Card>

          {/* ROI 인사이트 */}
          <Card title="AI Insight" titleIcon="lightbulb">
            <div className="insight-text">{roiInsight}</div>
          </Card>
        </div>
      </div>
    </DesktopLayout>
  );
}
