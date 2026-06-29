import { useState, useEffect } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import { useNavigate } from 'react-router-dom';
import { mockTechUser, techMenu } from '../../data/techops';
import { vodService } from '../../api/vodService';
import { opsLogService } from '../../api/opsLogService';
import type { OpsLog } from '../../api/opsLogService';
import type { RecordedLecture } from '../../types';
import '../instructor/Instructor.css';

interface Ticket {
  id: string | number;
  student: string;
  issue: string;
  priority: string;
  status: string;
  date: string;
}

interface EquipmentRequest {
  id: string;
  student: string;
  phone: string;
  address: string;
  status: 'Pending' | 'Shipped' | 'Delivered' | 'Returned';
  date: string;
}

export default function TechTeamMgmt() {
  const navigate = useNavigate();

  // Live States
  const [equipmentRequests, setEquipmentRequests] = useState<EquipmentRequest[]>([]);
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [vods, setVods] = useState<RecordedLecture[]>([]);
  const [opsLogs, setOpsLogs] = useState<OpsLog[]>([]);

  useEffect(() => {
    const loadLocalData = () => {
      const eqData = localStorage.getItem('easyplex_equipment_requests');
      if (eqData) setEquipmentRequests(JSON.parse(eqData));
      setVods(vodService.getVODs());
      setOpsLogs(opsLogService.getLogs());
    };
    
    loadLocalData();

    window.addEventListener('storage', loadLocalData);
    return () => window.removeEventListener('storage', loadLocalData);
  }, []);

  useEffect(() => {
    fetch('http://localhost:8000/api/v1/tech/student-mgmt/tickets')
      .then(res => res.json())
      .then(data => {
        if (data.status === 'success' && data.data) {
          setTickets(data.data);
        }
      })
      .catch(console.error);
  }, []);

  // Filtering for Dashboard
  const pendingEquipment = equipmentRequests.filter(req => req.status === 'Pending').slice(0, 3);
  const activeEquipment = equipmentRequests.filter(req => req.status !== 'Pending').slice(0, 2);
  const urgentTickets = tickets.filter(t => t.priority === 'Critical' || t.priority === 'High' || t.status === 'Open').slice(0, 3);
  const recentVods = vods.slice(0, 3);
  const recentLogs = opsLogs.slice(0, 5);

  return (
    <DesktopLayout
      brandTitle="TechOps Center"
      brandSubtitle="Systems & Infrastructure"
      menuItems={techMenu}
      user={mockTechUser}
      showFooterLinks={true}
      headerTitle="Tech Team Management"
      headerAction="New Ticket"
      headerActionIcon="add"
    >
      <div className="instructor-dashboard-grid">
        <div className="dashboard-section priority-high">
          {/* 1. 장비 상태 및 유지보수 알림 (Equipment) */}
          <Card 
            title="장비 신청 내역 (Equipment)" 
            titleIcon="monitor_heart" 
            className="card-highlight card-highlight-warning"
            action={<button className="button button--text" onClick={() => navigate('/techops/equipment')}>Manage</button>}
          >
            <div className="list-container">
              <h4 className="list-title text-warning">Pending Requests</h4>
              {pendingEquipment.length === 0 && <div className="p-3 text-sm text-gray-500">대기 중인 장비 신청이 없습니다.</div>}
              {pendingEquipment.map(eq => (
                <div key={eq.id} className="list-item danger-border">
                  <div className="list-item-header">
                    <strong>{eq.student}</strong>
                    <StatusTag label={eq.status} variant="warning" />
                  </div>
                  <div className="list-item-desc text-muted">Request Date: {eq.date}</div>
                </div>
              ))}
              
              {activeEquipment.length > 0 && <h4 className="list-title text-success mt-4">Recently Processed</h4>}
              {activeEquipment.map(eq => (
                <div key={eq.id} className="list-item compact">
                  <div className="list-item-header">
                    <strong>{eq.student}</strong>
                    <StatusTag label={eq.status} variant={eq.status === 'Delivered' ? 'success' : 'info'} />
                  </div>
                </div>
              ))}
            </div>
          </Card>

          {/* 2. 학생 시스템 지원 (Urgent Tickets) */}
          <Card 
            title="학생 시스템 지원 (Tickets)" 
            titleIcon="confirmation_number" 
            className="card-highlight card-highlight-danger"
            action={<button className="button button--text" onClick={() => navigate('/techops/students')}>Tickets</button>}
          >
            <div className="list-container">
              <h4 className="list-title text-danger">Urgent Account/System Issues</h4>
              {urgentTickets.length === 0 && <div className="p-3 text-sm text-gray-500">긴급 티켓이 없습니다.</div>}
              {urgentTickets.map(tkt => (
                <div key={tkt.id} className="list-item urgent-item">
                  <div className="list-item-header">
                    <strong className="text-danger">{tkt.student} - {tkt.issue}</strong>
                    <StatusTag label={tkt.priority} variant={tkt.priority === 'Critical' ? 'danger' : 'warning'} />
                  </div>
                  <div className="list-item-desc text-muted">Status: {tkt.status} | Date: {tkt.date}</div>
                </div>
              ))}
            </div>
          </Card>
        </div>

        <div className="dashboard-section priority-medium">
          {/* 1. 실시간 스트리밍 모니터링 (VODs) */}
          <Card 
            title="최신 스트리밍/VOD 상태" 
            titleIcon="ondemand_video"
            action={<button className="button button--text" onClick={() => navigate('/techops/streams')}>Streams</button>}
          >
            <div className="list-container">
              {recentVods.length === 0 && <div className="p-3 text-sm text-gray-500">업로드된 VOD가 없습니다.</div>}
              {recentVods.map(vod => (
                <div key={vod.id} className="list-item compact">
                  <div className="list-item-header">
                    <strong>Week {vod.week}: {vod.title}</strong>
                    <StatusTag label="Uploaded" variant="success" />
                  </div>
                  <div className="list-item-desc text-muted" style={{ display: 'flex', gap: '16px' }}>
                    <span>Date: {vod.date}</span>
                    <span>Duration: {vod.duration}</span>
                  </div>
                </div>
              ))}
            </div>
          </Card>

          {/* 2. 학생 계정 관리  */}
          <Card 
            title="학생 계정 관리 " 
            titleIcon="list_alt"
            action={<button className="button button--text" onClick={() => navigate('/techops/daily')}>Logs</button>}
          >
            <div className="list-container">
              {recentLogs.length === 0 && <div className="p-3 text-sm text-gray-500">시스템 로그가 없습니다.</div>}
              {recentLogs.map(log => (
                <div key={log.id} className="list-item compact">
                  <div className="list-item-header">
                    <strong className={log.status === 'warning' ? 'text-warning' : log.status === 'success' ? 'text-success' : log.status === 'error' ? 'text-danger' : 'text-primary'}>
                      {log.action}
                    </strong>
                    <span className="text-muted" style={{ fontSize: '11px' }}>{log.timestamp}</span>
                  </div>
                  <div className="list-item-desc text-muted" style={{ fontSize: '12px' }}>
                    {log.detail}
                  </div>
                </div>
              ))}
            </div>
          </Card>
        </div>

        <div className="dashboard-section priority-low">
          <h3 className="section-heading">Quick Links</h3>
          <div className="quick-links-panel">
            <button className="quick-link-btn" onClick={() => navigate('/techops/equipment')}>
              <span className="material-icons text-primary">add_to_queue</span>
              <span>신규 장비 관리</span>
            </button>
            <button className="quick-link-btn" onClick={() => navigate('/techops/students')}>
              <span className="material-icons text-primary">person_add</span>
              <span>학생 계정 및 티켓</span>
            </button>
            <button className="quick-link-btn" onClick={() => navigate('/techops/streams')}>
              <span className="material-icons text-primary">sensors</span>
              <span>스트리밍 및 VOD 관리</span>
            </button>
          </div>
        </div>
      </div>
    </DesktopLayout>
  );
}
