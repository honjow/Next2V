import { V2exTopic, V2exReply, ApiService } from 'shared'
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

  constructor(topicId: number) {
    this.topicId = topicId
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
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message || '加载失败'
      console.error('Failed to load topic detail:', e.message)
    } finally {
      this.isLoading = false
    }
  }
}
