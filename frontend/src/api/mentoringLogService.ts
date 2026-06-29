export type SpecialTag = 'none' | 'intensive_care' | 'suspicious' | 'excellent';

export interface MentoringEntry {
  id: string;
  date: string;
  tutorName: string;
  traineeName: string; // "수강생 전체" or specific name
  category: string; // e.g., "질의응답", "기타"
  topic: string;
  content: string;
  specialNotes: string;
  tag: SpecialTag;
}

export interface MentoringLogData {
  id: string;
  courseName: string;
  coursePeriod: string;
  subject: string;
  tutorName: string;
  classWeek: number;
  classPeriod: string; // e.g., "12.31 ~ 1.2 / 휴강(1.1)"
  createdAt: string;
  entries: MentoringEntry[];
}

const STORAGE_KEY = 'eduai_mentoring_logs';

export const mentoringLogService = {
  getLogs: (): MentoringLogData[] => {
    try {
      const data = localStorage.getItem(STORAGE_KEY);
      if (data) {
        return JSON.parse(data);
      }
    } catch (e) {
      console.error('Failed to parse mentoring logs from local storage', e);
    }
    // Return dummy data if none exists
    const dummyLogs: MentoringLogData[] = [
      {
        id: 'mlog-1',
        courseName: 'AI Agent를 활용한 디지털 미디어 콘텐츠 Innovator',
        coursePeriod: '2025.12.31 ~ 2026.07.10',
        subject: 'AI Agent를 위한 LLM 기초',
        tutorName: '이주영',
        classWeek: 1,
        classPeriod: '12.31 ~ 1.2 / 휴강(1.1)',
        createdAt: new Date().toISOString(),
        entries: [
          {
            id: 'e1',
            date: '2025.12.31',
            tutorName: '이주영',
            traineeName: '훈련생 전체',
            category: '기타',
            topic: '환경 세팅',
            content: '파이썬 아나콘다, vs code 환경 세팅',
            specialNotes: '',
            tag: 'none'
          },
          {
            id: 'e2',
            date: '2026.01.02',
            tutorName: '이주영',
            traineeName: '수강생 전체',
            category: '질의응답',
            topic: 'LLM 프롬프트 작성 요령',
            content: 'LLM을 사용해 프롬프트 작성 시 주의 사항',
            specialNotes: '',
            tag: 'none'
          },
          {
            id: 'e3',
            date: '2026.01.03',
            tutorName: '이주영',
            traineeName: '김학생',
            category: '질의응답',
            topic: '개인 진로 상담',
            content: '비전공자로서의 학습 방향성 상담',
            specialNotes: '학습 의지가 매우 높음',
            tag: 'excellent'
          },
          {
            id: 'e4',
            date: '2026.01.06',
            tutorName: '이주영',
            traineeName: '이수강',
            category: '질의응답',
            topic: '결석 사유 및 진도 보충',
            content: '결석에 따른 진도 보충 방법 안내',
            specialNotes: '지속적인 관찰 요망',
            tag: 'intensive_care'
          }
        ]
      }
    ];
    localStorage.setItem(STORAGE_KEY, JSON.stringify(dummyLogs));
    return dummyLogs;
  },

  saveLog: (log: Omit<MentoringLogData, 'id' | 'createdAt'>): MentoringLogData => {
    const logs = mentoringLogService.getLogs();
    const newLog: MentoringLogData = {
      ...log,
      id: `mlog-${Date.now()}`,
      createdAt: new Date().toISOString()
    };
    const updatedLogs = [newLog, ...logs];
    localStorage.setItem(STORAGE_KEY, JSON.stringify(updatedLogs));
    return newLog;
  }
};
