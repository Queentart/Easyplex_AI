import type { MenuItem, User } from '../types';

export const mockTechUser: User = {
  id: 'u4',
  name: 'Tech Admin',
  nameKo: '기술지원팀',
  role: 'admin',
  title: 'Lead System Engineer',
  email: 'tech@easyplex.com'
};

export const techMenu: MenuItem[] = [
  { id: 'tm_dash', label: '대시보드', icon: 'admin_panel_settings', path: '/techops' },
  { id: 'tm_equip', label: '장비 신청', icon: 'devices', path: '/techops/equipment' },
  { id: 'tm_students', label: '학생 관리', icon: 'manage_accounts', path: '/techops/students' },
  { id: 'tm_daily', label: '계정 관리', icon: 'badge', path: '/techops/daily' },
  { id: 'tm_stream', label: '스트리밍 관리', icon: 'ondemand_video', path: '/techops/streams' },
];

export const systemHealth = [
  { service: 'LMS Platform', status: 'Healthy', uptime: '99.98%', latency: '45ms' },
  { service: 'AI Grading Engine', status: 'Healthy', uptime: '99.95%', latency: '120ms' },
  { service: 'Database (PostgreSQL)', status: 'Healthy', uptime: '99.99%', latency: '12ms' },
  { service: 'Caching (Redis)', status: 'Warning', uptime: '99.90%', latency: '35ms' },
  { service: 'Video Streaming CDN', status: 'Healthy', uptime: '99.99%', latency: '22ms' },
];

export const equipmentList = [
  { id: 'EQ-001', type: 'Server', name: 'DB-Primary', status: 'Active', nextMaintenance: '2026-07-01' },
  { id: 'EQ-002', type: 'Network', name: 'Core Router', status: 'Active', nextMaintenance: '2026-06-25' },
  { id: 'EQ-003', type: 'Workstation', name: 'Instructor-PC-01', status: 'Needs Repair', nextMaintenance: '2026-06-15' },
  { id: 'EQ-004', type: 'AV', name: 'Projector-RoomA', status: 'Active', nextMaintenance: '2026-08-10' },
];

export const techStudentTickets = [
  { id: 'TKT-101', student: '지수현', issue: 'Password Reset', status: 'Open', priority: 'High', date: '10 mins ago' },
  { id: 'TKT-102', student: '김민수', issue: 'Cannot access assignments', status: 'In Progress', priority: 'Medium', date: '1 hour ago' },
  { id: 'TKT-103', student: '이현우', issue: 'Video playback buffering', status: 'Resolved', priority: 'Low', date: '2 days ago' },
];

export const dailyOperationsLogs = [
  { time: '08:00 AM', event: 'Daily Database Backup Completed', type: 'Info' },
  { time: '09:15 AM', event: 'High CPU Usage on AI Engine', type: 'Warning' },
  { time: '11:30 AM', event: 'User Sync with SIS successful', type: 'Success' },
  { time: '01:05 PM', event: 'Redis cache latency spike', type: 'Warning' },
];

export const streamHealth = [
  { roomId: 'ROOM-A', title: 'Week 5 React Deep Dive', status: 'Live', viewers: 145, latency: '2s', bandwidth: 'Excellent' },
  { roomId: 'ROOM-B', title: 'Backend Special Session', status: 'Live', viewers: 42, latency: '8s', bandwidth: 'Warning' },
  { roomId: 'ROOM-C', title: 'Test Stream', status: 'Offline', viewers: 0, latency: '-', bandwidth: '-' },
];

export const urgentTickets = [
  { id: 'TKT-101', student: '지수현', issue: '비밀번호 초기화 요청 (로그인 잠금)', status: 'Open', priority: 'Critical', date: '10 mins ago' },
  { id: 'TKT-105', student: '박진우', issue: '계정 활성화 동기화 오류', status: 'Open', priority: 'High', date: '30 mins ago' },
];
