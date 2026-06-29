/* ==========================================================
 * BarChart 컴포넌트
 * ----------------------------------------------------------
 * CSS 기반 바 차트. 외부 라이브러리 없이 구현.
 *
 * [사용처]
 * - 수익성 & 활용 트렌드 차트 (Revenue vs OpEx)
 * - Q3 Financial vs Capacity Metrics
 * ========================================================== */

import type { BarChartData } from '../../types';
import './Charts.css';

interface BarChartProps {
  /** 차트 데이터 그룹 배열 */
  data: BarChartData[];
  /** 차트 높이 (px) */
  height?: number;
}

/**
 * BarChart 컴포넌트
 * 
 * CSS로 구현된 수직 바 차트입니다.
 * 그룹당 여러 바를 지원하며 범례를 자동 생성합니다.
 */
export default function BarChart({ data, height = 180 }: BarChartProps) {
  /** 모든 값 중 최대값 (높이 비율 계산용) */
  const maxValue = Math.max(...data.flatMap(g => g.values.map(v => v.value)));

  /** 범례 추출 (첫 번째 그룹 기준) */
  const legendItems = data[0]?.values.map(v => ({ label: v.label, color: v.color })) || [];

  return (
    <div>
      <div className="bar-chart" style={{ height }}>
        {data.map((group, gi) => (
          <div key={gi} className="bar-chart__group">
            <div className="bar-chart__bars">
              {group.values.map((bar, bi) => (
                <div
                  key={bi}
                  className="bar-chart__bar"
                  style={{
                    height: `${(bar.value / maxValue) * (height - 40)}px`,
                    background: bar.color,
                  }}
                  title={`${bar.label}: ${bar.value}`}
                />
              ))}
            </div>
            <span className="bar-chart__label">{group.label}</span>
          </div>
        ))}
      </div>

      {/* 범례 */}
      <div className="bar-chart__legend">
        {legendItems.map((item, i) => (
          <div key={i} className="bar-chart__legend-item">
            <span className="bar-chart__legend-dot" style={{ background: item.color }} />
            {item.label}
          </div>
        ))}
      </div>
    </div>
  );
}
