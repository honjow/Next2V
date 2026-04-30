import { V2exMemberProfile, V2exTopic, ApiService } from 'shared'

/**
 * 主题数据源 — 用于 LazyForEach
 */
export class TopicDataSource implements IDataSource {
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

  setData(data: V2exTopic[]): void {
    this.dataArray = data
    this.listeners.forEach(listener => listener.onDataReloaded())
  }
}

/**
 * 用户主页 ViewModel
 */
@Observed
export class UserViewModel {
  profile: V2exMemberProfile | null = null
  topicDataSource: TopicDataSource = new TopicDataSource()
  isLoading: boolean = false
  username: string = ''

  private api: ApiService = new ApiService()

  constructor(username: string) {
    this.username = username
  }

  async load(): Promise<void> {
    this.isLoading = true
    try {
      this.profile = await this.api.getMember(this.username)
      this.topicDataSource.setData(await this.api.getTopicsByUsername(this.username))
    } catch (error) {
      console.error('Failed to load user:', error.message)
    } finally {
      this.isLoading = false
    }
  }
}
