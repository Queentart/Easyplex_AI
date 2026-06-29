import type { RecordedLecture } from '../types';
import { recordedLectures as initialLectures } from '../data/student';

const STORAGE_KEY = 'easyplex_vod_list';

class VODService {
  private getStorage(): RecordedLecture[] {
    const data = localStorage.getItem(STORAGE_KEY);
    if (!data) {
      // Initialize with dummy data on first load
      this.setStorage(initialLectures);
      return initialLectures;
    }
    try {
      return JSON.parse(data);
    } catch {
      return initialLectures;
    }
  }

  private setStorage(data: RecordedLecture[]) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  }

  private triggerEvent() {
    window.dispatchEvent(new StorageEvent('storage', { key: STORAGE_KEY }));
  }

  public getVODs(): RecordedLecture[] {
    return this.getStorage();
  }

  public addVOD(vod: RecordedLecture): RecordedLecture[] {
    const current = this.getStorage();
    const updated = [vod, ...current];
    this.setStorage(updated);
    this.triggerEvent();
    return updated;
  }

  public updateVOD(id: string, updates: Partial<RecordedLecture>): RecordedLecture[] {
    const current = this.getStorage();
    const updated = current.map(vod => vod.id === id ? { ...vod, ...updates } : vod);
    this.setStorage(updated);
    this.triggerEvent();
    return updated;
  }

  public deleteVOD(id: string): RecordedLecture[] {
    const current = this.getStorage();
    const updated = current.filter(vod => vod.id !== id);
    this.setStorage(updated);
    this.triggerEvent();
    return updated;
  }
}

export const vodService = new VODService();
