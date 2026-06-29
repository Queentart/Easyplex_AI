import { apiClient } from './client';

export interface AttendanceStats {
  lates: number;
  absences: number;
  earlyLeaves: number;
  rate: number;
}

export const attendanceApi = {
  getStudentStats: async (): Promise<AttendanceStats> => {
    const response = await apiClient.get('/student/attendance/stats');
    return response.data;
  }
};
