/* ==========================================================
 * StudentMgmt 페이지 (학생 관리)
 * ----------------------------------------------------------
 * (목업 화면 #6) 학생 목록 테이블 + 상담 로그
 * ========================================================== */

import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import DataTable from '../../components/common/Table';
import StatusTag from '../../components/common/StatusTag';
import ProgressBar from '../../components/common/ProgressBar';
import { opsUser, students, studentStats, counselingLogs, opsMenu } from '../../data/eduops';
import './EduOps.css';

export default function StudentMgmt() {
  /** 학생 테이블 컬럼 정의 */
  const columns = [
    { key: 'id', header: 'STUDENT ID' },
    { key: 'name', header: 'STUDENT NAME' },
    { key: 'cohort', header: 'COHORT' },
    {
      key: 'attendance', header: 'ATTENDANCE',
      render: (val: string) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)', minWidth: 120 }}>
          <ProgressBar
            value={Number(val)}
            size="sm"
            variant={Number(val) >= 90 ? 'success' : Number(val) >= 80 ? 'warning' : 'danger'}
          />
          <span style={{ fontSize: 'var(--font-size-sm)', whiteSpace: 'nowrap' }}>{val}%</span>
        </div>
      ),
    },
    { key: 'counseling', header: 'RECENT COUNSELING' },
    {
      key: 'status', header: 'STATUS',
      render: (val: string) => <StatusTag label={val} variant={val} />,
    },
  ];

  const tableData = students.map(s => ({
    id: s.studentId,
    name: `${s.nameKo} (${s.name})`,
    cohort: s.cohort,
    attendance: String(s.attendanceRate),
    counseling: s.recentCounseling || '-',
    status: s.status,
  }));

  return (
    <DesktopLayout
      brandTitle="EduOps Center"
      brandSubtitle="운영 관리 대시보드"
      menuItems={opsMenu}
      user={opsUser}
      sidebarAction="Quick Report"
      sidebarActionIcon="description"
      showFooterLinks={true}
      headerTitle="Student Management"
      showSearch={true}
      searchPlaceholder="Search students..."
      headerAction="Add Student"
      headerActionIcon="person_add"
    >
      {/* ── 통계 요약 ── */}
      <div className="student-table-header">
        <div className="student-count">
          <span>Total Active: <strong>{studentStats.totalActive}</strong></span>
          <span>Attendance Warning: <strong style={{ color: 'var(--color-danger)' }}>{studentStats.attendanceWarning}</strong></span>
        </div>
      </div>

      {/* ── 학생 목록 테이블 ── */}
      <DataTable columns={columns} data={tableData} />

      {/* ── 최근 상담 로그 ── */}
      <div style={{ marginTop: 'var(--space-6)' }}>
        <Card title="Recent Counseling Logs" titleIcon="psychology">
          <div className="counseling-log-list">
            {counselingLogs.map((log, i) => (
              <div key={i} className="counseling-log-item">
                <div className="counseling-log-item__header">
                  <span className="counseling-log-item__student">{log.studentName}</span>
                  <span className="counseling-log-item__date">{log.date}</span>
                  <StatusTag label={log.type} variant={log.type === 'Intervention' ? 'warning' : 'info'} />
                </div>
                <div className="counseling-log-item__summary">{log.summary}</div>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </DesktopLayout>
  );
}
