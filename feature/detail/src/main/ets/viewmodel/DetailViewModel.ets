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
  topicId: number = 0

  private api: ApiService = new ApiService()

  constructor(topicId: number) {
    this.topicId = topicId
  }

  async load(): Promise<void> {
    this.isLoading = true
    try {
      const topics = await this.api.getTopicById(this.topicId)
      if (topics.length > 0) {
        this.topic = topics[0]
      }
      const replies = await this.api.getReplies(this.topicId)
      this.replyDataSource.setData(replies)
    } catch (error) {
      console.error('Failed to load topic detail:', error.message)
    } finally {
      this.isLoading = false
    }
  }
}
