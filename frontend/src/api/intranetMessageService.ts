import { apiClient as api } from './client';
import type { IntranetMessage, UserRole } from '../types';

export const intranetMessageService = {
  getMessages: async (): Promise<IntranetMessage[]> => {
    const response = await api.get('/intranet-messages/');
    return response.data;
  },

  sendMessage: async (receiverRole: UserRole, content: string, cohortName?: string): Promise<IntranetMessage> => {
    const response = await api.post('/intranet-messages/', {
      receiver_role: receiverRole.toUpperCase(),
      content,
      cohort_name: cohortName,
    });
    return response.data;
  },
};
