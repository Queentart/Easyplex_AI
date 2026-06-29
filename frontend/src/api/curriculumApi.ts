import { apiClient } from './client';

export interface CurriculumStep {
  id: number;
  title: string;
  status: 'completed' | 'current' | 'upcoming';
  progress?: number;
  completed_date?: string;
  starts_date?: string;
  display_order: number;
}

export interface CurriculumStepCreate {
  title: string;
  status?: string;
  progress?: number;
  completed_date?: string;
  starts_date?: string;
  display_order?: number;
}

export const curriculumApi = {
  getCurriculumSteps: async (): Promise<CurriculumStep[]> => {
    const response = await apiClient.get('/curriculum/');
    return response.data;
  },

  createCurriculumStep: async (data: CurriculumStepCreate): Promise<CurriculumStep> => {
    const response = await apiClient.post('/curriculum/', data);
    return response.data;
  },

  updateCurriculumStep: async (id: number, data: Partial<CurriculumStepCreate>): Promise<CurriculumStep> => {
    const response = await apiClient.put(`/curriculum/${id}`, data);
    return response.data;
  },

  deleteCurriculumStep: async (id: number): Promise<void> => {
    await apiClient.delete(`/curriculum/${id}`);
  },

  // 문서를 업로드하여 파싱된 임시 커리큘럼 리스트(JSON)를 받아옴
  uploadCurriculumDocument: async (file: File): Promise<CurriculumStep[]> => {
    const formData = new FormData();
    formData.append('file', file);
    const response = await apiClient.post<CurriculumStep[]>('/curriculum/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  },

  // 파싱된 여러 개의 커리큘럼 단계를 한 번에 DB에 저장함
  createCurriculumStepsBatch: async (steps: Partial<CurriculumStep>[]): Promise<CurriculumStep[]> => {
    const response = await apiClient.post<CurriculumStep[]>('/curriculum/batch', steps);
    return response.data;
  }
};

