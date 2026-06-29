/* eslint-disable react-refresh/only-export-components */
import { createContext, useState, useEffect, useContext } from 'react';
import type { ReactNode } from 'react';
import { apiClient } from '../api/client';
import type { User } from '../types';

interface AuthContextType {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (token: string, userInfo: User) => void;
  logout: () => void;
}

export const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(localStorage.getItem('access_token'));
  const [isLoading, setIsLoading] = useState(true);

  // 컴포넌트 마운트 시 토큰이 있으면 사용자 정보를 가져옴
  useEffect(() => {
    const fetchUser = async () => {
      if (token) {
        try {
          const response = await apiClient.get('/auth/me');
          const data = response.data;
          setUser({
            ...data,
            name: data.name || data.full_name || 'Unknown'
          });

        } catch (error) {
          console.error('Failed to fetch user:', error);
          setToken(null);
          setUser(null);
          localStorage.removeItem('access_token');
        }
      }
      setIsLoading(false);
    };

    fetchUser();
  }, [token]);

  const login = (newToken: string, userInfo: User) => {
    localStorage.setItem('access_token', newToken);
    setToken(newToken);
    setUser(userInfo);
  };

  const logout = () => {
    localStorage.removeItem('access_token');
    setToken(null);
    setUser(null);
    // 선택: 로그아웃 후 로그인 페이지로 이동하는 로직 추가 가능
    window.location.href = '/'; // 또는 라우터 사용
  };

  return (
    <AuthContext.Provider value={{ user, token, isAuthenticated: !!user, isLoading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
