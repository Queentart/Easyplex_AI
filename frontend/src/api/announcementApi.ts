import { apiClient } from './client';

export interface Announcement {
  id: number;
  title: string;
  content: string;
  is_important: boolean;
  attachment_name: string | null;
  attachment_url: string | null;
  author_id: number | null;
  created_at: string;
  updated_at: string;
}

export interface AnnouncementCreate {
  title: string;
  content: string;
  is_important: boolean;
  file?: File | null;
}

export const announcementApi = {
  // 학생용 API
  getStudentAnnouncements: async (skip: number = 0, limit: number = 100): Promise<Announcement[]> => {
    const response = await apiClient.get('/student/announcements/', {
      params: { skip, limit }
    });
    return response.data;
  },

  // 운영팀(EduOps)용 API
  getOpsAnnouncements: async (skip: number = 0, limit: number = 100): Promise<Announcement[]> => {
    const response = await apiClient.get('/ops/announcements/', {
      params: { skip, limit }
    });
    return response.data;
  },

  createAnnouncement: async (data: AnnouncementCreate): Promise<Announcement> => {
    const formData = new FormData();
    formData.append('title', data.title);
    formData.append('content', data.content);
    if (data.is_important) {
      formData.append('is_important', 'true');
    }
    if (data.file) {
      formData.append('file', data.file);
    }
    
    // axios 기본 설정인 application/json을 덮어쓰고, 브라우저가 자동으로 multipart/form-data와 boundary를 설정하도록 유도합니다.
    const response = await apiClient.post('/ops/announcements/', formData, {
      headers: {
        'Content-Type': undefined
      }
    });
    return response.data;
  },

  deleteAnnouncement: async (id: number): Promise<Announcement> => {
    const response = await apiClient.delete(`/ops/announcements/${id}`);
    return response.data;
  }
};
