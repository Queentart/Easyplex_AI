import React, { useState, useRef } from 'react';

interface CreatePostModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (content: string, files: File[]) => void;
}

export default function CreatePostModal({ isOpen, onClose, onSubmit }: CreatePostModalProps) {
  const [content, setContent] = useState('');
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);

  if (!isOpen) return null;

  // 확장자 검증 (코드 파일 차단)
  const BLOCKED_EXTENSIONS = [
    '.js', '.ts', '.jsx', '.tsx', '.py', '.java', '.c', '.cpp', '.cs', 
    '.html', '.css', '.json', '.sh', '.bat', '.cmd', '.exe', '.php', '.rb', '.go', '.rs'
  ];

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      const filesArray = Array.from(e.target.files);
      const validFiles: File[] = [];
      const blockedFileNames: string[] = [];

      filesArray.forEach(file => {
        const fileName = file.name.toLowerCase();
        const isBlocked = BLOCKED_EXTENSIONS.some(ext => fileName.endsWith(ext));
        
        if (isBlocked) {
          blockedFileNames.push(file.name);
        } else {
          validFiles.push(file);
        }
      });

      if (blockedFileNames.length > 0) {
        alert(`보안 상의 이유로 코드 관련 파일은 업로드할 수 없습니다.\n차단된 파일: ${blockedFileNames.join(', ')}`);
      }

      setSelectedFiles(prev => [...prev, ...validFiles]);
    }
    // 동일한 파일 다시 선택 가능하도록 초기화
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const removeFile = (indexToRemove: number) => {
    setSelectedFiles(prev => prev.filter((_, idx) => idx !== indexToRemove));
  };

  const handleSubmit = () => {
    if (!content.trim() && selectedFiles.length === 0) {
      alert('내용을 입력하거나 파일을 첨부해주세요.');
      return;
    }
    onSubmit(content, selectedFiles);
    setContent('');
    setSelectedFiles([]);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 animate-[fadeIn_0.2s_ease-out]">
      <div className="bg-white w-full max-w-lg rounded-2xl shadow-2xl flex flex-col overflow-hidden animate-[scaleIn_0.2s_ease-out]">
        {/* 헤더 */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100">
          <h2 className="text-lg font-semibold text-gray-800">새 게시물 만들기</h2>
          <button onClick={onClose} className="p-1 rounded-full hover:bg-gray-100 transition text-gray-500">
            <span className="material-icons-outlined">close</span>
          </button>
        </div>

        {/* 본문 입력 영역 */}
        <div className="p-4 flex flex-col gap-3">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-full bg-teal-100 text-teal-600 flex items-center justify-center shrink-0 overflow-hidden">
              <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=이지" alt="Profile" className="w-full h-full object-cover" />
            </div>
            <div>
              <div className="font-semibold text-sm text-gray-800">김이지 (나)</div>
              <div className="text-xs text-gray-500">수강생</div>
            </div>
          </div>

          <textarea
            className="w-full min-h-[150px] resize-none border-none outline-none text-base text-gray-800 placeholder-gray-400"
            placeholder="동기들과 공유하고 싶은 내용이나 질문이 있나요?"
            value={content}
            onChange={(e) => setContent(e.target.value)}
          />

          {/* 첨부파일 목록 */}
          {selectedFiles.length > 0 && (
            <div className="flex flex-wrap gap-2 mt-2 max-h-[120px] overflow-y-auto p-2 bg-gray-50 rounded-lg border border-gray-100">
              {selectedFiles.map((file, idx) => (
                <div key={idx} className="flex items-center gap-1.5 bg-white border border-gray-200 rounded px-2 py-1 text-sm shadow-sm max-w-[200px]">
                  <span className="material-icons-outlined text-gray-400 text-[16px]">insert_drive_file</span>
                  <span className="truncate flex-1 text-gray-700 text-xs">{file.name}</span>
                  <button onClick={() => removeFile(idx)} className="text-gray-400 hover:text-red-500 flex items-center">
                    <span className="material-icons-outlined text-[14px]">close</span>
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* 하단 툴바 및 게시 버튼 */}
        <div className="px-4 py-3 flex items-center justify-between border-t border-gray-100 bg-gray-50/50">
          <div className="flex items-center gap-1 text-teal-600">
            <button 
              onClick={() => fileInputRef.current?.click()} 
              className="p-2 rounded-full hover:bg-teal-50 transition flex items-center justify-center"
              title="파일 첨부 (이미지, 동영상, 음원, 문서)"
            >
              <span className="material-icons-outlined">attach_file</span>
            </button>
            <input 
              type="file" 
              multiple 
              className="hidden" 
              ref={fileInputRef}
              onChange={handleFileChange}
              accept="image/*,video/*,audio/*,application/*,text/plain" 
            />
          </div>
          <button 
            className="bg-teal-600 hover:bg-teal-700 text-white font-semibold py-1.5 px-5 rounded-full transition shadow-sm disabled:opacity-50"
            onClick={handleSubmit}
            disabled={!content.trim() && selectedFiles.length === 0}
          >
            게시
          </button>
        </div>
      </div>
    </div>
  );
}
