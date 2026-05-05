import { V2exTopic, V2exReply, ApiService, TopicDetailCache } from 'shared'
import { ReplyDataSource } from '../model/DetailModels'

/**
 * 主题详情页 ViewModel
 */
@Observed
export class DetailViewModel {
  topic: V2exTopic | null = null
  replyDataSource: ReplyDataSource = new ReplyDataSource()
  isLoading: boolean = false
  errorMessage: string = ''
  topicId: number = 0

  private api: ApiService = new ApiService()
  private cacheLoader: (() => Promise<TopicDetailCache | null>) | null = null
  private cacheSaver: ((topic: V2exTopic | null, replies: V2exReply[]) => Promise<void>) | null = null

  constructor(topicId: number) {
    this.topicId = topicId
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
    try {
      const results = await Promise.all([
        this.api.getTopicById(this.topicId),
        this.api.getReplies(this.topicId)
      ])
      const topics = results[0] as V2exTopic[]
      const replies = results[1] as V2exReply[]
      if (topics.length > 0) {
        this.topic = topics[0]
      }
      this.replyDataSource.setData(replies)
      await this.saveCache(this.topic, replies)
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message || '加载失败'
      await this.loadCachedData()
      console.error('Failed to load topic detail:', e.message)
    } finally {
      this.isLoading = false
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
