import React, { useEffect, useState, useRef } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import { opsMenu, opsUser } from '../../data/eduops';
import { announcementApi } from '../../api/announcementApi';
import type { Announcement } from '../../api/announcementApi';

const Announcements: React.FC = () => {
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newContent, setNewContent] = useState('');
  const [isImportant, setIsImportant] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  
  const fileInputRef = useRef<HTMLInputElement>(null);

  const fetchAnnouncements = async () => {
    try {
      setLoading(true);
      const data = await announcementApi.getOpsAnnouncements();
      setAnnouncements(data);
    } catch (error) {
      console.error('Failed to fetch announcements', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const loadData = async () => {
      await fetchAnnouncements();
    };
    loadData();
  }, []);

  const handleCreate = async () => {
    if (!newTitle || !newContent) return;
    try {
      await announcementApi.createAnnouncement({
        title: newTitle,
        content: newContent,
        is_important: isImportant,
        file: selectedFile
      });
      setShowModal(false);
      setNewTitle('');
      setNewContent('');
      setIsImportant(false);
      setSelectedFile(null);
      fetchAnnouncements();
    } catch (error) {
      console.error('Failed to create announcement', error);
      alert('공지사항 작성에 실패했습니다.');
    }
  };

  const handleDelete = async (id: number) => {
    if (!window.confirm('정말 삭제하시겠습니까?')) return;
    try {
      await announcementApi.deleteAnnouncement(id);
      fetchAnnouncements();
    } catch (error) {
      console.error('Failed to delete announcement', error);
      alert('공지사항 삭제에 실패했습니다.');
    }
  };

  return (
    <DesktopLayout
      brandTitle="Easyplex"
      brandSubtitle="EduOps Portal"
      menuItems={opsMenu}
      user={opsUser}
      headerTitle="공지사항 관리"
      headerSubtitle="수강생들에게 중요한 일정과 정보를 전달합니다."
      showSearch={false}
    >
      <div className="w-full h-full p-6 bg-gray-50" style={{ minHeight: 'calc(100vh - 70px)' }}>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden w-full">
          <div className="border-b border-gray-200 bg-white flex justify-between items-center" style={{ padding: '24px 32px' }}>
            <h2 className="text-xl font-bold text-gray-800 tracking-tight">등록된 공지사항</h2>
            <button
              onClick={() => setShowModal(true)}
              className="btn btn-primary shadow-sm hover:-translate-y-0.5"
            >
              <span className="material-icons-outlined mr-2" style={{ fontSize: '20px' }}>campaign</span>
              새 공지사항 작성
            </button>
          </div>

          {loading ? (
             <div className="flex flex-col items-center justify-center text-gray-400" style={{ padding: '80px' }}>
               <span className="material-icons-outlined animate-spin text-4xl mb-4 text-blue-500">autorenew</span>
               <p>공지사항을 불러오는 중입니다...</p>
             </div>
          ) : announcements.length === 0 ? (
            <div className="flex flex-col items-center justify-center text-gray-400" style={{ padding: '80px' }}>
              <span className="material-icons-outlined text-5xl mb-4 text-gray-300">campaign</span>
              <p className="text-lg">등록된 공지사항이 없습니다.</p>
            </div>
          ) : (
            <div className="divide-y divide-gray-200">
              {announcements.map((announcement) => (
                <div key={announcement.id} className="hover:bg-gray-50 transition-colors duration-300 flex justify-between items-center" style={{ padding: '24px 32px' }}>
                  <div className="flex flex-col">
                    <div className="flex items-center gap-3 mb-2">
                      {announcement.is_important && (
                        <span className="px-2 py-0.5 bg-red-100 text-red-700 font-bold text-xs rounded-full border border-red-200">
                          중요
                        </span>
                      )}
                      <h3 className="text-lg font-bold text-gray-900">{announcement.title}</h3>
                    </div>
                    <p className="text-gray-500 text-sm mb-2 line-clamp-2">{announcement.content}</p>
                    <div className="flex items-center gap-4 text-sm text-gray-400">
                      <span className="flex items-center gap-1">
                        <span className="material-icons-outlined" style={{ fontSize: '16px' }}>schedule</span>
                        {new Date(announcement.created_at).toLocaleString()}
                      </span>
                      {announcement.attachment_name && (
                        <span className="flex items-center gap-1 text-blue-500">
                          <span className="material-icons-outlined" style={{ fontSize: '16px' }}>attach_file</span>
                          {announcement.attachment_name}
                        </span>
                      )}
                    </div>
                  </div>
                  <button
                    onClick={() => handleDelete(announcement.id)}
                    className="text-red-500 hover:text-red-700 bg-red-50 hover:bg-red-100 p-2 rounded-full transition-colors flex items-center justify-center"
                    title="삭제"
                  >
                    <span className="material-icons-outlined">delete</span>
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* 새 공지사항 작성 모달 */}
        {showModal && (
          <div className="fixed inset-0 bg-gray-900/50 backdrop-blur-sm flex items-center justify-center z-50 transition-opacity">
            <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl overflow-hidden transform transition-all animate-fade-in" style={{ display: 'flex', flexDirection: 'column' }}>
              <div className="flex justify-between items-center text-white" style={{ padding: '24px 32px', background: 'linear-gradient(to right, var(--color-primary), var(--color-primary-dark))' }}>
                <h2 className="text-xl font-bold flex items-center" style={{ gap: '8px', margin: 0 }}>
                  <span className="material-icons-outlined">campaign</span>
                  <span>새 공지사항 작성</span>
                </h2>
                <button onClick={() => setShowModal(false)} className="text-white hover:text-gray-200 bg-white/10 hover:bg-white/20 p-1 rounded-full transition flex items-center justify-center" style={{ width: '32px', height: '32px' }}>
                  <span className="material-icons-outlined" style={{ fontSize: '20px' }}>close</span>
                </button>
              </div>

              <div style={{ padding: '32px', display: 'flex', flexDirection: 'column', gap: '24px' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <label className="text-sm font-bold text-gray-700">공지 제목 <span className="text-red-500">*</span></label>
                  <input
                    type="text"
                    className="w-full border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-shadow bg-gray-50 focus:bg-white"
                    style={{ padding: '12px 16px' }}
                    value={newTitle}
                    onChange={(e) => setNewTitle(e.target.value)}
                    placeholder="수강생들이 쉽게 알 수 있는 제목을 입력하세요"
                  />
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <label className="text-sm font-bold text-gray-700">공지 내용 <span className="text-red-500">*</span></label>
                  <textarea
                    className="w-full border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none transition-shadow bg-gray-50 focus:bg-white"
                    style={{ padding: '12px 16px', height: '192px' }}
                    value={newContent}
                    onChange={(e) => setNewContent(e.target.value)}
                    placeholder="상세한 공지 내용을 작성하세요..."
                  ></textarea>
                </div>

                {/* 첨부파일 영역 */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <label className="text-sm font-bold text-gray-700">첨부파일</label>
                  <div 
                    className="border-2 border-dashed border-gray-300 rounded-xl hover:bg-gray-50 cursor-pointer transition flex flex-col items-center justify-center"
                    style={{ padding: '24px', gap: '8px', textAlign: 'center' }}
                    onClick={() => fileInputRef.current?.click()}
                  >
                    <input 
                      type="file" 
                      className="hidden" 
                      ref={fileInputRef}
                      onChange={(e) => {
                        if (e.target.files && e.target.files[0]) {
                          setSelectedFile(e.target.files[0]);
                        }
                      }}
                    />
                    {selectedFile ? (
                      <div className="flex items-center bg-blue-50 text-blue-700 rounded-lg border border-blue-200" style={{ padding: '8px 16px', gap: '12px' }}>
                        <span className="material-icons-outlined">insert_drive_file</span>
                        <span className="font-medium">{selectedFile.name}</span>
                        <span className="text-sm opacity-70">({(selectedFile.size / 1024).toFixed(1)} KB)</span>
                        <button 
                          className="text-red-500 hover:text-red-700 flex items-center justify-center" 
                          style={{ marginLeft: '8px' }}
                          onClick={(e) => {
                            e.stopPropagation();
                            setSelectedFile(null);
                            if (fileInputRef.current) fileInputRef.current.value = '';
                          }}
                        >
                          <span className="material-icons-outlined" style={{ fontSize: '18px' }}>close</span>
                        </button>
                      </div>
                    ) : (
                      <>
                        <div className="bg-gray-100 rounded-full flex items-center justify-center text-gray-400" style={{ width: '48px', height: '48px', marginBottom: '4px' }}>
                          <span className="material-icons-outlined">cloud_upload</span>
                        </div>
                        <p className="text-gray-600 font-medium m-0">클릭하여 파일을 첨부하세요</p>
                        <p className="text-gray-400 text-sm m-0">PDF, 이미지, 압축파일 등 허용</p>
                      </>
                    )}
                  </div>
                </div>

                <div className="flex items-center bg-red-50 border border-red-100 rounded-xl cursor-pointer" style={{ padding: '16px', gap: '12px' }} onClick={() => setIsImportant(!isImportant)}>
                  <div className={`rounded flex items-center justify-center border transition ${isImportant ? 'bg-red-500 border-red-500' : 'bg-white border-gray-300'}`} style={{ width: '24px', height: '24px', flexShrink: 0 }}>
                    {isImportant && <span className="material-icons text-white" style={{ fontSize: '18px' }}>check</span>}
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                    <label className="text-sm font-bold text-red-800 cursor-pointer m-0">중요 공지로 등록</label>
                    <p className="text-xs text-red-600 m-0">체크 시 수강생 화면 최상단에 붉은색으로 강조되어 표시됩니다.</p>
                  </div>
                </div>
              </div>

              <div className="bg-gray-50 flex justify-end items-center border-t border-gray-200" style={{ padding: '20px 32px', gap: '12px' }}>
                <button
                  onClick={() => setShowModal(false)}
                  className="font-bold text-gray-600 bg-white border border-gray-300 hover:bg-gray-100 rounded-xl transition"
                  style={{ padding: '10px 24px' }}
                >
                  취소
                </button>
                <button
                  onClick={handleCreate}
                  className="btn btn-primary shadow-md disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
                  style={{ padding: '10px 24px', gap: '8px', borderRadius: '0.75rem' }}
                  disabled={!newTitle || !newContent}
                >
                  <span className="material-icons-outlined" style={{ fontSize: '20px' }}>send</span>
                  <span>공지 등록하기</span>
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </DesktopLayout>
  );
};

export default Announcements;
