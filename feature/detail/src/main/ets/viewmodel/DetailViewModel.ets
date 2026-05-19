import {
  V2exTopic,
  V2exReply,
  ApiService,
  ApiV2Service,
  TopicDetailCache,
  HtmlEntityUtils,
  StorageKeys,
  ReplyDisplaySettings,
  CookieJarSettings,
} from 'shared'
import type { V2exTopicWebRepliesPage, V2exTopicWebRepliesAllResult } from 'shared'
import { ReplyDataSource } from '../model/DetailModels'
import { ReplyThreadCoordinator } from '../model/ReplyThreadCoordinator'

export interface ReplyThankSnapshot {
  replyId: number
  previousThanks: number
  wasThanked: boolean
  previousRenderKey?: string
}

/**
 * 主题详情页 ViewModel
 */
@Observed
export class DetailViewModel {
  topic: V2exTopic | null = null
  replyDataSource: ReplyDataSource = new ReplyDataSource()
  isLoading: boolean = false
  onlyOp: boolean = false
  replyDisplayMode: string = ReplyDisplaySettings.normalizeMode(
    AppStorage.get<string>(StorageKeys.REPLY_DISPLAY_MODE) ?? ReplyDisplaySettings.MODE_THREAD,
  )
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
  isPreloadingAll: boolean = false
  preloadProgress: string = ''
  needsPreloadConfirm: boolean = false
  private preloadFallbackToFlat: boolean = false

  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private authToken: string = ''
  private replies: V2exReply[] = []
  private cacheLoader: (() => Promise<TopicDetailCache | null>) | null = null
  private cacheSaver: ((topic: V2exTopic | null, replies: V2exReply[]) => Promise<void>) | null =
    null
  private repliesSource: string = 'publicApi'
  private repliesPageCount: number = 1
  private failedRepliesPage: number = 0
  private readonly V2_REPLY_PAGE_SIZE: number = 20
  allRepliesLoaded: boolean = false
  private static readonly PRELOAD_REPLY_LIMIT: number = 500

  constructor(topicId: number) {
    this.topicId = topicId
  }

  setOnlyOp(enabled: boolean): void {
    this.onlyOp = enabled
    this.replyDisplayMode = enabled
      ? ReplyDisplaySettings.MODE_OP
      : ReplyDisplaySettings.MODE_THREAD
    this.replyDataSource.setData(this.getVisibleReplies())
  }

  setReplyDisplayMode(mode: string): void {
    this.replyDisplayMode = ReplyDisplaySettings.normalizeMode(mode)
    this.onlyOp = this.replyDisplayMode === ReplyDisplaySettings.MODE_OP
    this.replyDataSource.setData(this.getVisibleReplies())
  }

  isThreadMode(): boolean {
    if (this.preloadFallbackToFlat) {
      return false
    }
    const m = this.replyDisplayMode
    return (
      m === ReplyDisplaySettings.MODE_THREAD ||
      m === ReplyDisplaySettings.MODE_THREAD_WITH_MENTION ||
      m === ReplyDisplaySettings.MODE_THREAD_REDUNDANT
    )
  }

  /**
   * Called after load() completes. Checks if thread mode needs preloading
   * and either auto-preloads or sets needsPreloadConfirm for the UI to show a dialog.
   */
  triggerThreadPreloadIfNeeded(): void {
    if (!this.isThreadMode() || !this.repliesHasMore || this.allRepliesLoaded) {
      return
    }
    const estimatedTotal = this.estimateTotalReplies()
    if (estimatedTotal > DetailViewModel.PRELOAD_REPLY_LIMIT) {
      this.needsPreloadConfirm = true
    } else {
      this.preloadRemainingReplies()
    }
  }

  /**
   * Called when user switches to a thread mode after the topic is already loaded.
   * Triggers preloading remaining pages if not yet done.
   */
  async switchToThreadModeAndPreload(mode: string): Promise<void> {
    this.preloadFallbackToFlat = false
    this.setReplyDisplayMode(mode)
    if (!this.allRepliesLoaded && this.repliesHasMore) {
      await this.preloadRemainingReplies()
    }
  }

  confirmPreloadAll(): void {
    this.needsPreloadConfirm = false
    this.preloadRemainingReplies()
  }

