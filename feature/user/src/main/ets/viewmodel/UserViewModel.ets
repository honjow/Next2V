import {
  V2exMemberProfile, V2exTopic, V2exUserReply, V2exMemberActionState,
  ApiService, CookieJarSettings, translateApiError
} from 'shared'

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

  appendData(data: V2exTopic[]): void {
    if (data.length === 0) {
      return
    }
    const start = this.dataArray.length
    this.dataArray = this.dataArray.concat(data)
    this.listeners.forEach(listener => listener.onDataAdd(start))
  }
}

export class ReplyDataSource implements IDataSource {
  private dataArray: V2exUserReply[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number {
    return this.dataArray.length
  }

  getData(index: number): V2exUserReply {
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

  setData(data: V2exUserReply[]): void {
    this.dataArray = data
    this.listeners.forEach(listener => listener.onDataReloaded())
  }

  appendData(data: V2exUserReply[]): void {
    if (data.length === 0) {
      return
    }
    const start = this.dataArray.length
    this.dataArray = this.dataArray.concat(data)
    this.listeners.forEach(listener => listener.onDataAdd(start))
  }
}

/**
 * 用户主页 ViewModel
 */
@Observed
export class UserViewModel {
  profile: V2exMemberProfile | null = null
  topicDataSource: TopicDataSource = new TopicDataSource()
  replyDataSource: ReplyDataSource = new ReplyDataSource()
  actions: V2exMemberActionState | null = null
  topicsHidden: boolean = false
  recentTopicCount: number = 0
  recentReplyCount: number = 0
  isLoading: boolean = false
  isActionLoading: boolean = false
  errorMessage: string = ''
  username: string = ''

  private api: ApiService = new ApiService()

  constructor(username: string) {
    this.username = username
  }

  async load(): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''
    try {
      this.profile = await this.api.getMember(this.username)
      const snapshot = await this.api.getMemberPageSnapshot(this.username, CookieJarSettings.getCurrentCookie())
      this.actions = snapshot.actions
      this.topicsHidden = snapshot.topicsHidden
      this.replyDataSource.setData(snapshot.replies)
      const topics = await this.api.getTopicsByIds(snapshot.topicIds)
      this.recentReplyCount = snapshot.replies.length
      this.recentTopicCount = topics.length
      this.topicDataSource.setData(topics)
    } catch (error) {
      this.errorMessage = translateApiError(error)
      console.error('Failed to load user:', error.message)
    } finally {
      this.isLoading = false
    }
  }

  async toggleFollow(): Promise<void> {
    if (!this.actions || !this.actions.followPath || this.isActionLoading) {
      return
    }
    await this.executeMemberAction(this.actions.followPath)
  }

  async toggleBlock(): Promise<void> {
    if (!this.actions || !this.actions.blockPath || this.isActionLoading) {
      return
    }
    await this.executeMemberAction(this.actions.blockPath)
  }

  private async executeMemberAction(path: string): Promise<void> {
    this.isActionLoading = true
    this.errorMessage = ''
    try {
      const snapshot = await this.api.executeMemberActionWithCookie(
        CookieJarSettings.getCurrentCookie(),
        this.username,
        path
      )
      this.actions = snapshot.actions
      this.topicsHidden = snapshot.topicsHidden
      this.replyDataSource.setData(snapshot.replies)
      const topics = await this.api.getTopicsByIds(snapshot.topicIds)
      this.recentReplyCount = snapshot.replies.length
      this.recentTopicCount = topics.length
      this.topicDataSource.setData(topics)
    } catch (error) {
      this.errorMessage = translateApiError(error)
      throw new Error(this.errorMessage)
    } finally {
      this.isActionLoading = false
    }
  }
}

@Observed
export class UserTopicsViewModel {
  topicDataSource: TopicDataSource = new TopicDataSource()
  username: string = ''
  page: number = 1
  hasMore: boolean = true
  topicsHidden: boolean = false
  isLoading: boolean = false
  isLoadingMore: boolean = false
  errorMessage: string = ''

  private api: ApiService = new ApiService()

  constructor(username: string) {
    this.username = username
  }

  async load(): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''
    this.page = 1
    this.hasMore = true
    try {
      const snapshot = await this.api.getMemberTopicsPage(this.username, this.page, CookieJarSettings.getCurrentCookie())
      this.topicsHidden = snapshot.topicsHidden
      this.hasMore = snapshot.hasMore
      this.topicDataSource.setData(await this.api.getTopicsByIds(snapshot.topicIds))
    } catch (error) {
      this.errorMessage = translateApiError(error)
    } finally {
      this.isLoading = false
    }
  }

  async loadMore(): Promise<void> {
    if (this.isLoading || this.isLoadingMore || !this.hasMore || this.topicsHidden) {
      return
    }
    this.isLoadingMore = true
    try {
      const nextPage = this.page + 1
      const snapshot = await this.api.getMemberTopicsPage(this.username, nextPage, CookieJarSettings.getCurrentCookie())
      this.topicsHidden = snapshot.topicsHidden
      this.hasMore = snapshot.hasMore
      this.page = nextPage
      const topics = await this.api.getTopicsByIds(snapshot.topicIds)
      this.topicDataSource.appendData(topics)
    } catch (error) {
      this.errorMessage = translateApiError(error)
    } finally {
      this.isLoadingMore = false
    }
  }
}

@Observed
export class UserRepliesViewModel {
  replyDataSource: ReplyDataSource = new ReplyDataSource()
  username: string = ''
  page: number = 1
  hasMore: boolean = true
  isLoading: boolean = false
  isLoadingMore: boolean = false
  errorMessage: string = ''

  private api: ApiService = new ApiService()

  constructor(username: string) {
    this.username = username
  }

  async load(): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''
    this.page = 1
    this.hasMore = true
    try {
      const snapshot = await this.api.getMemberRepliesPage(this.username, this.page, CookieJarSettings.getCurrentCookie())
      this.hasMore = snapshot.hasMore
      this.replyDataSource.setData(snapshot.replies)
    } catch (error) {
      this.errorMessage = translateApiError(error)
    } finally {
      this.isLoading = false
    }
  }

  async loadMore(): Promise<void> {
    if (this.isLoading || this.isLoadingMore || !this.hasMore) {
      return
    }
    this.isLoadingMore = true
    try {
      const nextPage = this.page + 1
      const snapshot = await this.api.getMemberRepliesPage(this.username, nextPage, CookieJarSettings.getCurrentCookie())
      this.hasMore = snapshot.hasMore
      this.page = nextPage
      this.replyDataSource.appendData(snapshot.replies)
    } catch (error) {
      this.errorMessage = translateApiError(error)
    } finally {
      this.isLoadingMore = false
    }
  }
}
