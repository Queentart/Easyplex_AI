import React, { useState } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import StatusTag from '../../components/common/StatusTag';
import { mockTechUser, techMenu } from '../../data/techops';

interface GeneratedAccount {
  id: string;
  name: string;
  email: string;
  tempPass: string;
  status: 'Ready';
}

export default function DailyOps() {
  const [isDragging, setIsDragging] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [accounts, setAccounts] = useState<GeneratedAccount[]>([]);

  // Simulate parsing a roster and generating accounts
  const handleSimulateUpload = () => {
    setIsProcessing(true);
    // Mock student names from a fake roster
    const mockNames = ['김철수', '이영희', '박민수', '최지윤', '정다운', '강하늘', '조수빈', '임동현', '한소희', '오현우'];
    
    setTimeout(() => {
      const generated = mockNames.map((name, index) => {
        const studentNumber = 20260001 + index;
        return {
          id: `acc_${Date.now()}_${index}`,
          name,
          email: `${studentNumber}@easyplex.com`,
          tempPass: `eplex${index + 1}!`,
          status: 'Ready' as const
        };
      });
      setAccounts(generated);
      setIsProcessing(false);
    }, 1500); // 1.5s simulated delay
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = () => {
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleSimulateUpload();
    }
  };

  const handleFileInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      handleSimulateUpload();
    }
  };

  return (
    <DesktopLayout
      brandTitle="TechOps Center"
      brandSubtitle="Systems & Infrastructure"
      menuItems={techMenu}
      user={mockTechUser}
      sidebarAction="Export Credentials"
      sidebarActionIcon="download"
    >
      <div className="flex flex-col gap-6 p-6">
        <header>
          <h1 className="text-2xl font-bold text-gray-800">계정 관리 (Account Management)</h1>
          <p className="text-gray-500">수강생 명단(Excel/PDF)을 업로드하여 일괄적으로 계정을 발급하고 관리합니다.</p>
        </header>

        {/* Upload Section */}
        <div 
          className={`border-2 border-dashed rounded-xl p-10 text-center transition-colors duration-200 flex flex-col items-center justify-center min-h-[200px]
            ${isDragging ? 'border-blue-500 bg-blue-50' : 'border-gray-300 bg-gray-50 hover:bg-gray-100'}`}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
        >
          {isProcessing ? (
            <div className="flex flex-col items-center gap-3">
              <span className="material-icons animate-spin text-blue-500" style={{ fontSize: 48 }}>autorenew</span>
              <p className="text-gray-600 font-medium">명단을 분석하고 계정을 생성 중입니다...</p>
            </div>
          ) : (
            <>
              <span className="material-icons text-gray-400 mb-3" style={{ fontSize: 48 }}>cloud_upload</span>
              <h3 className="text-lg font-bold text-gray-700 mb-1">수강생 명단 업로드 (Excel / PDF)</h3>
              <p className="text-sm text-gray-500 mb-4">여기로 파일을 드래그하거나 아래 버튼을 클릭하세요.</p>
              
              <label className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium cursor-pointer transition-colors flex items-center gap-2">
                <span className="material-icons" style={{ fontSize: 18 }}>attach_file</span>
                파일 선택하기
                <input type="file" className="hidden" accept=".xlsx,.pdf,.csv" onChange={handleFileInput} />
              </label>
              
              <button 
                onClick={handleSimulateUpload}
                className="mt-4 text-xs text-blue-500 underline bg-transparent border-none cursor-pointer"
              >
                (테스트용) 더미 명단 불러오기 시뮬레이션
              </button>
            </>
          )}
        </div>

        {/* Results Table */}
        {accounts.length > 0 && (
          <Card title="발급된 계정 목록 (Generated Accounts)" titleIcon="badge">
            <div className="overflow-x-auto">
              <table className="w-full text-sm text-left">
                <thead className="bg-gray-50 text-gray-600 border-b border-gray-200">
                  <tr>
                    <th className="px-4 py-3 font-semibold">No.</th>
                    <th className="px-4 py-3 font-semibold">Student Name</th>
                    <th className="px-4 py-3 font-semibold">Student ID (Email)</th>
                    <th className="px-4 py-3 font-semibold">Generated Password</th>
                    <th className="px-4 py-3 font-semibold text-center">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {accounts.map((acc, idx) => (
                    <tr key={acc.id} className="hover:bg-gray-50/50 transition-colors">
                      <td className="px-4 py-3 text-gray-500">{idx + 1}</td>
                      <td className="px-4 py-3 font-bold text-gray-800">{acc.name}</td>
                      <td className="px-4 py-3 font-medium text-blue-600">{acc.email}</td>
                      <td className="px-4 py-3 font-mono bg-gray-50 text-gray-700 tracking-wider">
                        {acc.tempPass}
                      </td>
                      <td className="px-4 py-3 text-center">
                        <StatusTag label={acc.status} variant="success" />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            
            <div className="mt-4 flex justify-end">
              <button className="bg-gray-800 hover:bg-gray-900 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors flex items-center gap-2">
                <span className="material-icons" style={{ fontSize: 16 }}>download</span>
                계정 엑셀 다운로드 (Export)
              </button>
            </div>
          </Card>
        )}
      </div>
    </DesktopLayout>
  );
}
