/* ==========================================================
 * TechOpsSummary 페이지 (Tech Ops Executive Summary Dashboard)
 * ----------------------------------------------------------
 * 기술 운영 요약 대시보드.
 *
 * [화면 구성]
 * - 글로벌 드롭아웃 위험도 게이지
 * - 고위험 학생 레이더 목록
 * - 커리큘럼 최적화 인사이트
 * - 취업시장 적합도 & 신흥 스킬 트렌드
 * ========================================================== */

import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import { useNavigate } from 'react-router-dom';
import {
  executiveUser, executiveMenuItems,
  globalDropoutRisk, highRiskStudents,
  curriculumOptimization, jobMarketFit, emergingSkills,
} from '../../data/executive';
import './Executive.css';

/**
 * TechOpsSummary 페이지
 *
 * 기술 운영 요약 — AI 리스크 분석, 고위험 학생, 커리큘럼 인사이트.
 */
export default function TechOpsSummary() {
  const navigate = useNavigate();

  return (
    <DesktopLayout
      brandTitle="EduAI Executive"
      brandSubtitle="Strategic Oversight"
      menuItems={executiveMenuItems}
      user={executiveUser}
      sidebarAction="Generate Report"
      sidebarActionIcon="description"
      showFooterLinks={true}
      headerTitle="Tech Ops Summary"
      headerAction="Go to TechOps Team"
      headerActionIcon="arrow_forward"
      onHeaderAction={() => navigate('/techops')}
    >
      {/* ── 페이지 헤더 ── */}
      <div className="content-section">
        <h2 className="content-section__title">Tech Ops Executive Summary</h2>
        <p className="content-section__subtitle">기술 운영 현황 요약 대시보드</p>
      </div>

      {/* ── AI Risk & Student Radar ── */}
      <div className="content-section">
        <h3 className="exec-section-title">
          <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>psychology</span>
          AI Intelligence & Risk Analysis
        </h3>

        <div className="exec-cards exec-cards--2">
          {/* 드롭아웃 위험도 */}
          <Card title="Global Dropout Risk Index" titleIcon="warning_amber">
            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-6)', marginTop: 'var(--space-4)' }}>
              <div className="big-percent">{globalDropoutRisk.value}%</div>
              <div>
                <div className="card__label">{globalDropoutRisk.label}</div>
                <p style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-secondary)', marginTop: 'var(--space-1)' }}>
                  {globalDropoutRisk.statusText}
                </p>
                <div className="progress-bar" style={{ marginTop: 'var(--space-2)' }}>
                  <div
                    className="progress-bar__fill"
                    style={{ width: `${(globalDropoutRisk.value / globalDropoutRisk.max) * 100}%` }}
                  />
                </div>
              </div>
            </div>
          </Card>

          {/* 고위험 학생 레이더 */}
          <Card title="High-Risk Student Radar" titleIcon="radar">
            <div className="risk-student-list">
              {highRiskStudents.map(student => (
                <div key={student.id} className="risk-student-item">
                  <span
                    className="material-icons-outlined"
                    style={{
                      color: student.riskLevel === 'high'
                        ? 'var(--color-danger)'
                        : student.riskLevel === 'medium'
                          ? 'var(--color-warning)'
                          : 'var(--color-success)',
                    }}
                  >
                    {student.riskLevel === 'high' ? 'error' : student.riskLevel === 'medium' ? 'warning' : 'info'}
                  </span>
                  <div className="risk-student-item__info">
                    <div className="risk-student-item__name">{student.name}</div>
                    <div className="risk-student-item__reason">{student.riskReason}</div>
                  </div>
                  <span className={`status-tag status-tag--${student.riskLevel === 'high' ? 'danger' : student.riskLevel === 'medium' ? 'warning' : 'success'}`}>
                    {student.riskLevel?.toUpperCase()}
                  </span>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </div>

      {/* ── Curriculum & Market ── */}
      <div className="content-section">
        <h3 className="exec-section-title">
          <span className="material-icons-outlined" style={{ color: 'var(--color-primary)' }}>school</span>
          Curriculum & Market Alignment
        </h3>

        <div className="exec-cards exec-cards--3">
          {/* 커리큘럼 최적화 인사이트 */}
          <Card title="Curriculum Optimization" titleIcon="auto_fix_high">
            <div className="insight-text" style={{ marginTop: 'var(--space-3)' }}>
              {curriculumOptimization.insight}
            </div>
            <p style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-primary)', marginTop: 'var(--space-3)', fontWeight: 'var(--font-weight-medium)' }}>
              💡 {curriculumOptimization.recommendation}
            </p>
          </Card>

          {/* 취업시장 적합도 */}
          <Card title="Job Market Fit" titleIcon="work">
            <div className="big-percent" style={{ marginTop: 'var(--space-3)' }}>{jobMarketFit}</div>
            <p style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-secondary)', marginTop: 'var(--space-2)' }}>
              Curriculum vs Job Market Alignment
            </p>
          </Card>

          {/* 신흥 스킬 트렌드 */}
          <Card title="Emerging Skill Trends" titleIcon="trending_up">
            <div className="skill-tags" style={{ marginTop: 'var(--space-3)' }}>
              {emergingSkills.map((skill, i) => (
                <span key={i} className="skill-tag">{skill}</span>
              ))}
            </div>
          </Card>
        </div>
      </div>
    </DesktopLayout>
  );
}
