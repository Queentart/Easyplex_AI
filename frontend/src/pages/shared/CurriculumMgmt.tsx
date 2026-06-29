import { useState, useEffect } from 'react';
import DesktopLayout from '../../components/layout/DesktopLayout';
import { curriculumApi } from '../../api/curriculumApi';
import type { CurriculumStep } from '../../api/curriculumApi';
import type { MenuItem, User } from '../../types';
import InstructorCurriculumNodeEditor from './InstructorCurriculumNodeEditor';
import { useRef } from 'react';

interface CurriculumMgmtProps {
  brandTitle: string;
  brandSubtitle: string;
  menuItems: MenuItem[];
  user: User;
  logoutLabel: string;
}

export default function CurriculumMgmt({
  brandTitle,
  brandSubtitle,
  menuItems,
  user,
  logoutLabel
}: CurriculumMgmtProps) {
  const [steps, setSteps] = useState<CurriculumStep[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // 폼 상태
  const [isEditing, setIsEditing] = useState(false);
  const [currentStep, setCurrentStep] = useState<Partial<CurriculumStep>>({});

  const fetchSteps = async () => {
    try {
      const data = await curriculumApi.getCurriculumSteps();
      setSteps(data);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to load curriculum steps');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    // eslint-disable-next-line
    fetchSteps();
  }, []);

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    try {
      setUploading(true);
      setError(null);
      const parsedSteps = await curriculumApi.uploadCurriculumDocument(file);
      // 기존 목록 뒤에 추가 (임시 상태)
      setSteps(prev => [...prev, ...parsedSteps]);
      alert('문서가 성공적으로 분석되었습니다. 아래 목록을 검토하고 저장하세요.');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : '파일 파싱 실패');
    } finally {
      setUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const handleSaveBatch = async (updatedSteps: Partial<CurriculumStep>[]) => {
    try {
      setLoading(true);
      // id가 없는 항목은 생성, id가 있으면 업데이트 (하지만 batch API는 생성만 처리하도록 만들었음)
      // 따라서 id가 없는 신규 항목만 batch 로 생성하고, 위치 갱신은 기존 로직으로 처리해야 할 수 있음.
      // 백엔드의 batch API는 모든 걸 새로 create 하므로, 기존 걸 전부 삭제하고 재생성할지 아니면 update/create를 섞을지가 문제.
      // Instructor용 배치 저장은 개별 항목들의 display_order만 갱신.
      await Promise.all(updatedSteps.map(step => {
        if (step.id) {
          return curriculumApi.updateCurriculumStep(step.id, step);
        } else {
          return curriculumApi.createCurriculumStep({
            title: step.title || 'Untitled',
            status: step.status || 'upcoming',
            starts_date: step.starts_date,
            completed_date: step.completed_date,
            progress: step.progress,
            display_order: step.display_order
          });
        }
      }));
      fetchSteps();
    } catch (err) {
      alert("저장 실패: " + (err instanceof Error ? err.message : String(err)));
    } finally {
      setLoading(false);
    }
  };

  const handleSaveAll = async () => {
    // EduOps 에서 파싱된 임시 항목 저장 
    const newSteps = steps.filter(s => !s.id);
    if (newSteps.length > 0) {
      try {
        setLoading(true);
        await curriculumApi.createCurriculumStepsBatch(newSteps);
        alert('새 커리큘럼 항목들이 저장되었습니다.');
        fetchSteps();
      } catch (err) {
        alert("일괄 저장 실패: " + (err instanceof Error ? err.message : String(err)));
        setLoading(false);
      }
    } else {
      alert('새로 저장할 항목이 없습니다.');
    }
  };

  const handleSave = async () => {
    try {
      if (!currentStep.title) {
        alert("타이틀을 입력해주세요.");
        return;
      }
      
      const payload = {
        title: currentStep.title,
        status: currentStep.status || 'upcoming',
        progress: currentStep.progress,
        completed_date: currentStep.completed_date,
        starts_date: currentStep.starts_date,
        display_order: currentStep.display_order || 0
      };

      if (currentStep.id) {
        await curriculumApi.updateCurriculumStep(currentStep.id, payload);
      } else {
        await curriculumApi.createCurriculumStep(payload);
      }
      setIsEditing(false);
      setCurrentStep({});
      fetchSteps();
    } catch (err: unknown) {
      alert("저장 실패: " + (err instanceof Error ? err.message : String(err)));
    }
  };

  const handleDelete = async (id: number) => {
    if (window.confirm("정말 삭제하시겠습니까?")) {
      try {
        await curriculumApi.deleteCurriculumStep(id);
        fetchSteps();
      } catch (err: unknown) {
        alert("삭제 실패: " + (err instanceof Error ? err.message : String(err)));
      }
    }
  };

  return (
    <DesktopLayout
      brandTitle={brandTitle}
      brandSubtitle={brandSubtitle}
      menuItems={menuItems}
      user={user}
      logoutLabel={logoutLabel}
    >
      <div className="p-6 md:p-10 w-full max-w-[1600px] mx-auto">
        <div className="flex flex-col md:flex-row md:justify-between md:items-end gap-6 mb-8">
          <div>
            <h1 className="text-3xl md:text-4xl font-extrabold text-transparent bg-clip-text bg-linear-to-r from-teal-600 to-emerald-600 tracking-tight leading-tight">
              학습 커리큘럼 로드맵 관리
            </h1>
            <p className="text-sm md:text-base text-gray-500 mt-2 font-medium">
              수강생들에게 제공되는 공식 커리큘럼 로드맵을 AI를 통해 스마트하게 관리하세요.
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <button 
              onClick={() => {
                setCurrentStep({ status: 'upcoming', display_order: steps.length + 1 });
                setIsEditing(true);
              }}
              className="flex items-center gap-2 px-5 py-2.5 bg-white border border-gray-200 text-gray-700 rounded-xl text-sm font-bold hover:bg-gray-50 hover:border-gray-300 transition-all shadow-sm"
            >
              <span className="material-icons-outlined text-xl">add</span>
              수동 단계 추가
            </button>
            {steps.filter(s => !s.id).length > 0 && (
              <button 
                onClick={handleSaveAll}
                className="flex items-center gap-2 px-5 py-2.5 bg-linear-to-r from-emerald-500 to-teal-600 text-white rounded-xl text-sm font-bold hover:from-emerald-600 hover:to-teal-700 transition-all shadow-md shadow-teal-500/30"
              >
                <span className="material-icons-outlined text-xl">save</span>
                새 항목 일괄 저장
              </button>
            )}
          </div>
        </div>

        {error && (
          <div className="bg-red-50 text-red-600 p-4 rounded-xl mb-6 border border-red-100 flex items-start gap-3 shadow-sm">
            <span className="material-icons-outlined text-xl">error_outline</span>
            <div>
              <h4 className="font-bold">오류 발생</h4>
              <p className="text-sm mt-0.5">{error}</p>
            </div>
          </div>
        )}

        {(user.role === 'ops' || user.role === 'owner') && (
          <div className="mb-10 w-full">
            <input 
              type="file" 
              accept=".pdf, .xlsx, .xls" 
              className="hidden" 
              ref={fileInputRef}
              onChange={handleFileUpload}
            />
            <div 
              onClick={() => !uploading && fileInputRef.current?.click()}
              className={`relative overflow-hidden group cursor-pointer border-2 border-dashed rounded-3xl p-8 md:p-14 transition-all duration-300 w-full ${
                uploading 
                  ? 'border-teal-400 bg-teal-50/50' 
                  : 'border-gray-300 bg-white hover:border-teal-500 hover:bg-teal-50/30 hover:shadow-xl hover:shadow-teal-500/10'
              }`}
            >
              {/* 장식용 배경 도형 */}
              <div className="absolute -top-10 -right-10 w-40 h-40 bg-linear-to-br from-teal-100 to-emerald-100 rounded-full blur-3xl opacity-50 group-hover:opacity-100 transition-opacity"></div>
              <div className="absolute -bottom-10 -left-10 w-40 h-40 bg-linear-to-tr from-cyan-100 to-teal-100 rounded-full blur-3xl opacity-50 group-hover:opacity-100 transition-opacity"></div>

              <div className="relative z-10 flex flex-col items-center justify-center text-center">
                {uploading ? (
                  <>
                    <div className="w-16 h-16 relative flex items-center justify-center mb-4">
                      <div className="absolute inset-0 border-4 border-teal-100 rounded-full"></div>
                      <div className="absolute inset-0 border-4 border-teal-500 rounded-full border-t-transparent animate-spin"></div>
                      <span className="material-icons-outlined text-teal-500 text-3xl">smart_toy</span>
                    </div>
                    <h3 className="text-xl md:text-2xl font-bold text-gray-800">AI가 문서를 분석하고 있습니다...</h3>
                    <p className="text-gray-500 mt-2 text-sm md:text-base max-w-md">
                      문서의 양에 따라 수십 초가 소요될 수 있습니다. AI 모델이 커리큘럼 구조를 추출 중입니다.
                    </p>
                  </>
                ) : (
                  <>
                    <div className="w-20 h-20 bg-teal-50 text-teal-600 rounded-2xl flex items-center justify-center mb-5 group-hover:scale-110 transition-transform shadow-inner border border-teal-100">
                      <span className="material-icons-outlined text-5xl">cloud_upload</span>
                    </div>
                    <h3 className="text-xl md:text-2xl font-extrabold text-gray-800">커리큘럼 문서 업로드 (PDF / Excel)</h3>
                    <p className="text-gray-500 mt-2 text-sm md:text-base max-w-md">
                      클릭하거나 파일을 이곳에 드롭하세요. <br/>
                      로컬 LLM이 문서를 자동으로 분석하여 커리큘럼 단계를 추출합니다.
                    </p>
                    <div className="mt-6 flex items-center gap-2 text-xs md:text-sm font-bold text-teal-600 bg-teal-50 px-4 py-2 rounded-full border border-teal-100">
                      <span className="material-icons-outlined text-lg">auto_awesome</span>
                      Powered by Local LLM
                    </div>
                  </>
                )}
              </div>
            </div>
          </div>
        )}

        {isEditing && (
          <div className="bg-white/80 backdrop-blur-xl p-8 rounded-3xl border border-gray-200 shadow-2xl mb-10 relative overflow-hidden">
            <div className="absolute top-0 left-0 w-2 h-full bg-linear-to-b from-teal-400 to-emerald-600"></div>
            <h2 className="text-xl font-extrabold mb-6 text-gray-800 flex items-center gap-2">
              <span className="material-icons-outlined text-teal-600">edit_note</span>
              {currentStep.id ? '커리큘럼 단계 수정' : '새 커리큘럼 단계 추가'}
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="md:col-span-2">
                <label className="block text-sm font-bold text-gray-700 mb-2">과목 / 단계명 (Title)</label>
                <input 
                  type="text" 
                  value={currentStep.title || ''}
                  onChange={(e) => setCurrentStep({...currentStep, title: e.target.value})}
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl outline-none focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20 transition-all text-gray-800 font-medium"
                  placeholder="예: 실전 데이터 분석 프로젝트"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">진행 상태 (Status)</label>
                <div className="relative">
                  <select 
                    value={currentStep.status || 'upcoming'}
                    onChange={(e) => setCurrentStep({...currentStep, status: e.target.value as CurriculumStep['status']})}
                    className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl outline-none focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20 transition-all appearance-none font-medium text-gray-700"
                  >
                    <option value="completed">완료 (Completed)</option>
                    <option value="current">진행중 (Current)</option>
                    <option value="upcoming">예정 (Upcoming)</option>
                  </select>
                  <span className="material-icons-outlined absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none">expand_more</span>
                </div>
              </div>
              
              {currentStep.status === 'completed' && (
                <div>
                  <label className="block text-sm font-bold text-gray-700 mb-2">완료일 (Completed Date)</label>
                  <input 
                    type="text" 
                    value={currentStep.completed_date || ''}
                    onChange={(e) => setCurrentStep({...currentStep, completed_date: e.target.value})}
                    className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl outline-none focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20 transition-all"
                    placeholder="예: 2026.09.15"
                  />
                </div>
              )}
              
              {currentStep.status === 'current' && (
                <div>
                  <label className="block text-sm font-bold text-gray-700 mb-2">진행률 (Progress %)</label>
                  <div className="relative">
                    <input 
                      type="number" 
                      min="0" max="100"
                      value={currentStep.progress || ''}
                      onChange={(e) => setCurrentStep({...currentStep, progress: parseInt(e.target.value)})}
                      className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl outline-none focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20 transition-all"
                      placeholder="예: 65"
                    />
                    <span className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 font-bold">%</span>
                  </div>
                </div>
              )}
              
              {currentStep.status === 'upcoming' && (
                <div>
                  <label className="block text-sm font-bold text-gray-700 mb-2">시작 예정일 (Starts Date)</label>
                  <input 
                    type="text" 
                    value={currentStep.starts_date || ''}
                    onChange={(e) => setCurrentStep({...currentStep, starts_date: e.target.value})}
                    className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl outline-none focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20 transition-all"
                    placeholder="예: 2026.10.01"
                  />
                </div>
              )}

              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">노출 순서 (Order)</label>
                <input 
                  type="number" 
                  value={currentStep.display_order ?? 0}
                  onChange={(e) => setCurrentStep({...currentStep, display_order: parseInt(e.target.value)})}
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl outline-none focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20 transition-all"
                />
              </div>
            </div>
            
            <div className="mt-8 flex justify-end gap-3 pt-6 border-t border-gray-100">
              <button 
                onClick={() => setIsEditing(false)}
                className="px-6 py-2.5 bg-white border border-gray-200 rounded-xl text-sm font-bold text-gray-600 hover:bg-gray-50 transition"
              >
                취소
              </button>
              <button 
                onClick={handleSave}
                className="px-6 py-2.5 bg-gray-900 text-white rounded-xl text-sm font-bold hover:bg-black transition shadow-lg shadow-gray-900/20"
              >
                저장하기
              </button>
            </div>
          </div>
        )}

        {loading && !steps.length ? (
          <div className="py-20 text-center">
            <div className="w-10 h-10 border-4 border-gray-200 border-t-teal-500 rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-gray-500 font-medium">커리큘럼 데이터를 불러오는 중입니다...</p>
          </div>
        ) : (user.role === 'instructor' || user.role === 'tutor') ? (
          <InstructorCurriculumNodeEditor steps={steps} onSaveBatch={handleSaveBatch} />
        ) : (
          <div className="space-y-4 relative">
            <div className="absolute left-6 top-4 bottom-4 w-0.5 bg-linear-to-b from-teal-200 to-gray-200 hidden md:block"></div>
            {steps.sort((a, b) => (a.display_order ?? 0) - (b.display_order ?? 0)).map((step, index) => (
              <div 
                key={step.id || `temp-${index}`} 
                className={`relative group bg-white rounded-2xl border transition-all duration-300 md:pl-16 p-5 sm:p-6 ${
                  !step.id 
                    ? 'border-orange-200 shadow-md shadow-orange-100/50 scale-[1.01] z-10' 
                    : 'border-gray-100 hover:border-gray-300 hover:shadow-lg'
                }`}
              >
                {/* Timeline Dot */}
                <div className="absolute left-6 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full bg-white border-4 border-teal-500 hidden md:block shadow-sm z-20 group-hover:scale-125 transition-transform"></div>
                
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <span className="text-2xl font-black text-gray-200 italic tracking-tighter w-8">{step.display_order}</span>
                      <h3 className="text-lg font-bold text-gray-900 flex items-center gap-2">
                        {step.title}
                        {!step.id && (
                          <span className="px-2 py-0.5 bg-orange-100 text-orange-600 text-[10px] uppercase font-black tracking-wider rounded-md animate-pulse">
                            New AI Draft
                          </span>
                        )}
                      </h3>
                    </div>
                    
                    <div className="flex flex-wrap items-center gap-3 md:pl-11">
                      <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-bold uppercase tracking-wide ${
                        step.status === 'completed' ? 'bg-emerald-50 text-emerald-700 border border-emerald-100' :
                        step.status === 'current' ? 'bg-blue-50 text-blue-700 border border-blue-100' :
                        'bg-gray-50 text-gray-600 border border-gray-200'
                      }`}>
                        {step.status === 'completed' && <span className="material-icons-outlined text-[14px]">check_circle</span>}
                        {step.status === 'current' && <span className="material-icons-outlined text-[14px]">play_circle</span>}
                        {step.status === 'upcoming' && <span className="material-icons-outlined text-[14px]">schedule</span>}
                        {step.status}
                      </span>
                      
                      <span className="text-sm font-medium text-gray-500 flex items-center gap-1">
                        {step.status === 'completed' && (
                          <><span className="material-icons-outlined text-[16px]">event_available</span> 완료일: {step.completed_date || '미정'}</>
                        )}
                        {step.status === 'current' && (
                          <><span className="material-icons-outlined text-[16px]">trending_up</span> 진행률: {step.progress || 0}%</>
                        )}
                        {step.status === 'upcoming' && (
                          <><span className="material-icons-outlined text-[16px]">event</span> 시작예정: {step.starts_date || '미정'}</>
                        )}
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 border-t border-gray-100 pt-4 md:pt-0 md:border-0">
                    <button 
                      onClick={() => {
                        setCurrentStep(step);
                        setIsEditing(true);
                      }}
                      className="p-2 text-gray-400 hover:text-teal-600 hover:bg-teal-50 rounded-lg transition-colors tooltip"
                      title="수정"
                    >
                      <span className="material-icons-outlined">edit</span>
                    </button>
                    {step.id ? (
                      <button 
                        onClick={() => handleDelete(step.id)}
                        className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors tooltip"
                        title="삭제"
                      >
                        <span className="material-icons-outlined">delete</span>
                      </button>
                    ) : (
                      <button 
                        onClick={() => {
                          setSteps(steps.filter(s => s !== step));
                        }}
                        className="p-2 text-orange-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors tooltip"
                        title="임시 항목 취소"
                      >
                        <span className="material-icons-outlined">close</span>
                      </button>
                    )}
                  </div>
                </div>
              </div>
            ))}
            
            {steps.length === 0 && (
              <div className="text-center py-20 bg-white border border-gray-200 rounded-3xl border-dashed">
                <span className="material-icons-outlined text-5xl text-gray-300 mb-3 block">assignment</span>
                <h3 className="text-lg font-bold text-gray-700">등록된 커리큘럼이 없습니다</h3>
                <p className="text-gray-500 mt-1 text-sm">상단의 업로드 버튼을 눌러 문서를 분석하거나 수동으로 단계를 추가하세요.</p>
              </div>
            )}
          </div>
        )}
      </div>
    </DesktopLayout>
  );
}
