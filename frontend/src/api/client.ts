import axios from 'axios';

// 백엔드 API 기본 URL (환경 변수 또는 기본값)
const baseURL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1';

export const apiClient = axios.create({
  baseURL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 요청 인터셉터: 로컬 스토리지에서 토큰을 가져와 헤더에 추가
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('access_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// 응답 인터셉터: 인증 에러 처리 등
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      // 권한 없음 에러 발생 시 처리 (예: 로그아웃 로직)
      console.error('Unauthorized access - maybe token expired');
      // localStorage.removeItem('access_token');
      // window.location.href = '/login'; // 이 부분은 AuthContext 등에서 처리하는 것이 좋을 수 있습니다.
    }
    // 백엔드에서 제공하는 상세 에러 메시지가 있을 경우 최우선으로 노출
    if (error.response && error.response.data && error.response.data.detail) {
        if (typeof error.response.data.detail === 'string') {
            error.message = error.response.data.detail;
        } else {
            error.message = JSON.stringify(error.response.data.detail);
        }
    }
    return Promise.reject(error);
  }
);

// Dashboard API 호출 함수들
export const dashboardApi = {
  getExecutive: async () => {
    const response = await apiClient.get('/dashboard/executive');
    return response.data;
  },
  getTechOps: async () => {
    const response = await apiClient.get('/dashboard/techops');
    return response.data;
  }
};