  confirmPreloadFallbackFlat(): void {
    this.needsPreloadConfirm = false
    this.preloadFallbackToFlat = true
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

  optimisticallyMarkReplyThanked(replyId: number): ReplyThankSnapshot | null {
    if (replyId <= 0) {
      return null
    }
    let snapshot: ReplyThankSnapshot | null = null
    this.replies.forEach((reply: V2exReply) => {
      if (reply && reply.id === replyId) {
        if (snapshot === null) {
          snapshot = {
            replyId,
            previousThanks: Math.max(0, reply.thanks || 0),
            wasThanked: !!reply.thanked,
            previousRenderKey: reply.renderKey,
          }
        }
        if (!reply.thanked) {
          reply.thanks = Math.max(0, reply.thanks || 0) + 1
        }
        reply.thanked = true
        reply.renderKey = `${reply.renderKey || reply.id.toString()}-thanks-${reply.thanks}-me`
      }
    })
    if (snapshot !== null) {
      this.replyDataSource.setData(this.getVisibleReplies())
    }
    return snapshot
  }

  rollbackReplyThank(snapshot: ReplyThankSnapshot | null): void {
    if (!snapshot || snapshot.replyId <= 0) {
      return
    }
    let changed = false
    this.replies.forEach((reply: V2exReply) => {
      if (reply && reply.id === snapshot.replyId) {
        reply.thanks = snapshot.previousThanks
        reply.thanked = snapshot.wasThanked
        reply.renderKey = snapshot.previousRenderKey
        changed = true
      }
    })
    if (changed) {
      this.replyDataSource.setData(this.getVisibleReplies())
    }
  }

  markReplyThanked(replyId: number): void {
    if (replyId <= 0) {
      return
    }
    let changed = false
    this.replies.forEach((reply: V2exReply) => {
      if (reply && reply.id === replyId) {
        if (!reply.thanked) {
          reply.thanks = Math.max(0, reply.thanks || 0) + 1
        }
        reply.thanked = true
        reply.renderKey = `${reply.renderKey || reply.id.toString()}-thanks-${reply.thanks}-me`
        changed = true
      }
    })
    if (changed) {
      this.replyDataSource.setData(this.getVisibleReplies())
    }
  }

  setToken(token: string): void {
    this.authToken = token.trim()
  }

  setCacheHandlers(
    loader: () => Promise<TopicDetailCache | null>,
    saver: (topic: V2exTopic | null, replies: V2exReply[]) => Promise<void>,
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

  async load(forceNetwork: boolean = true): Promise<void> {
    if (this.topicId <= 0) {
      this.errorMessage = '无效的主题 ID'
      return
    }
    this.isLoading = true
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
    if (forceNetwork && this.topic === null) {
      this.replies = []
      this.replyDataSource.setData([])
      this.repliesLoaded = 0
    }
    this.repliesUseV2 = !!this.authToken
    this.repliesSource = this.authToken ? 'v2' : 'publicApi'
    this.repliesPage = 1
    this.repliesPageCount = 1
    this.repliesHasMore = false
    this.allRepliesLoaded = false
    this.isRepliesLoadingMore = false
    this.isBottomRefreshing = false
    this.failedRepliesPage = 0
    this.repliesLoadMoreState = 'endReached'
    try {
      let topic: V2exTopic | null = null
      let replies: V2exReply[] = []
      const cacheBuster = forceNetwork ? Date.now() : 0
      if (this.authToken) {
        const res = await this.apiV2.getTopic(this.authToken, this.topicId)
        topic = res.data
        const replyRes = await this.apiV2.getTopicReplies(this.authToken, this.topicId, 1)
        replies = replyRes.data || []
        this.repliesUseV2 = true
        this.repliesSource = 'v2'
        this.repliesHasMore = replies.length >= this.V2_REPLY_PAGE_SIZE
      } else {
        const topics = await this.api.getTopicById(this.topicId, cacheBuster)
        if (topics.length > 0) {
          topic = topics[0]
        }
        const apiReplies = await this.api.getReplies(this.topicId, cacheBuster)
        const webCookie = CookieJarSettings.getCurrentCookie()
        const firstPage = await this.api.getTopicWebRepliesPage(
          this.topicId,
          1,
          Date.now(),
          webCookie,
        )
        topic = this.mergeTopicSupplements(topic, firstPage.topicSupplementMarkdown || '')
        if (firstPage.replies.length > 0) {
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
      if (!this.repliesHasMore) {
        this.allRepliesLoaded = true
      }
      this.saveCache(this.topic, this.replies).catch((_e: Error) => {})
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
    if (
      this.isLoading ||
      this.isRepliesLoadingMore ||
      this.isBottomRefreshing ||
      !this.repliesHasMore
    ) {
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
        const snapshot: V2exTopicWebRepliesPage = await this.api.getTopicWebRepliesPage(
          this.topicId,
          nextPage,
          Date.now(),
          CookieJarSettings.getCurrentCookie(),
        )
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

  async preloadRemainingReplies(): Promise<void> {
    if (this.isPreloadingAll || this.allRepliesLoaded || this.isLoading) {
      return
    }
    this.isPreloadingAll = true
    this.preloadProgress = '正在加载全部回复…'
    try {
      if (this.repliesSource === 'publicWebPage') {
        await this.preloadWebReplies()
      } else if (this.repliesSource === 'v2') {
        await this.preloadV2Replies()
      }
      this.allRepliesLoaded = true
      this.repliesHasMore = false
      this.repliesLoadMoreState = 'endReached'
      this.replyDataSource.setData(this.getVisibleReplies())
      this.repliesLoaded = this.replies.length
      this.saveCache(this.topic, this.replies).catch((_e: Error) => {})
    } catch (error) {
      console.error('preload all replies failed:', (error as Error).message)
    } finally {
      this.isPreloadingAll = false
      this.preloadProgress = ''
    }
  }

  private async preloadWebReplies(): Promise<void> {
    const cookie = CookieJarSettings.getCurrentCookie()
    const result: V2exTopicWebRepliesAllResult = await this.api.getTopicWebRepliesAll(
      this.topicId,
      cookie,
      (loaded: number, total: number) => {
        this.preloadProgress = `正在加载全部回复 ${loaded}/${total}…`
      },
    )
    if (result.topicSupplementMarkdown) {
      this.topic = this.mergeTopicSupplements(this.topic, result.topicSupplementMarkdown)
    }
    this.replies = this.normalizeRepliesForRender(result.replies)
    this.repliesPage = result.pageCount
    this.repliesPageCount = result.pageCount
  }

  private async preloadV2Replies(): Promise<void> {
    let page = this.repliesPage + 1
    let hasMore = this.repliesHasMore
    while (hasMore) {
      this.preloadProgress = `正在加载全部回复 ${this.replies.length} 条…`
      const res = await this.apiV2.getTopicReplies(this.authToken, this.topicId, page)
      const items = res.data || []
      const unique = this.uniqueNewReplies(items)
      if (unique.length > 0) {
        this.replies = this.replies.concat(unique)
      }
      hasMore = items.length >= this.V2_REPLY_PAGE_SIZE
      this.repliesPage = page
      page++
    }
  }

  async retryLoadMoreReplies(): Promise<void> {
    if (this.repliesLoadMoreState !== 'loadMoreError' || this.failedRepliesPage <= 0) {
      return
    }
    await this.loadMoreReplies()
  }

  canBottomRefresh(): boolean {
    return (
      !this.isLoading &&
      !this.isRepliesLoadingMore &&
      !this.isBottomRefreshing &&
      this.repliesLoadMoreState === 'endReached' &&
      !this.repliesHasMore &&
      this.repliesPage >= 1
    )
  }

  shouldShowRepliesFooter(): boolean {
    return (
      this.repliesLoadMoreState === 'loadingMore' || this.repliesLoadMoreState === 'loadMoreError'
    )
  }

  private estimateTotalReplies(): number {
    if (this.topic && this.topic.replies > 0) {
      return this.topic.replies
    }
    return this.repliesPageCount * 100
  }

  async refreshLastRepliesPage(): Promise<void> {
    if (!this.canBottomRefresh()) {
      return
    }
    this.isBottomRefreshing = true
    try {
      let items: V2exReply[] = []
      if (this.repliesSource === 'v2') {
        const res = await this.apiV2.getTopicReplies(
          this.authToken,
          this.topicId,
          this.repliesPage,
          Date.now(),
        )
        items = res.data || []
      } else if (this.repliesSource === 'publicWebPage') {
        const snapshot = await this.api.getTopicWebRepliesPage(
          this.topicId,
          this.repliesPage,
          Date.now(),
          CookieJarSettings.getCurrentCookie(),
        )
        items = snapshot.replies
        this.repliesPageCount = snapshot.pageCount
        this.repliesHasMore = snapshot.hasMore
        if (snapshot.hasMore) {
          this.repliesLoadMoreState = 'idle'
        }
      } else {
        const snapshot = await this.api.getTopicWebRepliesPage(
          this.topicId,
          1,
          Date.now(),
          CookieJarSettings.getCurrentCookie(),
        )
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
    const existingIds = new Set<number>(this.replies.map((reply) => reply.id))
    return this.normalizeRepliesForRender(items).filter(
      (item: V2exReply) => item && item.id > 0 && !existingIds.has(item.id),
    )
  }

  private appendReplies(unique: V2exReply[]): void {
    if (unique.length === 0) {
      return
    }
    this.replies = this.replies.concat(unique)
    this.replyDataSource.setData(this.getVisibleReplies())
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

  private mergeTopicSupplements(
    topic: V2exTopic | null,
    supplementMarkdown: string,
  ): V2exTopic | null {
    const supplement = (supplementMarkdown || '').trim()
    if (!topic || supplement.length === 0) {
      return topic
    }
    const existing = (topic.topicSupplementMarkdown || '').trim()
    if (existing.indexOf(supplement) >= 0) {
      return topic
    }
    topic.topicSupplementMarkdown =
      existing.length > 0 ? `${existing}\n\n${supplement}` : supplement
    return topic
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
    reply.renderKey = `${reply.renderKey || reply.id.toString()}-${ReplyThreadCoordinator.replyStateKey(reply)}`
    return reply
  }

  private getVisibleReplies(): V2exReply[] {
    return ReplyThreadCoordinator.visibleReplies({
      displayMode: this.replyDisplayMode,
      onlyOp: this.onlyOp,
      preloadFallbackToFlat: this.preloadFallbackToFlat,
      topic: this.topic,
      replies: this.replies,
    })
  }
}
