import { V2exTopic } from 'shared'

/**
 * Feed 数据源 — 用于 LazyForEach 高性能列表
 */
export class FeedDataSource implements IDataSource {
  private dataArray: V2exTopic[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number {
    return this.dataArray.length
  }

  getData(index: number): V2exTopic {
    return this.dataArray[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener)
    if (pos >= 0) {
      this.listeners.splice(pos, 1)
    }
  }

  /** 替换全部数据 */
  setData(data: V2exTopic[]): void {
    this.dataArray = data
    this.listeners.forEach(listener => listener.onDataReloaded())
  }

  /** 追加数据（触底加载） */
  appendData(data: V2exTopic[]): void {
    const start = this.dataArray.length
    this.dataArray = this.dataArray.concat(data)
    this.listeners.forEach(listener => listener.onDataAdd(start))
  }
}
