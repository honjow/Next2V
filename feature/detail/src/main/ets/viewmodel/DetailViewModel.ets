import { V2exTopic, V2exReply, ApiService, ApiV2Service, TopicDetailCache, HtmlEntityUtils } from 'shared'
import { ReplyDataSource } from '../model/DetailModels'

/**
 * 主题详情页 ViewModel
 */
@Observed
export class DetailViewModel {
  topic: V2exTopic | null = null
  replyDataSource: ReplyDataSource = new ReplyDataSource()
  isLoading: boolean = false
  onlyOp: boolean = false
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

  setOnlyOp(enabled: boolean): void {
    this.onlyOp = enabled
    this.replyDataSource.setData(this.getVisibleReplies())
  }

  getReplyFloor(replyId: number): number {
    if (replyId <= 0) {
      return 0
    }
    for (let i = 0; i < this.replies.length; i++) {
      if (this.replies[i].id === replyId) {
        return i + 1
      }
    }
    return 0
  }

  getLoadedRepliesSnapshot(): V2exReply[] {
    return this.replies.slice()
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
      this.topic = this.normalizeTopicForRender(cached.topic)
      this.replies = this.normalizeRepliesForRender(cached.replies)
      this.replyDataSource.setData(this.getVisibleReplies())
      this.repliesLoaded = this.replies.length
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
        replies = await this.api.getRepliesWithWebFallback(this.topicId, topic ? topic.replies : 0)
        this.repliesUseV2 = false
        this.repliesHasMore = false
      }

      this.topic = this.normalizeTopicForRender(topic)
      this.replies = this.normalizeRepliesForRender(replies)
      this.replyDataSource.setData(this.getVisibleReplies())
      this.repliesLoaded = this.replies.length
      await this.saveCache(this.topic, this.replies)
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
      if (this.onlyOp) {
        const opId = this.topic ? this.topic.member.id : 0
        const opUnique = opId > 0 ? unique.filter(reply => reply.member.id === opId) : unique
        if (opUnique.length > 0) {
          this.replyDataSource.appendData(opUnique)
        }
      } else {
        this.replyDataSource.appendData(unique)
      }
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

  private normalizeTopicForRender(topic: V2exTopic | null): V2exTopic | null {
    if (!topic) {
      return topic
    }
    topic.title = HtmlEntityUtils.decode(topic.title)
    topic.content = HtmlEntityUtils.decode(topic.content)
    topic.content_rendered = HtmlEntityUtils.decode(topic.content_rendered)
    if (topic.node) {
      topic.node.title = HtmlEntityUtils.decode(topic.node.title)
      topic.node.title_alternative = HtmlEntityUtils.decode(topic.node.title_alternative)
      topic.node.header = HtmlEntityUtils.decode(topic.node.header || '')
      topic.node.footer = HtmlEntityUtils.decode(topic.node.footer || '')
    }
    if (topic.member) {
      topic.member.tagline = HtmlEntityUtils.decode(topic.member.tagline)
    }
    return topic
  }

  private normalizeRepliesForRender(replies: V2exReply[]): V2exReply[] {
    return (replies || []).map((reply: V2exReply) => this.normalizeReplyForRender(reply))
  }

  private normalizeReplyForRender(reply: V2exReply): V2exReply {
    if (!reply) {
      return reply
    }
    reply.content = HtmlEntityUtils.decode(reply.content)
    reply.content_rendered = HtmlEntityUtils.decode(reply.content_rendered)
    if (reply.member) {
      reply.member.tagline = HtmlEntityUtils.decode(reply.member.tagline)
    }
    return reply
  }

  private getVisibleReplies(): V2exReply[] {
    if (!this.onlyOp) {
      return this.replies
    }
    const opId = this.topic ? this.topic.member.id : 0
    if (opId <= 0) {
      return this.replies
    }
    return this.replies.filter(reply => reply.member.id === opId)
  }
}
