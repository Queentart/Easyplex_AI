import { Handle, Position } from '@xyflow/react';
import { useState } from 'react';
import type { CurriculumStep } from '../../api/curriculumApi';

interface CurriculumCustomNodeProps {
  id: string;
  data: {
    label: string;
    stepData: CurriculumStep;
    color?: string;
    onEdit?: (id: string, currentData: CurriculumStep) => void;
    onDelete?: (id: string) => void;
    onChangeColor?: (id: string, color: string) => void;
  };
}

export default function CurriculumCustomNode({ id, data }: CurriculumCustomNodeProps) {
  const { stepData, onEdit, onDelete, onChangeColor, color } = data;
  const [showColorPicker, setShowColorPicker] = useState(false);
  
  const statusColors = {
    completed: 'bg-green-500',
    current: 'bg-blue-500',
    upcoming: 'bg-gray-400'
  };

  const statusBg = statusColors[stepData.status] || statusColors.upcoming;

  const COLORS = [
    'bg-slate-100', // Default light
    'bg-blue-100',
    'bg-emerald-100',
    'bg-purple-100',
    'bg-amber-100',
    'bg-rose-100',
  ];

  const BORDER_COLORS = {
    'bg-slate-100': 'border-slate-200',
    'bg-blue-100': 'border-blue-200',
    'bg-emerald-100': 'border-emerald-200',
    'bg-purple-100': 'border-purple-200',
    'bg-amber-100': 'border-amber-200',
    'bg-rose-100': 'border-rose-200',
  };

  const handleColorChange = (c: string) => {
    if (onChangeColor) onChangeColor(id, c);
    setShowColorPicker(false);
  };

  const headerBg = color || COLORS[0];
  const borderColor = BORDER_COLORS[headerBg as keyof typeof BORDER_COLORS] || 'border-slate-200';

  return (
    <div className={`min-w-[220px] bg-white text-slate-800 rounded-xl shadow-md border ${borderColor} overflow-hidden flex flex-col font-sans transition-colors duration-200`}>
      {/* Target Handle (입력) */}
      <Handle 
        type="target" 
        position={Position.Left} 
        className="w-3 h-3 bg-white border-2 border-indigo-400" 
        isConnectable={true}
      />

      {/* 노드 헤더 */}
      <div className={`flex items-center justify-between px-3 py-2 ${headerBg} border-b ${borderColor} group transition-colors duration-200`}>
        <div className="flex items-center gap-2">
          <div className={`w-2.5 h-2.5 rounded-full ${statusBg}`}></div>
          <h3 className="text-sm font-semibold truncate max-w-[120px]" title={stepData.title}>
            {stepData.title}
          </h3>
        </div>
        <div className="flex items-center gap-1">
          {/* 노드 상태 라벨 (기본 표시, 호버 시 숨김 처리 가능하거나 작게 유지) */}
          <span className="text-[9px] uppercase tracking-wider text-slate-500 font-bold bg-white/60 px-1 rounded block group-hover:hidden shadow-sm">
            {stepData.status}
          </span>
          {/* 액션 버튼 (호버 시 표시) */}
          <div className="hidden group-hover:flex items-center gap-1">
            <div className="relative">
              <button 
                className="p-1 hover:bg-black/5 rounded text-slate-400 hover:text-slate-700 transition-colors"
                onClick={() => setShowColorPicker(!showColorPicker)}
                title="색상 변경"
              >
                <span className="material-icons-outlined text-[14px]">palette</span>
              </button>
              
              {showColorPicker && (
                <div className="absolute top-8 right-0 bg-white p-2 rounded-lg border border-slate-200 shadow-xl flex gap-2 z-50 w-max">
                  {COLORS.map(c => (
                    <button
                      key={c}
                      className={`w-5 h-5 rounded-full border border-slate-300 hover:scale-110 transition-transform shadow-sm ${c}`}
                      onClick={() => handleColorChange(c)}
                    />
                  ))}
                </div>
              )}
            </div>
            <button 
              className="p-1 hover:bg-black/5 rounded text-slate-400 hover:text-slate-700 transition-colors"
              onClick={() => onEdit && onEdit(id, stepData)}
              title="노드 수정"
            >
              <span className="material-icons-outlined text-[14px]">edit</span>
            </button>
            <button 
              className="p-1 hover:bg-red-50 rounded text-slate-400 hover:text-red-500 transition-colors"
              onClick={() => onDelete && onDelete(id)}
              title="노드 삭제"
            >
              <span className="material-icons-outlined text-[14px]">delete</span>
            </button>
          </div>
        </div>
      </div>

      {/* 노드 바디 (상세 정보) */}
      <div className="px-3 py-3 flex flex-col gap-2">
        {stepData.status === 'completed' && (
          <div className="flex justify-between items-center text-xs">
            <span className="text-slate-500">Completed Date</span>
            <span className="text-slate-700 font-medium">{stepData.completed_date || '-'}</span>
          </div>
        )}
        
        {stepData.status === 'current' && (
          <div className="flex flex-col gap-1">
            <div className="flex justify-between items-center text-xs">
              <span className="text-slate-500">Progress</span>
              <span className="text-blue-600 font-semibold">{stepData.progress || 0}%</span>
            </div>
            <div className="w-full bg-slate-100 rounded-full h-1.5 mt-1 overflow-hidden border border-slate-200">
              <div 
                className="bg-blue-500 h-1.5 rounded-full" 
                style={{ width: `${stepData.progress || 0}%` }}
              ></div>
            </div>
          </div>
        )}

        {stepData.status === 'upcoming' && (
          <div className="flex justify-between items-center text-xs">
            <span className="text-slate-500">Starts</span>
            <span className="text-slate-700 font-medium">{stepData.starts_date || '-'}</span>
          </div>
        )}

        <div className="flex justify-between items-center text-[10px] text-slate-400 mt-1">
          <span>Order: {stepData.display_order}</span>
        </div>
      </div>

      {/* Source Handle (출력) */}
      <Handle 
        type="source" 
        position={Position.Right} 
        className="w-3 h-3 bg-white border-2 border-indigo-400" 
        isConnectable={true}
      />
    </div>
  );
}
