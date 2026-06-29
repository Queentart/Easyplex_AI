/* ==========================================================
 * main.tsx - 앱 엔트리포인트
 * ----------------------------------------------------------
 * React 앱을 DOM에 마운트하는 진입점입니다.
 * 글로벌 CSS를 import하고 StrictMode로 App을 렌더링합니다.
 * ========================================================== */

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { AuthProvider } from './contexts/AuthContext.tsx'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const queryClient = new QueryClient()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <App />
      </AuthProvider>
    </QueryClientProvider>
  </StrictMode>,
)