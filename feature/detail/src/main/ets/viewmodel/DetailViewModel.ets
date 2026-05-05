import { V2exTopic, V2exReply, ApiService, ApiV2Service, TopicDetailCache } from 'shared'
import { ReplyDataSource } from '../model/DetailModels'

/**
 * 主题详情页 ViewModel
 */
@Observed
export class DetailViewModel {
  topic: V2exTopic | null = null
  replyDataSource: ReplyDataSource = new ReplyDataSource()
  isLoading: boolean = false
  repliesUseV2: boolean = false
  repliesPage: number = 1
  repliesHasMore: boolean = false
  isRepliesLoadingMore: boolean = false
  repliesLoaded: number = 0
  errorMessage: string = ''
  topicId: number = 0

  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private authToken: string = ''
  private replies: V2exReply[] = []
  private cacheLoader: (() => Promise<TopicDetailCache | null>) | null = null
  private cacheSaver: ((topic: V2exTopic | null, replies: V2exReply[]) => Promise<void>) | null = null
  private readonly V2_REPLY_PAGE_SIZE: number = 20

  constructor(topicId: number) {
    this.topicId = topicId
  }

  setToken(token: string): void {
    this.authToken = token.trim()
  }

  setCacheHandlers(
    loader: () => Promise<TopicDetailCache | null>,
    saver: (topic: V2exTopic | null, replies: V2exReply[]) => Promise<void>
  ): void {
    this.cacheLoader = loader
    this.cacheSaver = saver
  }

  async loadCachedData(): Promise<void> {
    if (!this.cacheLoader || this.topic !== null || this.replyDataSource.totalCount() > 0) {
      return
    }
    try {
      const cached = await this.cacheLoader()
      if (!cached) {
        return
      }
      this.topic = cached.topic
      this.replyDataSource.setData(cached.replies)
      this.replies = cached.replies
      this.repliesLoaded = cached.replies.length
    } catch (error) {
      console.error('load topic cache failed:', (error as Error).message)
    }
  }

  async load(): Promise<void> {
    if (this.topicId <= 0) {
      this.errorMessage = '无效的主题 ID'
      return
    }
    this.isLoading = true
    this.errorMessage = ''
    this.repliesUseV2 = !!this.authToken
    this.repliesPage = 1
    this.repliesHasMore = false
    this.isRepliesLoadingMore = false
    try {
      let topic: V2exTopic | null = null
      let replies: V2exReply[] = []
      if (this.authToken) {
        const res = await this.apiV2.getTopic(this.authToken, this.topicId)
        topic = res.data
        const replyRes = await this.apiV2.getTopicReplies(this.authToken, this.topicId, 1)
        replies = replyRes.data || []
        this.repliesUseV2 = true
        this.repliesHasMore = replies.length >= this.V2_REPLY_PAGE_SIZE
      } else {
        const topics = await this.api.getTopicById(this.topicId)
        if (topics.length > 0) {
          topic = topics[0]
        }
        replies = await this.api.getReplies(this.topicId)
        this.repliesUseV2 = false
        this.repliesHasMore = false
      }

      this.topic = topic
      this.replyDataSource.setData(replies)
      this.replies = replies
      this.repliesLoaded = replies.length
      await this.saveCache(topic, replies)
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message || '加载失败'
      await this.loadCachedData()
      console.error('Failed to load topic detail:', e.message)
    } finally {
      this.isLoading = false
    }
  }

  async loadMoreRepliesV2(): Promise<void> {
    if (!this.repliesUseV2 || this.isLoading || this.isRepliesLoadingMore || !this.repliesHasMore || !this.authToken) {
      return
    }
    const nextPage = this.repliesPage + 1
    this.isRepliesLoadingMore = true
    try {
      const res = await this.apiV2.getTopicReplies(this.authToken, this.topicId, nextPage)
      const items = res.data || []
      if (items.length === 0) {
        this.repliesHasMore = false
        return
      }

      const existingIds = new Set<number>(this.replies.map(reply => reply.id))
      const unique = items.filter(item => item && item.id > 0 && !existingIds.has(item.id))
      if (unique.length === 0) {
        this.repliesHasMore = false
        return
      }

      this.replies = this.replies.concat(unique)
      this.replyDataSource.appendData(unique)
      this.repliesLoaded = this.replies.length
      this.repliesPage = nextPage
      this.repliesHasMore = items.length >= this.V2_REPLY_PAGE_SIZE
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message || '加载更多失败'
      this.repliesHasMore = false
    } finally {
      this.isRepliesLoadingMore = false
    }
  }

  private async saveCache(topic: V2exTopic | null, replies: V2exReply[]): Promise<void> {
    if (!this.cacheSaver || !topic) {
      return
    }
    try {
      await this.cacheSaver(topic, replies)
    } catch (error) {
      console.error('save topic cache failed:', (error as Error).message)
    }
  }
}
