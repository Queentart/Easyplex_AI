/* ==========================================================
 * Executive 대시보드 목업 데이터
 * ----------------------------------------------------------
 * Owner/Executive 뷰에서 사용되는 모든 더미 데이터를 정의합니다.
 *
 * [5개 페이지 매핑]
 * 1. OwnerCommandCenter    — Owner Executive Command Center
 * 2. EduOpsCommandCenter   — Edu Ops Command Center
 * 3. AcademicOversight     — Strategic Academic Oversight
 * 4. TechOpsSummary        — Tech Ops Executive Summary
 * 5. StrategicReports      — Strategic Reports & Insights
 * ========================================================== */

import type {
  MenuItem, KPICard, Tenant, AuditLog, CostCard,
  Cohort, Student, BarChartData
} from '../types';

/* ── 현재 로그인 사용자 (Owner) ── */
export const executiveUser = {
  id: 'owner-001',
  name: 'Executive Admin',
  role: 'owner' as const,
  title: 'Strategic Oversight',
  avatar: '',
};

/* ── 좌측 사이드바 메뉴 (5개 페이지 매핑) ── */
export const executiveMenuItems: MenuItem[] = [
  { id: 'command-center', label: 'Command Center', icon: 'dashboard', path: '/executive' },
  { id: 'eduops-cmd', label: 'Edu Ops', icon: 'school', path: '/executive/eduops' },
  { id: 'academic', label: 'Academic Oversight', icon: 'insights', path: '/executive/academic' },
  { id: 'techops', label: 'Tech Ops', icon: 'memory', path: '/executive/techops' },
  { id: 'reports', label: 'Reports & Insights', icon: 'assessment', path: '/executive/reports' },
  { id: 'streams', label: 'Class Streams', icon: 'ondemand_video', path: '/executive/streams' },
];

/* ── EduOps Command Center 데이터 ── */

/** 운영 KPI 카드 */
export const opsKpiCards: KPICard[] = [
  { id: 'ops-1', title: 'ACTIVE BATCHES', value: '8', subtitle: '+2 this quarter', trend: 'up', trendValue: '+2' },
  { id: 'ops-2', title: 'AVG. ATTENDANCE', value: '94.2%', subtitle: 'Target: 90%', trend: 'up' },
  { id: 'ops-3', title: 'COUNSELING PENDING', value: '5', subtitle: '2 urgent', trend: 'neutral' },
  { id: 'ops-4', title: 'DATA SYNC STATUS', value: 'Healthy', subtitle: 'Last sync: 5 min ago', trend: 'up' },
];

/** 최근 동기화 로그 */
export const syncLogs = [
  { id: 'sl1', source: 'Goyong24', status: 'success' as const, time: '5 mins ago', records: 1240 },
  { id: 'sl2', source: 'Zoom Attendance', status: 'success' as const, time: '12 mins ago', records: 890 },
  { id: 'sl3', source: 'LMS Grades', status: 'warning' as const, time: '1 hour ago', records: 456 },
];

/** 자동화 상태 */
export const automationStatus = [
  { id: 'auto-1', name: 'Attendance Auto-Sync', enabled: true, lastRun: 'Today 09:00', nextRun: 'Today 18:00' },
  { id: 'auto-2', name: 'Grade Report Generator', enabled: true, lastRun: 'Yesterday 22:00', nextRun: 'Today 22:00' },
  { id: 'auto-3', name: 'Risk Alert Engine', enabled: false, lastRun: 'N/A', nextRun: 'Disabled' },
];

/* ── GlobalOverview 데이터 ── */

/** 전략 인텔리전스 상태 태그 */
export const overviewStatusTags = [
  { label: 'Active Batches: 8', color: 'info' },
  { label: 'Budget Usage: 64%', color: 'warning' },
];

/** 수익성 & 활용도 차트 데이터 */
export const profitabilityChartData: BarChartData[] = [
  {
    label: 'Q3 Financial vs Capacity Metrics',
    values: [
      { label: 'Revenue', value: 85, color: 'var(--color-primary)' },
      { label: 'OpEx', value: 62, color: 'var(--color-info)' },
      { label: 'Capacity', value: 78, color: 'var(--color-border)' },
    ],
  },
];

/** 취업 성과 & ROI */
export const employmentROI = {
  targetROI: '150%',
  placementRate: '88%',
};

/** 드롭아웃 리스크 */
export const dropoutRisk = {
  riskPercent: '3%',
  riskLevel: 'Low' as const,
};

/** 커리큘럼 최적화 AI 제안 */
export const curriculumSuggestion = {
  message: 'Increase Python OOP sessions by 20% based on cohort performance analysis.',
  actions: ['Apply Optimization', 'Dismiss'],
};

/** 보안 설정 토글 */
export const securityToggles = [
  { id: 'global-admin', label: 'Global Admin Access', value: true },
  { id: 'cross-tenant', label: 'Cross-Tenant Data Sharing', value: false },
];

/** API 인프라 비용 */
export const infraCost = {
  amount: '$1,240/mo',
  status: 'Below target threshold',
};

/** 테넌트 구독 목록 */
export const tenantSubscriptions: Tenant[] = [
  { id: 't1', name: 'Dong-A AI Lab', licenseType: 'Enterprise Plus', activeUsers: 1200, renewalDate: '2027-03-01', status: 'active' },
  { id: 't2', name: 'SK Tech Academy', licenseType: 'Pro', activeUsers: 450, renewalDate: '2026-09-15', status: 'active' },
  { id: 't3', name: 'National University', licenseType: 'Basic', activeUsers: 180, renewalDate: '2026-12-01', status: 'active' },
];

/* ── StrategicKPIs 데이터 ── */

