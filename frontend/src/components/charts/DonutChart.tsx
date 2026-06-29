/* ==========================================================
 * DonutChart 컴포넌트
 * ----------------------------------------------------------
 * SVG 기반 도넛 차트. 외부 라이브러리 없이 구현.
 *
 * [사용처]
 * - Global Dropout Risk Level (3.2% RISK)
 * ========================================================== */

import './Charts.css';

interface DonutChartProps {
  /** 현재 값 */
  value: number;
  /** 최대 값 */
  max: number;
  /** 중앙 라벨 */
  label: string;
  /** 차트 색상 */
  color?: string;
  /** 차트 크기 (px) */
  size?: number;
  /** 두께 (px) */
  strokeWidth?: number;
}

/**
 * DonutChart 컴포넌트
 * 
 * SVG를 사용한 도넛(링) 차트입니다.
 * 중앙에 값과 라벨을 표시합니다.
 */
export default function DonutChart({
  value,
  max,
  label,
  color = 'var(--color-primary)',
  size = 140,
  strokeWidth = 12,
}: DonutChartProps) {
  /** SVG 원의 반지름 및 둘레 계산 */
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;

  /** 채움 비율에 따른 dashoffset 계산 */
  const percent = Math.min(value / max, 1);
  const dashoffset = circumference * (1 - percent);

  return (
    <div className="donut-chart" style={{ width: size, height: size }}>
      {/* SVG 도넛 */}
      <svg className="donut-chart__svg" width={size} height={size}>
        {/* 배경 원 */}
        <circle
          className="donut-chart__bg"
          cx={size / 2}
          cy={size / 2}
          r={radius}
          strokeWidth={strokeWidth}
        />
        {/* 채움 원 */}
        <circle
          className="donut-chart__fill"
          cx={size / 2}
          cy={size / 2}
          r={radius}
          strokeWidth={strokeWidth}
          stroke={color}
          strokeDasharray={circumference}
          strokeDashoffset={dashoffset}
        />
      </svg>

      {/* 중앙 텍스트 */}
      <div className="donut-chart__center">
        <span className="donut-chart__value">{value}%</span>
        <span className="donut-chart__label">{label}</span>
      </div>
    </div>
  );
}
