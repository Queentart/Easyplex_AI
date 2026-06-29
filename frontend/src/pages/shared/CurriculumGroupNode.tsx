import { useState } from 'react';
import { NodeResizer } from '@xyflow/react';

export interface CurriculumGroupNodeData {
  title: string;
  color: string;
  onChangeColor?: (id: string, color: string) => void;
  onEditTitle?: (id: string, title: string) => void;
}

interface CurriculumGroupNodeProps {
  id: string;
  data: CurriculumGroupNodeData;
  selected: boolean;
}

const COLORS = [
  'rgba(129, 140, 248, 0.08)', // Indigo
  'rgba(248, 113, 113, 0.08)', // Red
  'rgba(52, 211, 153, 0.08)',  // Emerald
  'rgba(251, 191, 36, 0.08)',  // Amber
  'rgba(167, 139, 250, 0.08)', // Violet
];

const BORDER_COLORS = {
  'rgba(129, 140, 248, 0.08)': 'border-indigo-500/40',
  'rgba(248, 113, 113, 0.08)': 'border-red-500/40',
  'rgba(52, 211, 153, 0.08)': 'border-emerald-500/40',
  'rgba(251, 191, 36, 0.08)': 'border-amber-500/40',
  'rgba(167, 139, 250, 0.08)': 'border-violet-500/40',
};

export default function CurriculumGroupNode({ id, data, selected }: CurriculumGroupNodeProps) {
  const [showColorPicker, setShowColorPicker] = useState(false);

  const handleTitleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (data.onEditTitle) {
      data.onEditTitle(id, e.target.value);
    }
  };

  const handleColorChange = (color: string) => {
    if (data.onChangeColor) {
      data.onChangeColor(id, color);
    }
    setShowColorPicker(false);
  };

  const bgColor = data.color || COLORS[0];
  const borderColor = BORDER_COLORS[bgColor as keyof typeof BORDER_COLORS] || 'border-indigo-500/40';

  return (
    <div 
      className={`w-full h-full rounded-2xl border-2 ${borderColor} transition-colors duration-200`}
      style={{ backgroundColor: bgColor }}
    >
      <NodeResizer 
        color="#818CF8" 
        isVisible={selected} 
        minWidth={300} 
        minHeight={200} 
      />
      
      <div className="w-full flex items-center justify-between px-4 py-2 border-b border-white/5 rounded-t-2xl bg-black/10">
        <input 
          type="text" 
          value={data.title}
          onChange={handleTitleChange}
          className="bg-transparent text-gray-200 font-bold text-lg outline-none placeholder-gray-500 w-full"
          placeholder="섹션 이름"
        />
        
        <div className="relative">
          <button 
            className="p-1.5 hover:bg-white/10 rounded-lg text-gray-400 hover:text-white transition-colors"
            onClick={() => setShowColorPicker(!showColorPicker)}
            title="색상 변경"
          >
            <span className="material-icons-outlined text-sm">palette</span>
          </button>
          
          {showColorPicker && (
            <div className="absolute top-10 right-0 bg-[#1a1a1f] p-2 rounded-lg border border-[#3d3d4d] shadow-2xl flex gap-2 z-50">
              {COLORS.map(c => (
                <button
                  key={c}
                  className={`w-6 h-6 rounded-full border-2 ${data.color === c ? 'border-white' : 'border-transparent'} hover:scale-110 transition-transform`}
                  style={{ backgroundColor: c.replace('0.08', '0.5') }}
                  onClick={() => handleColorChange(c)}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
