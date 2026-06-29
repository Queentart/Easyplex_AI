/* ==========================================================
 * StatusTag 컴포넌트
 * ----------------------------------------------------------
 * 상태를 시각적으로 표시하는 태그/뱃지 컴포넌트.
 *
 * [지원 variant]
 * active, success, warning, danger, info, neutral,
 * matched, mismatch, question, freetalk, studygroup,
 * high, medium, low
 * ========================================================== */

import './CommonComponents.css';

interface StatusTagProps {
  /** 표시 텍스트 */
  label: string;
  /** 색상 variant */
  variant: string;
  /** Material Icon 이름 (선택) */
  icon?: string;
}

/**
 * StatusTag 컴포넌트
 * 
 * Active, Warning, Matched 등의 상태를 색상으로 구분하여 표시합니다.
 * 테이블 셀, 카드, 목록 아이템 등에서 사용됩니다.
 */
export default function StatusTag({ label, variant, icon }: StatusTagProps) {
  return (
    <span className={`status-tag status-tag--${variant}`}>
      {icon && (
        <span className="material-icons-outlined" style={{ fontSize: 14 }}>
          {icon}
        </span>
      )}
      {label}
    </span>
  );
}
