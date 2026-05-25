import { V2exTopic } from 'shared'

/**
 * Feed data source — for LazyForEach high-performance list
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

  /** Replace all data */
  setData(data: V2exTopic[]): void {
    this.dataArray = data
    this.listeners.forEach(listener => listener.onDataReloaded())
  }

  getAllData(): V2exTopic[] {
    return this.dataArray
  }

  /** Append data (load on scroll to bottom) */
  appendData(data: V2exTopic[]): void {
    if (data.length === 0) {
      return
    }
    const start = this.dataArray.length
    this.dataArray = this.dataArray.concat(data)
    this.listeners.forEach(listener => listener.onDataAdd(start))
  }
}
