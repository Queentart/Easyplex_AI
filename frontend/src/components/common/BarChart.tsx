/* ==========================================================
 * BarChart 컴포넌트
 * ----------------------------------------------------------
 * CSS 기반의 세로 막대 차트 컴포넌트.
 *
 * [사용처]
 * - 주차별 성적 추이
 * - 월별 비용/수익 비교
 * - 학습 참여도 트렌드
 * ========================================================== */

import './CommonComponents.css';

interface BarChartItem {
  label: string;
  score: number;
}

interface BarChartProps {
  /** 차트 데이터 배열 */
  data: BarChartItem[];
  /** 차트 높이 (px) */
  height?: number;
  /** Y축 라벨 */
  yAxisLabel?: string;
}

/**
 * BarChart 컴포넌트
 *
 * CSS 기반의 간단한 세로 막대 차트를 렌더링합니다.
 * 외부 라이브러리 의존 없이 구현되었습니다.
 */
export default function BarChart({ data, height = 250, yAxisLabel }: BarChartProps) {
  const maxScore = Math.max(...data.map(d => d.score), 1);

  return (
    <div className="bar-chart" style={{ height }}>
      {yAxisLabel && <div className="bar-chart__y-label">{yAxisLabel}</div>}
      <div className="bar-chart__container">
        {data.map((item, i) => {
          const barHeight = (item.score / maxScore) * 100;
          return (
            <div key={i} className="bar-chart__col">
              <div className="bar-chart__bar-wrapper">
                <span className="bar-chart__value">{item.score}</span>
                <div
                  className="bar-chart__bar"
                  style={{ height: `${barHeight}%` }}
                />
              </div>
              <span className="bar-chart__label">{item.label}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
