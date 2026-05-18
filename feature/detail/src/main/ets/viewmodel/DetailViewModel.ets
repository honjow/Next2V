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
    reply.renderKey = `${reply.renderKey || reply.id.toString()}-${this.replyStateKey(reply)}`
    return reply
  }

  private replyStateKey(reply: V2exReply): string {
    return `thanks-${reply.thanks || 0}-${reply.thanked ? 'me' : 'other'}`
  }

  private childrenThankKey(children: V2exReply[]): string {
    if (children.length === 0) {
      return ''
    }
    const parts = children.map((c: V2exReply) => {
      const sub = this.childrenThankKey(c.threadChildren || [])
      return `${c.id}${c.thanked ? 't' : 'f'}${c.thanks || 0}${sub}`
    })
    return `-ch(${parts.join(',')})`
  }

  private prepareRepliesForThreading(): V2exReply[] {
    const prepared = this.replies.map((reply: V2exReply, index: number) => {
      reply.floor = index + 1
      reply.threadLevel = 0
      reply.isWrongReference = false
      reply.isDuplicateThreadItem = false
      reply.threadChildren = []
      reply.replyUsers = this.extractReplyUsers(reply.content, reply.content_rendered)
      reply.replyFloor = this.extractReplyFloor(reply.content, reply.content_rendered)
      reply.hiddenLeadingMentionContent = this.removeLeadingSingleMention(
        reply.content,
        reply.replyUsers || [],
        reply.replyFloor || -1,
      )
      reply.hiddenLeadingMentionRenderedContent = this.removeLeadingSingleMentionRendered(
        reply.content_rendered,
        reply.replyUsers || [],
        reply.replyFloor || -1,
      )
      reply.relationLabel = this.replyRelationLabel(reply)
      reply.renderKey = `${this.replyDisplayMode}-r-${reply.id}-${this.replyStateKey(reply)}`
      return reply
    })
    return prepared
  }

  private buildThreadedReplies(
    includeDuplicateOriginal: boolean,
    hideSingleMention: boolean,
  ): V2exReply[] {
    const base = this.prepareRepliesForThreading()
    const byFloor = new Map<number, V2exReply>()
    const childMap = new Map<number, V2exReply[]>()
    const parentFloorById = new Map<number, number>()
    base.forEach((reply: V2exReply) => {
      byFloor.set(reply.floor || 0, reply)
      childMap.set(reply.floor || 0, [])
    })

    base.forEach((reply: V2exReply) => {
      const parentFloor = this.findThreadParentFloor(reply, byFloor)
      if (parentFloor > 0 && parentFloor < (reply.floor || 0)) {
        const children = childMap.get(parentFloor) || []
        children.push(reply)
        childMap.set(parentFloor, children)
        parentFloorById.set(reply.id, parentFloor)
      }
    })

    const result: V2exReply[] = []
    const prepareNode = (reply: V2exReply, level: number): V2exReply => {
      reply.threadLevel = level
      reply.isDuplicateThreadItem = false
      reply.threadChildren = []
      const children = (childMap.get(reply.floor || 0) || []).sort(
        (a: V2exReply, b: V2exReply) => (a.floor || 0) - (b.floor || 0),
      )
      reply.threadChildren = children.map((child: V2exReply) => prepareNode(child, level + 1))
      const childSummary = this.childrenThankKey(reply.threadChildren)
      const compactTag =
        hideSingleMention &&
        level > 0 &&
        (reply.replyUsers || []).length === 1 &&
        (reply.hiddenLeadingMentionContent || '').trim()
          ? '-compact'
          : ''
      reply.renderKey = `${this.replyDisplayMode}-r-${reply.id}-t-${level}${compactTag}-${this.replyStateKey(reply)}${childSummary}`
      return reply
    }

    base.forEach((reply: V2exReply) => {
      if (!parentFloorById.has(reply.id)) {
        result.push(prepareNode(reply, 0))
      }
    })

    if (includeDuplicateOriginal) {
      const duplicateList: V2exReply[] = []
      base.forEach((reply: V2exReply) => {
        if (parentFloorById.has(reply.id)) {
          const dup = this.cloneReplyForDisplay(reply)
          dup.threadLevel = 0
          dup.threadChildren = []
          dup.isDuplicateThreadItem = true
          dup.renderKey = `${this.replyDisplayMode}-r-${reply.id}-dup-${this.replyStateKey(reply)}`
          duplicateList.push(dup)
        }
      })
      return result.concat(
        duplicateList.sort((a: V2exReply, b: V2exReply) => (a.floor || 0) - (b.floor || 0)),
      )
    }
    return result
  }

  private cloneReplyForDisplay(reply: V2exReply): V2exReply {
    return JSON.parse(JSON.stringify(reply)) as V2exReply
  }

  private findThreadParentFloor(reply: V2exReply, byFloor: Map<number, V2exReply>): number {
    const floor = reply.floor || 0
    const users = reply.replyUsers || []
    const replyFloor = reply.replyFloor || -1
    if (floor <= 1 || users.length === 0) {
      return 0
    }
    if (replyFloor > 0 && replyFloor < floor) {
      const target = byFloor.get(replyFloor)
      if (!target || !target.member) {
        reply.isWrongReference = true
        return 0
      }
      const targetName = (target.member.username || '').toLowerCase()
      const mentioned = users.some((name: string) => name.toLowerCase() === targetName)
      if (mentioned) {
        return replyFloor
      }
      reply.isWrongReference = true
      return 0
    }
    if (users.length !== 1) {
      return 0
    }
    const targetUser = users[0].toLowerCase()
    for (let i = floor - 1; i >= 1; i--) {
      const candidate = byFloor.get(i)
      if (
        candidate &&
        candidate.member &&
        (candidate.member.username || '').toLowerCase() === targetUser
      ) {
        return i
      }
    }
    return 0
  }

  private extractReplyUsers(content: string, renderedContent: string): string[] {
    const names: string[] = []
    const seen = new Set<string>()
    const addName = (name: string): void => {
      const clean = (name || '').trim()
      const key = clean.toLowerCase()
      if (clean && !seen.has(key)) {
        seen.add(key)
        names.push(clean)
      }
    }
    const rendered = renderedContent || content || ''
    const linkRe =
      /@?\s*<a\b[^>]*href=["'](?:https?:\/\/(?:www\.)?v2ex\.(?:com|co))?\/member\/([^"'?#\/]+)[^"']*["'][^>]*>/gi
    let linkMatch: RegExpExecArray | null = linkRe.exec(rendered)
    while (linkMatch) {
      addName(HtmlEntityUtils.decode(linkMatch[1] || ''))
      linkMatch = linkRe.exec(rendered)
    }
    if (names.length > 0) {
      return names
    }
    const raw = content || ''
    const re = /@([0-9A-Za-z_]{2,32})/g
    let m: RegExpExecArray | null = re.exec(raw)
    while (m) {
      addName(m[1] || '')
      m = re.exec(raw)
    }
    return names
  }

  private extractReplyFloor(content: string, renderedContent: string): number {
    const source = `${renderedContent || ''} ${content || ''}`
    const m = source.match(/(?:^|\s)#(\d{1,5})(?:\s|<|$)/)
    if (!m || !m[1]) {
      return -1
    }
    const floor = Number.parseInt(m[1])
    return Number.isNaN(floor) ? -1 : floor
  }

  private removeLeadingSingleMention(content: string, users: string[], replyFloor: number): string {
    if (users.length !== 1) {
      return content
    }
    const name = users[0]
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const floorPart = replyFloor > 0 ? `\\s*#${replyFloor}` : '(?:\\s*#\\d+)?'
    const re = new RegExp(`^\\s*@${escaped}${floorPart}\\s*`, 'i')
    const markdownLinkRe = new RegExp(
      `^\\s*\\[@?${escaped}\\]\\((?:https?:\\/\\/(?:www\\.)?v2ex\\.(?:com|co))?\\/member\\/${escaped}(?:[?#][^)]*)?\\)${floorPart}\\s*`,
      'i',
    )
    return (content || '').replace(markdownLinkRe, '').replace(re, '').trim()
  }

  private removeLeadingSingleMentionRendered(contentRendered: string, users: string[], replyFloor: number): string {
    if (users.length !== 1) {
      return ''
    }
    const source = (contentRendered || '').trim()
    if (!source) {
      return ''
    }
    const direct = this.stripLeadingSingleMentionRenderedBody(source, users[0], replyFloor)
    if (direct !== source) {
      return direct.trim()
    }

    const paragraphMatch = source.match(/^(\s*<p\b[^>]*>)([\s\S]*)(<\/p>\s*)$/i)
    if (paragraphMatch) {
      const opening = paragraphMatch[1] || ''
      const body = paragraphMatch[2] || ''
      const closing = paragraphMatch[3] || ''
      const strippedBody = this.stripLeadingSingleMentionRenderedBody(body, users[0], replyFloor)
      if (strippedBody !== body) {
        return `${opening}${strippedBody.trimStart()}${closing}`.trim()
      }
    }

    return ''
  }

  private stripLeadingSingleMentionRenderedBody(contentRendered: string, username: string, replyFloor: number): string {
    const name = username
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const htmlSpace = '(?:\\s|&nbsp;|&#160;|&#xa0;)*'
    const floorPart = replyFloor > 0 ? `${htmlSpace}#${replyFloor}` : `(?:${htmlSpace}#\\d+)?`
    const memberHref = `(?:https?:\\/\\/(?:www\\.)?v2ex\\.(?:com|co))?\\/member\\/${escaped}(?:[?#][^"']*)?`
    const renderedMentionRe = new RegExp(
      `^${htmlSpace}@?${htmlSpace}<a\\b(?=[^>]*href=["']${memberHref}["'])[^>]*>${htmlSpace}@?${escaped}${htmlSpace}<\\/a>${floorPart}${htmlSpace}`,
      'i',
    )
    return (contentRendered || '').replace(renderedMentionRe, '')
  }

  private replyRelationLabel(reply: V2exReply): string {
    const users = reply.replyUsers || []
    const floor = reply.replyFloor || -1
    if (users.length === 0 && floor <= 0) {
      return ''
    }
    const mention = users.length > 0 ? users.map((name: string) => `@${name}`).join(' ') : ''
    const floorText = floor > 0 ? `#${floor}` : ''
    return `回复 ${mention}${mention && floorText ? ' · ' : ''}${floorText}`.trim()
  }

  private getVisibleReplies(): V2exReply[] {
    if (this.replyDisplayMode === ReplyDisplaySettings.MODE_OP || this.onlyOp) {
      const opId = this.topic ? this.topic.member.id : 0
      if (opId <= 0) {
        return this.prepareRepliesForThreading()
      }
      return this.prepareRepliesForThreading().filter((reply) => reply.member.id === opId)
    }
    if (this.replyDisplayMode === ReplyDisplaySettings.MODE_ORIGIN || this.preloadFallbackToFlat) {
      return this.prepareRepliesForThreading()
    }
    if (this.replyDisplayMode === ReplyDisplaySettings.MODE_THREAD_REDUNDANT) {
      return this.buildThreadedReplies(true, false)
    }
    if (this.replyDisplayMode === ReplyDisplaySettings.MODE_THREAD_WITH_MENTION) {
      return this.buildThreadedReplies(false, false)
    }
    return this.buildThreadedReplies(false, true)
  }
}
