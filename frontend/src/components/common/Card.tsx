/* ==========================================================
 * Card 컴포넌트
 * ----------------------------------------------------------
 * 대시보드에서 사용되는 범용 카드 컴포넌트.
 * 제목, 부제목, 아이콘, 값, 트렌드, 액션을 지원합니다.
 *
 * [사용처]
 * - KPI 카드 (값 + 트렌드 표시)
 * - 정보 카드 (제목 + 내용)
 * - 액션 카드 (버튼 포함)
 * ========================================================== */

import './CommonComponents.css';

interface CardProps {
  /** 카드 제목 */
  title?: string;
  /** 카드 라벨 (대문자 작은 텍스트) */
  label?: string;
  /** 카드 부제목 */
  subtitle?: string;
  /** 제목 앞 Material Icon 이름 */
  titleIcon?: string;
  /** 큰 값 텍스트 */
  value?: string;
  /** 값 색상을 primary로 설정 */
  valuePrimary?: boolean;
  /** 트렌드 방향 */
  trend?: 'up' | 'down' | 'neutral';
  /** 트렌드 값 텍스트 */
  trendValue?: string;
  /** 컴팩트 모드 */
  compact?: boolean;
  /** flat 스타일 (보더 없음) */
  flat?: boolean;
  /** 자식 콘텐츠 */
  children?: React.ReactNode;
  /** 추가 CSS 클래스 */
  className?: string;
  /** 추가 인라인 스타일 */
  style?: React.CSSProperties;
  /** 우측 상단 액션 엘리먼트 (버튼 등) */
  action?: React.ReactNode;
}

/**
 * Card 컴포넌트
 * 
 * 다양한 유형의 정보를 카드 형태로 표시합니다.
 * 제목, 큰 숫자 값, 트렌드 화살표, 커스텀 콘텐츠를 지원합니다.
 */
export default function Card({
  title,
  label,
  subtitle,
  titleIcon,
  value,
  valuePrimary = false,
  trend,
  trendValue,
  compact = false,
  flat = false,
  children,
  className = '',
  style,
  action,
}: CardProps) {
  return (
    <div className={`card ${compact ? 'card--compact' : ''} ${flat ? 'card--flat' : ''} ${className}`} style={style}>
      {/* 라벨 (대문자 작은 텍스트) */}
      {label && <div className="card__label">{label}</div>}

      {/* 헤더: 제목 + 아이콘 + 액션 */}
      {(title || action) && (
        <div className="card__header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            {title && (
              <div className="card__title">
                {titleIcon && (
                  <span className="material-icons-outlined card__title-icon">{titleIcon}</span>
                )}
                {title}
              </div>
            )}
            {subtitle && <div className="card__subtitle">{subtitle}</div>}
          </div>
          {action && <div className="card__action">{action}</div>}
        </div>
      )}

      {/* 큰 값 */}
      {value && (
        <div className={`card__value ${valuePrimary ? 'card__value--primary' : ''}`}>
          {value}
          {/* 트렌드 표시 */}
          {trend && (
            <span className={`card__trend card__trend--${trend}`} style={{ marginLeft: 8 }}>
              <span className="material-icons" style={{ fontSize: 16 }}>
                {trend === 'up' ? 'trending_up' : trend === 'down' ? 'trending_down' : 'trending_flat'}
              </span>
              {trendValue}
            </span>
          )}
        </div>
      )}

      {/* 커스텀 콘텐츠 */}
      {children}
    </div>
  );
}
