/* ==========================================================
 * ProgressBar 컴포넌트
 * ----------------------------------------------------------
 * 진행률을 시각적으로 표시하는 프로그레스 바 컴포넌트.
 *
 * [사용처]
 * - 코호트 배치별 취업률
 * - 출석률
 * - 강의 시청 진행률
 * - 토큰 사용량 (62% of quota)
 * ========================================================== */

import './CommonComponents.css';

interface ProgressBarProps {
  /** 현재 값 (0~100) */
  value: number;
  /** 최대 값 (기본: 100) */
  max?: number;
  /** 왼쪽 라벨 */
  label?: string;
  /** 오른쪽 서브 라벨 */
  sublabel?: string;
  /** 색상 variant */
  variant?: 'default' | 'success' | 'warning' | 'danger';
  /** 크기 */
  size?: 'sm' | 'md' | 'lg';
}

/**
 * ProgressBar 컴포넌트
 * 
 * 0~100% 범위의 진행 상태를 수평 바로 표시합니다.
 * variant에 따라 색상이 변경됩니다.
 */
export default function ProgressBar({
  value,
  max = 100,
  label,
  sublabel,
  variant = 'default',
  size = 'md',
}: ProgressBarProps) {
  /** 퍼센트 계산 (0~100 범위로 클램핑) */
  const percent = Math.min(Math.max((value / max) * 100, 0), 100);

  /** variant에 따른 CSS 클래스 결정 */
  const fillClass = variant !== 'default' ? `progress-bar__fill--${variant}` : '';

  return (
    <div className={`progress-bar progress-bar--${size}`}>
      <div className="progress-bar__track">
        <div
          className={`progress-bar__fill ${fillClass}`}
          style={{ width: `${percent}%` }}
        />
      </div>
      {(label || sublabel) && (
        <div className="progress-bar__label">
          <span>{label}</span>
          <span>{sublabel || `${Math.round(percent)}%`}</span>
        </div>
      )}
    </div>
  );
}
