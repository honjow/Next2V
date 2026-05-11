import { V2exTopic, V2exReply, ApiService, ApiV2Service, TopicDetailCache, HtmlEntityUtils } from 'shared'
import type { V2exTopicWebRepliesPage } from 'shared'
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
  repliesLoadMoreState: string = 'endReached'
  loadMoreErrorMessage: string = ''
  isBottomRefreshing: boolean = false
  errorMessage: string = ''
  topicId: number = 0

  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private authToken: string = ''
  private replies: V2exReply[] = []
  private cacheLoader: (() => Promise<TopicDetailCache | null>) | null = null
  private cacheSaver: ((topic: V2exTopic | null, replies: V2exReply[]) => Promise<void>) | null = null
  private repliesSource: string = 'publicApi'
  private repliesPageCount: number = 1
  private failedRepliesPage: number = 0
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
    this.loadMoreErrorMessage = ''
    this.repliesUseV2 = !!this.authToken
    this.repliesSource = this.authToken ? 'v2' : 'publicApi'
    this.repliesPage = 1
    this.repliesPageCount = 1
    this.repliesHasMore = false
    this.isRepliesLoadingMore = false
    this.isBottomRefreshing = false
    this.failedRepliesPage = 0
    this.repliesLoadMoreState = 'endReached'
    try {
      let topic: V2exTopic | null = null
      let replies: V2exReply[] = []
      if (this.authToken) {
        const res = await this.apiV2.getTopic(this.authToken, this.topicId)
        topic = res.data
        const replyRes = await this.apiV2.getTopicReplies(this.authToken, this.topicId, 1)
        replies = replyRes.data || []
        this.repliesUseV2 = true
        this.repliesSource = 'v2'
        this.repliesHasMore = replies.length >= this.V2_REPLY_PAGE_SIZE
      } else {
        const topics = await this.api.getTopicById(this.topicId)
        if (topics.length > 0) {
          topic = topics[0]
        }
        const apiReplies = await this.api.getReplies(this.topicId)
        const expectedReplies = topic ? topic.replies : 0
        if (apiReplies.length === 0 || (expectedReplies > 0 && apiReplies.length < expectedReplies)) {
          const firstPage = await this.api.getTopicWebRepliesPage(this.topicId, 1, Date.now())
          replies = firstPage.replies
          this.repliesSource = 'publicWebPage'
          this.repliesPage = firstPage.page
          this.repliesPageCount = firstPage.pageCount
          this.repliesHasMore = firstPage.hasMore
        } else {
          replies = apiReplies
          this.repliesSource = 'publicApi'
          this.repliesHasMore = false
        }
        this.repliesUseV2 = false
      }

      this.topic = this.normalizeTopicForRender(topic)
      this.replies = this.normalizeRepliesForRender(replies)
      this.replyDataSource.setData(this.getVisibleReplies())
      this.repliesLoaded = this.replies.length
      this.repliesLoadMoreState = this.repliesHasMore ? 'idle' : 'endReached'
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

  async loadMoreReplies(): Promise<void> {
    if (this.isLoading || this.isRepliesLoadingMore || this.isBottomRefreshing || !this.repliesHasMore) {
      return
    }
    if (this.repliesSource === 'v2' && !this.authToken) {
      return
    }
    const nextPage = this.failedRepliesPage > 0 ? this.failedRepliesPage : this.repliesPage + 1
    this.isRepliesLoadingMore = true
    this.repliesLoadMoreState = 'loadingMore'
    this.loadMoreErrorMessage = ''
    try {
      let items: V2exReply[] = []
      let hasMore = false
      let pageCount = this.repliesPageCount
      if (this.repliesSource === 'v2') {
        const res = await this.apiV2.getTopicReplies(this.authToken, this.topicId, nextPage)
        items = res.data || []
        hasMore = items.length >= this.V2_REPLY_PAGE_SIZE
      } else if (this.repliesSource === 'publicWebPage') {
        const snapshot: V2exTopicWebRepliesPage = await this.api.getTopicWebRepliesPage(this.topicId, nextPage, Date.now())
        items = snapshot.replies
        hasMore = snapshot.hasMore
        pageCount = snapshot.pageCount
      } else {
        return
      }

      const unique = this.uniqueNewReplies(items)
      this.appendReplies(unique)
      if (this.repliesSource !== 'v2' || items.length > 0) {
        this.repliesPage = nextPage
      }
      this.repliesPageCount = Math.max(pageCount, this.repliesPage)
      this.repliesHasMore = hasMore
      this.failedRepliesPage = 0
      this.repliesLoadMoreState = hasMore ? 'idle' : 'endReached'
      await this.saveCache(this.topic, this.replies)
    } catch (error) {
      const e = error as Error
      this.loadMoreErrorMessage = e.message || '加载更多失败'
      this.failedRepliesPage = nextPage
      this.repliesLoadMoreState = 'loadMoreError'
    } finally {
      this.isRepliesLoadingMore = false
    }
  }

  async loadMoreRepliesV2(): Promise<void> {
    await this.loadMoreReplies()
  }

  async retryLoadMoreReplies(): Promise<void> {
    if (this.repliesLoadMoreState !== 'loadMoreError' || this.failedRepliesPage <= 0) {
      return
    }
    await this.loadMoreReplies()
  }

  canBottomRefresh(): boolean {
    return !this.isLoading && !this.isRepliesLoadingMore && !this.isBottomRefreshing &&
      this.repliesLoadMoreState === 'endReached' && !this.repliesHasMore && this.repliesPage >= 1
  }

  shouldShowRepliesFooter(): boolean {
    return this.repliesLoadMoreState === 'loadingMore' || this.repliesLoadMoreState === 'loadMoreError'
  }

  async refreshLastRepliesPage(): Promise<void> {
    if (!this.canBottomRefresh()) {
      return
    }
    this.isBottomRefreshing = true
    try {
      let items: V2exReply[] = []
      if (this.repliesSource === 'v2') {
        const res = await this.apiV2.getTopicReplies(this.authToken, this.topicId, this.repliesPage, Date.now())
        items = res.data || []
      } else if (this.repliesSource === 'publicWebPage') {
        const snapshot = await this.api.getTopicWebRepliesPage(this.topicId, this.repliesPage, Date.now())
        items = snapshot.replies
        this.repliesPageCount = snapshot.pageCount
        this.repliesHasMore = snapshot.hasMore
        if (snapshot.hasMore) {
          this.repliesLoadMoreState = 'idle'
        }
      } else {
        const snapshot = await this.api.getTopicWebRepliesPage(this.topicId, 1, Date.now())
        items = snapshot.replies
        this.repliesSource = 'publicWebPage'
        this.repliesPage = snapshot.page
        this.repliesPageCount = snapshot.pageCount
        this.repliesHasMore = snapshot.hasMore
        if (snapshot.hasMore) {
          this.repliesLoadMoreState = 'idle'
        }
      }
      const unique = this.uniqueNewReplies(items)
      this.appendReplies(unique)
      if (!this.repliesHasMore) {
        this.repliesLoadMoreState = 'endReached'
      }
      await this.saveCache(this.topic, this.replies)
    } finally {
      this.isBottomRefreshing = false
    }
  }

  private uniqueNewReplies(items: V2exReply[]): V2exReply[] {
    const existingIds = new Set<number>(this.replies.map(reply => reply.id))
    return this.normalizeRepliesForRender(items).filter((item: V2exReply) => item && item.id > 0 && !existingIds.has(item.id))
  }

  private appendReplies(unique: V2exReply[]): void {
    if (unique.length === 0) {
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
