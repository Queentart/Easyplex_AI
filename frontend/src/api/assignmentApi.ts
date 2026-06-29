import axios from 'axios';

const API_BASE_URL = 'http://localhost:8000/api/v1/assignments';

const getAuthHeaders = () => ({
  headers: {
    Authorization: `Bearer ${localStorage.getItem('access_token')}`
  }
});

export interface AssignmentTask {
  id: number;
  title: string;
  description: string;
  deadline: string;
  status?: string;
  submission_id?: number;
  final_score?: number | null;
  final_feedback?: string | null;
}

export interface AssignmentSubmission {
  id: number;
  student_name: string;
  content: string | null;
  file_url: string | null;
  file_name: string | null;
  submitted_at: string;
  ai_score: number | null;
  ai_confidence: string | null;
  ai_feedback: string | null;
  final_score: number | null;
  final_feedback: string | null;
  status: string;
}

export interface AIGradingResponse {
  score: number;
  feedback: string;
  ai_confidence?: string;
}

export const assignmentApi = {
  // Get all assignment tasks
  getTasks: async (): Promise<AssignmentTask[]> => {
    const response = await axios.get(`${API_BASE_URL}/tasks`, getAuthHeaders());
    return response.data;
  },

  // Create a new assignment task (Instructor)
  createTask: async (data: { title: string; description: string; deadline: string }): Promise<AssignmentTask> => {
    const response = await axios.post(`${API_BASE_URL}/tasks`, data, getAuthHeaders());
    return response.data;
  },

  // Submit an assignment (Student)
  submitAssignment: async (taskId: number, content: string, file: File | null = null): Promise<AssignmentSubmission> => {
    const formData = new FormData();
    formData.append('content', content);
    if (file) {
      formData.append('file', file);
    }
    
    const headers = getAuthHeaders().headers;
    const response = await axios.post(`${API_BASE_URL}/tasks/${taskId}/submit`, formData, {
      headers: {
        ...headers,
        'Content-Type': 'multipart/form-data'
      }
    });
    return response.data;
  },

  // Get submissions for a task (Instructor)
  getSubmissions: async (taskId: number): Promise<AssignmentSubmission[]> => {
    const response = await axios.get(`${API_BASE_URL}/tasks/${taskId}/submissions`, getAuthHeaders());
    return response.data;
  },

  // Generate AI grading (Instructor)
  generateGrading: async (student_name: string, assignment_title: string, submission_content: string | null, file_url: string | null = null, file_name: string | null = null): Promise<AIGradingResponse> => {
    const response = await axios.post(`${API_BASE_URL}/generate-grading`, {
      student_name,
      assignment_title,
      submission_content: submission_content || "",
      file_url,
      file_name
    }, getAuthHeaders());
    return response.data;
  },

  // Finalize grading (Instructor)
  finalizeGrading: async (submissionId: number, final_score: number, final_feedback: string): Promise<AssignmentSubmission> => {
    const response = await axios.post(`${API_BASE_URL}/submissions/${submissionId}/grade`, {
      final_score,
      final_feedback
    }, getAuthHeaders());
    return response.data;
  }
};
