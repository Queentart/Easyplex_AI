/* ==========================================================
 * Table 컴포넌트
 * ----------------------------------------------------------
 * 데이터 테이블을 렌더링하는 범용 컴포넌트.
 *
 * [주요 기능]
 * - 헤더 + 행 데이터 렌더링
 * - 커스텀 셀 렌더러 지원
 * - 페이지네이션 (선택)
 * - 인라인 모드 (채팅 메시지 내 테이블)
 *
 * [사용처]
 * - 학생 목록 테이블, 출석 교차검증 테이블
 * - 테넌트 계약 테이블, ROI 분석 테이블
 * - AI 채팅 응답 내 인라인 테이블
 * ========================================================== */

import type { ReactNode } from 'react';
import './Table.css';

interface TableColumn {
  /** 컬럼 키 (데이터 접근용) */
  key: string;
  /** 헤더 표시 텍스트 */
  header: string;
  /** 커스텀 셀 렌더러 */
  render?: (value: string, row: Record<string, string>, rowIndex: number) => ReactNode;
}

interface DataTableProps {
  /** 컬럼 정의 목록 */
  columns: TableColumn[];
  /** 행 데이터 (key-value 맵 배열) */
  data: Record<string, string>[];
  /** 인라인 모드 (채팅 내 테이블) */
  inline?: boolean;
  /** 페이지네이션 표시 여부 */
  showPagination?: boolean;
  /** 현재 페이지 */
  currentPage?: number;
  /** 총 페이지 수 */
  totalPages?: number;
  /** 페이지 변경 핸들러 */
  onPageChange?: (page: number) => void;
}

/**
 * DataTable 컴포넌트
 * 
 * 구조화된 데이터를 테이블 형태로 표시합니다.
 * 컬럼별 커스텀 렌더러를 지원하여 StatusTag, 버튼 등을 셀에 삽입할 수 있습니다.
 */
export default function DataTable({
  columns,
  data,
  inline = false,
  showPagination = false,
  currentPage = 1,
  totalPages = 1,
  onPageChange,
}: DataTableProps) {
  return (
    <div className={inline ? 'inline-table' : 'table-wrapper'}>
      <table className="data-table">
        <thead>
          <tr>
            {columns.map(col => (
              <th key={col.key}>{col.header}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.map((row, rowIndex) => (
            <tr key={rowIndex}>
              {columns.map(col => (
                <td key={col.key}>
                  {col.render
                    ? col.render(row[col.key], row, rowIndex)
                    : row[col.key]
                  }
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>

      {/* 페이지네이션 */}
      {showPagination && totalPages > 1 && (
        <div className="table-pagination">
          <button
            className="table-pagination__btn"
            disabled={currentPage <= 1}
            onClick={() => onPageChange?.(currentPage - 1)}
          >
            Prev
          </button>
          {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => (
            <button
              key={page}
              className={`table-pagination__btn ${page === currentPage ? 'table-pagination__btn--active' : ''}`}
              onClick={() => onPageChange?.(page)}
            >
              {page}
            </button>
          ))}
          <button
            className="table-pagination__btn"
            disabled={currentPage >= totalPages}
            onClick={() => onPageChange?.(currentPage + 1)}
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}

/* ── SimpleTable: 단순 문자열 배열 기반 테이블 (채팅 내) ── */

interface SimpleTableProps {
  /** 헤더 문자열 배열 */
  headers: string[];
  /** 행 데이터 (2D 문자열 배열) */
  rows: string[][];
}

/**
 * SimpleTable 컴포넌트
 * 
 * 채팅 메시지 내에서 간단한 테이블을 표시할 때 사용합니다.
 * headers/rows를 문자열 배열로 받아 인라인 테이블을 렌더링합니다.
 */
export function SimpleTable({ headers, rows }: SimpleTableProps) {
  return (
    <div className="inline-table">
      <table className="data-table">
        <thead>
          <tr>
            {headers.map((h, i) => (
              <th key={i}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, ri) => (
            <tr key={ri}>
              {row.map((cell, ci) => (
                <td key={ci}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
