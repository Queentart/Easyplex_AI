import { useState, useEffect } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import { mockTechUser, techMenu } from '../../data/techops';
import { opsLogService } from '../../api/opsLogService';

interface EquipmentRequest {
  id: string;
  student: string;
  phone: string;
  address: string;
  status: 'Pending' | 'Shipped' | 'Delivered' | 'Returned';
  date: string;
}

export default function EquipmentMgmt() {
  const [requests, setRequests] = useState<EquipmentRequest[]>([]);

  useEffect(() => {
    const loadRequests = () => {
      const data = localStorage.getItem('easyplex_equipment_requests');
      if (data) {
        setRequests(JSON.parse(data));
      }
    };
    loadRequests();
    
    // Listen for storage changes in case student submits while page is open
    window.addEventListener('storage', loadRequests);
    return () => window.removeEventListener('storage', loadRequests);
  }, []);

  const handleUpdateStatus = (id: string, newStatus: EquipmentRequest['status']) => {
    const updated = requests.map(req => req.id === id ? { ...req, status: newStatus } : req);
    setRequests(updated);
    localStorage.setItem('easyplex_equipment_requests', JSON.stringify(updated));
    
    const req = requests.find(r => r.id === id);
    if (req && req.status !== newStatus) {
      opsLogService.addLog(
        'Equipment Status Updated', 
        `${req.student}'s request changed to ${newStatus}`, 
        newStatus === 'Delivered' ? 'success' : 'info'
      );
    }
  };

  const getStatusVariant = (status: string) => {
    switch (status) {
      case 'Pending': return 'warning';
      case 'Shipped': return 'info';
      case 'Delivered': return 'success';
      case 'Returned': return 'neutral';
      default: return 'neutral';
    }
  };

  const pendingCount = requests.filter(r => r.status === 'Pending').length;
  const shippedCount = requests.filter(r => r.status === 'Shipped').length;

  return (
    <DesktopLayout
      brandTitle="TechOps Center"
      brandSubtitle="Systems & Infrastructure"
      menuItems={techMenu}
      user={mockTechUser}
      sidebarAction="Export Data"
      sidebarActionIcon="download"
    >
      <div className="flex flex-col gap-6 p-6">
        <header>
          <h1 className="text-2xl font-bold text-gray-800">장비 신청 관리 (Equipment Requests)</h1>
          <p className="text-gray-500">수강생들이 챗봇을 통해 요청한 노트북 등 학습 장비 신청 내역을 관리합니다.</p>
        </header>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card title="Total Requests" titleIcon="inventory" value={requests.length.toString()} />
          <Card title="Pending (접수 대기)" titleIcon="hourglass_empty" value={pendingCount.toString()} />
          <Card title="Shipped (배송 중)" titleIcon="local_shipping" value={shippedCount.toString()} />
          <Card title="Available Spares" titleIcon="check_box" value="42" />
        </div>

        <Card title="Student Equipment Requests" titleIcon="devices">
          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left">
              <thead className="bg-gray-50 text-gray-600">
                <tr>
                  <th className="px-4 py-3">Request ID</th>
                  <th className="px-4 py-3">Student Name</th>
                  <th className="px-4 py-3">Contact</th>
                  <th className="px-4 py-3">Shipping Address</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Request Date</th>
                  <th className="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {requests.map((req) => (
                  <tr key={req.id} className="hover:bg-gray-50/50 transition">
                    <td className="px-4 py-3 font-medium text-blue-600">{req.id}</td>
                    <td className="px-4 py-3 font-medium">{req.student}</td>
                    <td className="px-4 py-3">{req.phone}</td>
                    <td className="px-4 py-3 truncate max-w-[250px]" title={req.address}>{req.address}</td>
                    <td className="px-4 py-3">
                      <StatusTag label={req.status} variant={getStatusVariant(req.status)} />
                    </td>
                    <td className="px-4 py-3 text-gray-500">{new Date(req.date).toLocaleString()}</td>
                    <td className="px-4 py-3 text-right">
                      <select 
                        value={req.status}
                        onChange={(e) => handleUpdateStatus(req.id, e.target.value as EquipmentRequest['status'])}
                        style={{ border: '1px solid #e2e8f0', borderRadius: '4px', padding: '4px 8px', fontSize: '0.8rem', background: '#f8fafc', color: '#475569', cursor: 'pointer' }}
                      >
                        <option value="Pending">Pending (대기)</option>
                        <option value="Shipped">Shipped (발송)</option>
                        <option value="Delivered">Delivered (수령 완료)</option>
                        <option value="Returned">Returned (반납)</option>
                      </select>
                    </td>
                  </tr>
                ))}
                {requests.length === 0 && (
                  <tr>
                    <td colSpan={7} className="px-4 py-8 text-center text-gray-500">
                      현재 접수된 수강생 장비 신청 내역이 없습니다.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </Card>
      </div>
    </DesktopLayout>
  );
}
