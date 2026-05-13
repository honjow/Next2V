import { V2exTopic, V2exReply, ApiService, ApiV2Service, TopicDetailCache, HtmlEntityUtils, StorageKeys, ReplyDisplaySettings } from 'shared'
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
  replyDisplayMode: string = ReplyDisplaySettings.normalizeMode(
    AppStorage.get<string>(StorageKeys.REPLY_DISPLAY_MODE) ?? ReplyDisplaySettings.MODE_THREAD)
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
    this.replyDisplayMode = enabled ? ReplyDisplaySettings.MODE_OP : ReplyDisplaySettings.MODE_THREAD
    this.replyDataSource.setData(this.getVisibleReplies())
  }

  setReplyDisplayMode(mode: string): void {
    this.replyDisplayMode = ReplyDisplaySettings.normalizeMode(mode)
    this.onlyOp = this.replyDisplayMode === ReplyDisplaySettings.MODE_OP
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


  private prepareRepliesForThreading(): V2exReply[] {
    const prepared = this.replies.map((reply: V2exReply, index: number) => {
      reply.floor = index + 1
      reply.threadLevel = 0
      reply.isWrongReference = false
      reply.isDuplicateThreadItem = false
      reply.threadChildren = []
      reply.replyUsers = this.extractReplyUsers(reply.content, reply.content_rendered)
      reply.replyFloor = this.extractReplyFloor(reply.content, reply.content_rendered)
      reply.hiddenLeadingMentionContent = this.removeLeadingSingleMention(reply.content, reply.replyUsers || [], reply.replyFloor || -1)
      reply.relationLabel = this.replyRelationLabel(reply)
      reply.renderKey = `${this.replyDisplayMode}-r-${reply.id}`
      return reply
    })
    return prepared
  }

  private buildThreadedReplies(includeDuplicateOriginal: boolean, hideSingleMention: boolean): V2exReply[] {
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
      reply.renderKey = `${this.replyDisplayMode}-r-${reply.id}-t-${level}`
      if (hideSingleMention && level > 0 && (reply.replyUsers || []).length === 1 && (reply.hiddenLeadingMentionContent || '').trim()) {
        reply.renderKey = `${this.replyDisplayMode}-r-${reply.id}-t-${level}-compact`
      }
      const children = (childMap.get(reply.floor || 0) || []).sort((a: V2exReply, b: V2exReply) => (a.floor || 0) - (b.floor || 0))
      reply.threadChildren = children.map((child: V2exReply) => prepareNode(child, level + 1))
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
          dup.renderKey = `${this.replyDisplayMode}-r-${reply.id}-dup`
          duplicateList.push(dup)
        }
      })
      return result.concat(duplicateList.sort((a: V2exReply, b: V2exReply) => (a.floor || 0) - (b.floor || 0)))
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
      if (candidate && candidate.member && (candidate.member.username || '').toLowerCase() === targetUser) {
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
    const linkRe = /@?\s*<a\b[^>]*href=["'](?:https?:\/\/(?:www\.)?v2ex\.(?:com|co))?\/member\/([^"'?#\/]+)[^"']*["'][^>]*>/gi
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
    return (content || '').replace(re, '').trim()
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
      return this.prepareRepliesForThreading().filter(reply => reply.member.id === opId)
    }
    if (this.replyDisplayMode === ReplyDisplaySettings.MODE_ORIGIN) {
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