/** KPI 통계 카드 */
export const kpiCards: KPICard[] = [
  { id: 'kpi-1', title: 'OVERALL PROFITABILITY', value: '24.5%', subtitle: '+2.1% vs last quarter', trend: 'up', trendValue: '+2.1%' },
  { id: 'kpi-2', title: 'AVG. PLACEMENT RATE', value: '88.2%', subtitle: 'Target: 85%', trend: 'up' },
  { id: 'kpi-3', title: 'GLOBAL ROI', value: '142%', subtitle: 'Exceeding projections', trend: 'up' },
];

/** 수익성 & 활용 트렌드 차트 */
export const profitTrendData: BarChartData[] = [
  {
    label: 'Apr',
    values: [
      { label: 'Revenue', value: 72, color: 'var(--color-primary)' },
      { label: 'OpEx', value: 55, color: '#93C5FD' },
    ],
  },
  {
    label: 'May',
    values: [
      { label: 'Revenue', value: 80, color: 'var(--color-primary)' },
      { label: 'OpEx', value: 52, color: '#93C5FD' },
    ],
  },
  {
    label: 'Jun',
    values: [
      { label: 'Revenue', value: 88, color: 'var(--color-primary)' },
      { label: 'OpEx', value: 50, color: '#93C5FD' },
    ],
  },
];

/** 코호트별 취업 성과 */
export const placementCohorts: Cohort[] = [
  { id: 'c1', name: 'Batch 1 - Data Science', placementRate: 90 },
  { id: 'c2', name: 'Batch 2 - Machine Learning', placementRate: 85 },
  { id: 'c3', name: 'Batch 3 - AI Engineering', placementRate: 92 },
];

/** AI ROI 분석 테이블 */
export const roiAnalysisTable = {
  headers: ['CATEGORY', 'INVESTMENT', 'ROI MULTIPLE', 'STATUS'],
  rows: [
    ['Marketing', '$120,000', '3.2x', 'Optimal'],
    ['Infra', '$45,000', '1.8x', 'Optimal'],
  ],
};

/** ROI 인사이트 텍스트 */
export const roiInsight = 'Marketing efficiency has improved by 15% due to targeted cohort campaigns. Operational OpEx decreased by 8% leveraging LangGraph agent automations.';

/* ── AIIntelligence 데이터 ── */

/** 글로벌 드롭아웃 위험도 도넛 */
export const globalDropoutRisk = {
  value: 3.2,
  max: 100,
  label: 'RISK',
  color: 'var(--color-primary)',
  threshold: 10,
  statusText: 'Well below the 10% threshold.',
};

/** 고위험 학생 레이더 */
export const highRiskStudents: Student[] = [
  { id: 's1', studentId: '', name: 'Kim Chul-soo', nameKo: '김철수', cohort: '', attendanceRate: 0, status: 'warning', riskLevel: 'high', riskReason: 'Late 3 times in the last two weeks.' },
  { id: 's2', studentId: '', name: 'Lee Young-hee', nameKo: '이영희', cohort: '', attendanceRate: 0, status: 'warning', riskLevel: 'medium', riskReason: 'Low Assignment Score on recent modules.' },
  { id: 's3', studentId: '', name: 'Park Ji-min', nameKo: '박지민', cohort: '', attendanceRate: 0, status: 'active', riskLevel: 'low', riskReason: 'Decreased participation in forum discussions.' },
];

/** 커리큘럼 최적화 인사이트 */
export const curriculumOptimization = {
  insight: "45% of students in Batch 3 are struggling with the 'Multi-Agent System' module based on recent assignment grades.",
  recommendation: 'Allocate 2 additional hours of practical labs.',
};

/** 커리큘럼 vs 취업시장 적합도 */
export const jobMarketFit = '94%';

/** 신흥 스킬 트렌드 */
export const emergingSkills = ['#1 RAG Optimization', '#2 Local LLM Fine-tuning'];

/* ── GovernanceCost 데이터 ── */

/** 비용 카드 목록 */
export const costCards: CostCard[] = [
  { title: 'TOTAL CLOUD INFRA SPEND', value: '$4,250', change: '+12%', changeType: 'increase' },
  { title: 'LLM AGENT TOKEN USAGE', value: '12.4M Tokens', progress: 62, progressLabel: '62% of quota' },
  { title: 'BUDGET ALERT THRESHOLD', value: '$5,000 / month' },
];

/** 보안 토글 */
export const governanceSecurityToggles = [
  { id: 'data-isolation', label: 'Data Isolation', value: true },
  { id: '2fa', label: 'Two-Factor Authentication (2FA)', value: true },
  { id: 'intranet-only', label: 'Intranet-Only Policy', value: false },
];

/** 감사 로그 */
export const auditLogs: AuditLog[] = [
  { id: 'al1', message: 'Admin login from 192.168.1.45', icon: 'login', iconColor: 'var(--color-success)', time: '2 mins ago' },
  { id: 'al2', message: 'Policy updated: Data Isolation enabled', icon: 'settings', iconColor: 'var(--color-primary)', time: '1 hour ago' },
  { id: 'al3', message: 'Failed login attempt from unknown IP', icon: 'warning', iconColor: 'var(--color-danger)', time: 'Yesterday, 14:30' },
];

/** 테넌트 계약 테이블 */
export const tenantContracts: Tenant[] = [
  { id: 'tc1', name: 'Dong-A AI Lab', licenseType: 'Enterprise Plus', activeUsers: 1200, renewalDate: '2027-03-01', status: 'active' },
  { id: 'tc2', name: 'Seoul Edu Board', licenseType: 'Standard', activeUsers: 450, renewalDate: '2025-11-15', status: 'active' },
];
