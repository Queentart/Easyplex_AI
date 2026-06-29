import React, { useState, useEffect, useRef } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import Card from '../../components/common/Card';
import { useAuth } from '../../contexts/AuthContext';
import { instructorMenuItems } from '../../data/instructor';
import { materialApi } from '../../api/materialApi';
import type { CourseMaterial } from '../../api/materialApi';
import './Instructor.css';

export default function CourseMaterials() {
  const { user } = useAuth();
  const [isDragging, setIsDragging] = useState(false);
  const [materials, setMaterials] = useState<CourseMaterial[]>([]);
  const [loading, setLoading] = useState(true);
  
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [isUploading, setIsUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const fetchMaterials = async () => {
    try {
      setLoading(true);
      const data = await materialApi.getMaterials();
      setMaterials(data);
    } catch (error) {
      console.error('Failed to fetch materials:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const loadInitialData = async () => {
      try {
        const data = await materialApi.getMaterials();
        setMaterials(data);
      } catch (error) {
        console.error('Failed to fetch materials:', error);
      } finally {
        setLoading(false);
      }
    };
    loadInitialData();
  }, []);

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = () => {
    setIsDragging(false);
  };

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      const file = e.dataTransfer.files[0];
      await handleUploadFile(file);
    }
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      const file = e.target.files[0];
      await handleUploadFile(file);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handleUploadFile = async (file: File) => {
    try {
      setIsUploading(true);
      const uploadTitle = title.trim() || file.name;
      await materialApi.uploadMaterial(uploadTitle, description, file);
      // 초기화
      setTitle('');
      setDescription('');
      // 새로고침
      await fetchMaterials();
    } catch (error) {
      console.error('Upload failed:', error);
      alert('업로드에 실패했습니다.');
    } finally {
      setIsUploading(false);
    }
  };

  const handleDelete = async (id: number) => {
    if (!window.confirm('정말 삭제하시겠습니까?')) return;
    try {
      await materialApi.deleteMaterial(id);
      await fetchMaterials();
    } catch (error) {
      console.error('Delete failed:', error);
      alert('삭제에 실패했습니다.');
    }
  };

  const handleDownload = async (url: string, filename: string) => {
    try {
      const response = await fetch(`http://localhost:8000${url}`);
      const blob = await response.blob();
      const objectUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = objectUrl;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(objectUrl);
    } catch (error) {
      console.error("Download failed", error);
    }
  };

  const getFileIcon = (type: string) => {
    const t = type.toLowerCase();
    if (['pdf'].includes(t)) return 'picture_as_pdf';
    if (['xls', 'xlsx', 'csv'].includes(t)) return 'table_chart';
    if (['ppt', 'pptx'].includes(t)) return 'slideshow';
    if (['jpg', 'jpeg', 'png', 'gif'].includes(t)) return 'image';
    if (['mp4', 'avi', 'mkv'].includes(t)) return 'video_file';
    if (['zip', 'rar', 'tar', 'gz'].includes(t)) return 'folder_zip';
    if (['py', 'js', 'ts', 'html', 'css', 'json'].includes(t)) return 'code';
    return 'insert_drive_file';
  };

  const formatFileSize = (bytes: number) => {
    if (!bytes) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  // fallback user (for layout rendering if missing)
  const currentUser = user || {
    id: 'unknown',
    name: 'Unknown',
    email: '',
    role: 'instructor',
    avatar: ''
  };

  return (
    <DesktopLayout
      brandTitle="EduAI"
      brandSubtitle="Instructor Portal"
      menuItems={instructorMenuItems}
      user={currentUser}
      showFooterLinks={true}
      headerTitle="강의 자료 관리"
      headerAction="새 자료 업로드"
      headerActionIcon="cloud_upload"
      onHeaderAction={() => fileInputRef.current?.click()}
    >
      <div className="instructor-grid">
        {/* 업로드 폼 영역 */}
        <div className="col-12">
          <Card compact>
            <div style={{ padding: '20px' }}>
              <div style={{ marginBottom: '16px', display: 'flex', gap: '16px' }}>
                <div style={{ flex: 1 }}>
                  <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, color: 'var(--color-text-secondary)', marginBottom: '8px' }}>
                    자료 제목 (선택사항)
                  </label>
                  <input 
                    type="text" 
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="입력하지 않으면 파일명으로 자동 지정됩니다."
                    style={{ width: '100%', padding: '10px 14px', borderRadius: '8px', border: '1px solid var(--color-border)', fontSize: '14px' }}
                  />
                </div>
                <div style={{ flex: 1 }}>
                  <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, color: 'var(--color-text-secondary)', marginBottom: '8px' }}>
                    자료 설명 (선택사항)
                  </label>
                  <input 
                    type="text" 
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="자료에 대한 간단한 설명을 입력하세요."
                    style={{ width: '100%', padding: '10px 14px', borderRadius: '8px', border: '1px solid var(--color-border)', fontSize: '14px' }}
                  />
                </div>
              </div>
              
              <div 
                className={`upload-dropzone ${isDragging ? 'upload-dropzone--active' : ''}`}
                onDragOver={handleDragOver}
                onDragLeave={handleDragLeave}
                onDrop={handleDrop}
                onClick={() => fileInputRef.current?.click()}
                style={{ cursor: 'pointer', marginTop: 0 }}
              >
                <div className="upload-dropzone__content">
                  <span className="material-icons-outlined upload-dropzone__icon">cloud_upload</span>
                  <h3 className="upload-dropzone__title">강의 자료 업로드</h3>
                  <p className="upload-dropzone__subtitle">
                    {isUploading ? '업로드 중...' : '파일을 이곳으로 드래그하거나 클릭하여 업로드하세요 (모든 포맷 지원)'}
                  </p>
                  <input 
                    type="file" 
                    ref={fileInputRef} 
                    style={{ display: 'none' }} 
                    onChange={handleFileSelect}
                  />
                </div>
              </div>
            </div>
          </Card>
        </div>

        {/* 강의 자료 리스트 테이블 */}
        <div className="col-12" style={{ marginTop: 'var(--space-6)' }}>
          <div className="section-header">
            <h2 className="section-title">업로드된 자료 목록</h2>
            <div className="search-bar">
              <span className="material-icons-outlined">search</span>
              <input type="text" placeholder="자료명 검색..." />
            </div>
          </div>
          
          <Card compact style={{ padding: 0 }}>
            {loading ? (
              <div style={{ padding: '20px', textAlign: 'center', color: 'var(--color-text-secondary)' }}>로딩 중...</div>
            ) : materials.length === 0 ? (
              <div style={{ padding: '20px', textAlign: 'center', color: 'var(--color-text-secondary)' }}>업로드된 자료가 없습니다.</div>
            ) : (
              <div className="table-responsive">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>자료명</th>
                      <th>설명</th>
                      <th>용량</th>
                      <th>업로드 일시</th>
                      <th style={{ textAlign: 'right' }}>관리</th>
                    </tr>
                  </thead>
                  <tbody>
                    {materials.map(mat => (
                      <tr key={mat.id}>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                            <span className="material-icons-outlined" style={{ color: 'var(--color-indigo)' }}>
                              {getFileIcon(mat.file_type || '')}
                            </span>
                            <span style={{ fontWeight: 500, color: 'var(--color-text-primary)' }}>{mat.title}</span>
                          </div>
                        </td>
                        <td style={{ color: 'var(--color-text-secondary)' }}>{mat.description}</td>
                        <td style={{ color: 'var(--color-text-tertiary)' }}>{formatFileSize(mat.file_size)}</td>
                        <td style={{ color: 'var(--color-text-tertiary)' }}>{mat.created_at ? new Date(mat.created_at).toLocaleDateString() : 'N/A'}</td>
                        <td style={{ textAlign: 'right' }}>
                          <button 
                            className="btn-icon" 
                            title="다운로드" 
                            style={{ color: 'var(--color-success)' }}
                            onClick={() => handleDownload(mat.file_url, mat.file_name)}
                          >
                            <span className="material-icons-outlined">download</span>
                          </button>
                          <button 
                            className="btn-icon" 
                            title="삭제" 
                            style={{ color: 'var(--color-danger)' }}
                            onClick={() => handleDelete(mat.id)}
                          >
                            <span className="material-icons-outlined">delete_outline</span>
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </div>
      </div>
    </DesktopLayout>
  );
}
