export interface ClassPeriod {
  period: number;
  subject: string;
  instructorName: string;
  content: string;
  notes: string;
}

export interface TrainingLogData {
  id: string;
  courseName: string;
  coursePeriod: string;
  trainingDate: string;
  trainingDayNumber: number;
  remainingDays: number;
  attendance: {
    total: number;
    present: number;
    absent: number;
    late: number;
    out: number;
    earlyLeave: number;
  };
  schedule: ClassPeriod[];
  instructions: string;
  specialNotes: string;
  createdAt: string;
  instructorId: string;
}

const STORAGE_KEY = 'eduai_training_logs';

export const trainingLogService = {
  getLogs: (): TrainingLogData[] => {
    try {
      const data = localStorage.getItem(STORAGE_KEY);
      if (data) {
        return JSON.parse(data);
      }
    } catch (e) {
      console.error('Failed to parse training logs from local storage', e);
    }
    // Return dummy data if none exists
    const dummyLogs: TrainingLogData[] = [
      {
        id: 'log-1',
        instructorId: 'unknown',
        createdAt: new Date().toISOString(),
        courseName: 'AI Agent를 활용한 디지털 미디어 콘텐츠 Innovator',
        coursePeriod: '2026년 3월 31일 ~ 2026년 10월 8일 (3회차)',
        trainingDate: '2026-06-16',
        trainingDayNumber: 52,
        remainingDays: 78,
        attendance: { total: 28, present: 23, absent: 1, late: 2, out: 1, earlyLeave: 1 },
        schedule: [
          { period: 1, subject: '파이썬 기초', instructorName: '김범준', content: '데이터 타입과 변수', notes: '' },
          { period: 2, subject: '파이썬 기초', instructorName: '김범준', content: '조건문과 반복문', notes: '' },
          { period: 3, subject: '파이썬 기초', instructorName: '김범준', content: '리스트, 딕셔너리 활용', notes: '' },
          { period: 4, subject: '파이썬 기초', instructorName: '김범준', content: '함수 정의 및 호출', notes: '' },
          { period: 5, subject: '파이썬 기초', instructorName: '김범준', content: '모듈과 패키지', notes: '' },
          { period: 6, subject: '파이썬 기초', instructorName: '김범준', content: '예외 처리', notes: '' },
          { period: 7, subject: '파이썬 실습', instructorName: '김범준', content: '계산기 프로그램 만들기', notes: '' },
          { period: 8, subject: '파이썬 실습', instructorName: '김범준', content: '코드 리뷰 및 피드백', notes: '' },
        ],
        instructions: '반복문 중첩 실습 문제 복습 요망',
        specialNotes: '결석자: 이준표(면접)\n지각자: 이유림(개인 사정)'
      },
      {
        id: 'log-2',
        instructorId: 'unknown',
        createdAt: new Date().toISOString(),
        courseName: 'AI Agent를 활용한 디지털 미디어 콘텐츠 Innovator',
        coursePeriod: '2026년 3월 31일 ~ 2026년 10월 8일 (3회차)',
        trainingDate: '2026-06-15',
        trainingDayNumber: 51,
        remainingDays: 79,
        attendance: { total: 28, present: 28, absent: 0, late: 0, out: 0, earlyLeave: 0 },
        schedule: [
          { period: 1, subject: '오리엔테이션', instructorName: '신명근', content: '훈련 내용 및 운영 안내', notes: '' },
          { period: 2, subject: '오리엔테이션', instructorName: '최나라', content: '강사 및 담당자 소개', notes: '' },
          { period: 3, subject: 'AI 기초', instructorName: '김범준', content: '생성형 인공지능 시대 개막', notes: '' },
          { period: 4, subject: 'AI 기초', instructorName: '김범준', content: '파이썬 개발환경 구축', notes: '' },
          { period: 5, subject: 'AI 기초', instructorName: '김범준', content: '파이썬 설치 및 IDLE 사용법', notes: '' },
          { period: 6, subject: 'AI 기초', instructorName: '김범준', content: 'VS-Code 설치 및 확장 기능', notes: '' },
          { period: 7, subject: 'AI 기초', instructorName: '김범준', content: '파이썬 가상 환경 생성', notes: '' },
          { period: 8, subject: 'AI 기초', instructorName: '김범준', content: '가상 환경 실습', notes: '' },
        ],
        instructions: '개발 환경 셋팅 완료 필수',
        specialNotes: '특이사항 없음'
      }
    ];
    localStorage.setItem(STORAGE_KEY, JSON.stringify(dummyLogs));
    return dummyLogs;
  },

  saveLog: (log: Omit<TrainingLogData, 'id' | 'createdAt'>): TrainingLogData => {
    const logs = trainingLogService.getLogs();
    const newLog: TrainingLogData = {
      ...log,
      id: `log-${Date.now()}`,
      createdAt: new Date().toISOString()
    };
    const updatedLogs = [newLog, ...logs];
    localStorage.setItem(STORAGE_KEY, JSON.stringify(updatedLogs));
    return newLog;
  }
};
