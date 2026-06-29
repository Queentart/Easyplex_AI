export interface TodaySession {
  id: string;
  title: string;
  date: string;
  zoomUrl: string | null;
  youtubeUrl: string | null;
  vimeoUrl: string | null;
  status: 'Live' | 'Archived' | 'Processing';
}

const STORAGE_KEY = 'easyplex_stream_link_v1';

const DEFAULT_STREAM: TodaySession = {
  id: "1",
  title: "React 심화 과정 - 라이브 Q&A 세션",
  date: new Date().toISOString().split('T')[0],
  zoomUrl: "https://zoom.us/j/mock1234",
  youtubeUrl: "https://youtube.com/live/mock1234",
  vimeoUrl: "https://vimeo.com/event/mock1234",
  status: "Live"
};

class StreamLinkService {
  private getStorage(): TodaySession | null {
    const data = localStorage.getItem(STORAGE_KEY);
    if (!data) return null;
    try {
      return JSON.parse(data);
    } catch {
      return null;
    }
  }

  private setStorage(data: TodaySession) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  }

  public getTodayStream(): TodaySession {
    const stream = this.getStorage();
    if (!stream) {
      this.setStorage(DEFAULT_STREAM);
      return DEFAULT_STREAM;
    }
    return stream;
  }

  public updateTodayStream(updates: Partial<TodaySession>): TodaySession {
    const current = this.getTodayStream();
    const updated = { ...current, ...updates };
    this.setStorage(updated);
    return updated;
  }
}

export const streamLinkService = new StreamLinkService();
