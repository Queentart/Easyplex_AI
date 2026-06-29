/* ==========================================================
 * Toggle 컴포넌트
 * ----------------------------------------------------------
 * ON/OFF 토글 스위치 컴포넌트.
 * 설정 페이지에서 각종 옵션을 활성/비활성화할 때 사용됩니다.
 *
 * [사용처]
 * - 보안 설정 (Data Isolation, 2FA 등)
 * - 학생 설정 (알림, 다크모드 등)
 * - 운영 설정 (Auto-sync, Push Notifications 등)
 * ========================================================== */

import './CommonComponents.css';

interface ToggleProps {
  /** 토글 라벨 텍스트 */
  label: string;
  /** 현재 값 */
  checked: boolean;
  /** 값 변경 핸들러 */
  onChange: (checked: boolean) => void;
  /** 비활성화 여부 */
  disabled?: boolean;
}

/**
 * Toggle 컴포넌트
 * 
 * iOS 스타일의 토글 스위치입니다.
 * checked 상태에 따라 슬라이더가 좌우로 이동합니다.
 */
export default function Toggle({ label, checked, onChange, disabled = false }: ToggleProps) {
  return (
    <div className="toggle">
      <span className="toggle__label">{label}</span>
      <label className="toggle__switch">
        <input
          type="checkbox"
          checked={checked}
          onChange={(e) => onChange(e.target.checked)}
          disabled={disabled}
        />
        <span className="toggle__slider" />
      </label>
    </div>
  );
}
