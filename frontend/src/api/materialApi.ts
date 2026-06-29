import axios from 'axios';

// Assuming base URL setup or relying on proxy
const API_BASE_URL = 'http://localhost:8000/api/v1';

export interface CourseMaterial {
  id: number;
  title: string;
  description: string;
  file_name: string;
  file_type: string;
  file_size: number;
  file_url: string;
  uploaded_by_id: number;
  created_at: string;
}

export interface UploadMaterialResponse {
  message: string;
  id: number;
  title: string;
  file_url: string;
}

export const materialApi = {
  getMaterials: async (): Promise<CourseMaterial[]> => {
    const response = await axios.get(`${API_BASE_URL}/instructor/materials`, {
      headers: {
        Authorization: `Bearer ${localStorage.getItem('access_token')}`
      }
    });
    return response.data;
  },

  uploadMaterial: async (title: string, description: string, file: File): Promise<UploadMaterialResponse> => {
    const formData = new FormData();
    formData.append('title', title);
    formData.append('description', description);
    formData.append('file', file);

    const response = await axios.post(`${API_BASE_URL}/instructor/materials`, formData, {
      headers: {
        Authorization: `Bearer ${localStorage.getItem('access_token')}`
      }
    });
    return response.data;
  },

  deleteMaterial: async (id: number): Promise<void> => {
    await axios.delete(`${API_BASE_URL}/instructor/materials/${id}`, {
      headers: {
        Authorization: `Bearer ${localStorage.getItem('access_token')}`
      }
    });
  }
};
