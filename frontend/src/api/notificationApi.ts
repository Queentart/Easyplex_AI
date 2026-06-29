import axios from 'axios';

const API_BASE_URL = 'http://localhost:8000/api/v1/notifications';

const getAuthHeaders = () => {
  const token = localStorage.getItem('access_token');
  return {
    headers: { Authorization: `Bearer ${token}` }
  };
};

export interface Notification {
  id: number;
  title: string;
  message: string;
  type: 'warning' | 'info' | 'success' | 'message' | 'alert';
  is_read: boolean;
  link?: string;
  created_at: string;
}

export const notificationApi = {
  getNotifications: async (): Promise<Notification[]> => {
    const response = await axios.get(API_BASE_URL, getAuthHeaders());
    return response.data;
  },

  markAsRead: async (id: number): Promise<Notification> => {
    const response = await axios.post(`${API_BASE_URL}/${id}/read`, {}, getAuthHeaders());
    return response.data;
  },

  markAllAsRead: async (): Promise<{ message: string; count?: number }> => {
    const response = await axios.post(`${API_BASE_URL}/read-all`, {}, getAuthHeaders());
    return response.data;
  },

  // Test method (will remove in production)
  createTestNotification: async (title: string, message: string, type: string = 'info'): Promise<Notification> => {
    const response = await axios.post(`${API_BASE_URL}/test?title=${encodeURIComponent(title)}&message=${encodeURIComponent(message)}&type=${type}`, {}, getAuthHeaders());
    return response.data;
  }
};
