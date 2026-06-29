import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import type { UserRole } from '../../types';

interface ProtectedRouteProps {
  children: React.ReactNode;
  allowedRoles?: UserRole[];
}

export default function ProtectedRoute({ children, allowedRoles }: ProtectedRouteProps) {
  const { isAuthenticated, isLoading, user } = useAuth();
  const location = useLocation();

  if (isLoading) {
    // 로딩 중일 때는 로딩 스피너 등을 표시할 수 있음
    return (
      <div className="flex items-center justify-center h-screen w-screen bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!isAuthenticated || !user) {
    // 인증되지 않은 사용자는 웰컴(로그인 게이트웨이) 페이지로 리다이렉트
    return <Navigate to="/" state={{ from: location }} replace />;
  }

  if (allowedRoles && allowedRoles.length > 0 && !allowedRoles.includes(user.role)) {
    // 권한이 없는 경우 권한 없음 페이지 또는 적절한 대시보드로 리다이렉트
    // (여기서는 일단 메인으로 돌려보냄)
    return <Navigate to="/" replace />;
  }

  return <>{children}</>;
}
