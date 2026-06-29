const STORAGE_KEY = 'easyplex_ops_logs';

export interface OpsLog {
  id: string;
  action: string;
  detail: string;
  timestamp: string;
  status: 'info' | 'success' | 'warning' | 'error';
}

class OpsLogService {
  private getStorage(): OpsLog[] {
    const data = localStorage.getItem(STORAGE_KEY);
    if (!data) {
      return [];
    }
    try {
      return JSON.parse(data);
    } catch {
      return [];
    }
  }

  private setStorage(data: OpsLog[]) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  }

  private triggerEvent() {
    window.dispatchEvent(new StorageEvent('storage', { key: STORAGE_KEY }));
  }

  public getLogs(): OpsLog[] {
    return this.getStorage();
  }

  public addLog(action: string, detail: string, status: OpsLog['status'] = 'info'): OpsLog[] {
    const current = this.getStorage();
    
    const newLog: OpsLog = {
      id: `log_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      action,
      detail,
      timestamp: new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true }),
      status
    };

    // Keep only the last 50 logs to prevent unbounded growth
    const updated = [newLog, ...current].slice(0, 50);
    this.setStorage(updated);
    this.triggerEvent();
    return updated;
  }

  public clearLogs(): void {
    this.setStorage([]);
    this.triggerEvent();
  }
}

export const opsLogService = new OpsLogService();
