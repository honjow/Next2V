import {
  V2exTopic,
  V2exReply,
  ApiService,
  ApiV2Service,
  TopicDetailCache,
  HtmlEntityUtils,
  connectReplyDisplay,
  ReplyDisplaySettings,
  CookieJarSettings,
  AppStrings,
  translateApiError,
  CacheMergeCoordinator,
  ReplyFingerprint,
  HotReplySettings,
} from 'shared'
import type { V2exTopicWebRepliesPage, V2exTopicWebRepliesAllResult, TopicDetailActionOverlay } from 'shared'
import { ReplyDataSource } from '../model/DetailModels'
import { HotReplyCoordinator } from '../model/HotReplyCoordinator'
import { ReplyThreadCoordinator } from '../model/ReplyThreadCoordinator'

export interface ReplyThankSnapshot {
  replyId: number
  previousThanks: number
  wasThanked: boolean
  previousRenderKey?: string
}

/**
 * Topic detail page ViewModel
 */
// @ObservedV2: its only consumer, TopicDetailPage, is now a @ComponentV2 holding it via @Local.
// @Trace marks exactly the fields read inside the page's build() / @Builders — that read is the
// V2 subscription point (a non-@Trace mutation would leave the page stale, e.g. the topic body /
// loading spinner never appearing). replyDataSource is intentionally NOT @Trace: LazyForEach
// subscribes to it through its own DataChangeListener, independent of @ObservedV2.
@ObservedV2
export class DetailViewModel {
  @Trace topic: V2exTopic | null = null
  replyDataSource: ReplyDataSource = new ReplyDataSource()
  @Trace isLoading: boolean = false
  onlyOp: boolean = false
  @Trace replyDisplayMode: string = ReplyDisplaySettings.normalizeMode(connectReplyDisplay().mode)
  repliesUseV2: boolean = false
  repliesPage: number = 1
  @Trace repliesHasMore: boolean = false
  @Trace isRepliesLoadingMore: boolean = false
  @Trace repliesLoaded: number = 0
  @Trace hotReplyCandidates: V2exReply[] = []
  @Trace repliesLoadMoreState: string = 'endReached'
  loadMoreErrorMessage: string = ''
  isBottomRefreshing: boolean = false
  @Trace errorMessage: string = ''
  topicId: number = 0
  @Trace isPreloadingAll: boolean = false
  @Trace preloadProgress: string = ''
  needsPreloadConfirm: boolean = false
  private preloadFallbackToFlat: boolean = false

  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private authToken: string = ''
  private replies: V2exReply[] = []
  private cacheLoader: (() => Promise<TopicDetailCache | null>) | null = null
  private cacheSaver: ((topic: V2exTopic | null, replies: V2exReply[]) => Promise<void>) | null =
    null
  private actionOverlay: TopicDetailActionOverlay | null = null
  private repliesSource: string = 'publicApi'
  private repliesPageCount: number = 1
  private failedRepliesPage: number = 0
  private readonly V2_REPLY_PAGE_SIZE: number = 20
  allRepliesLoaded: boolean = false
  private static readonly PRELOAD_REPLY_LIMIT: number = 500
  // When a full reload runs while a complete thread is already on screen (cache-backed re-entry,
  // post-reply refetch), publishing the intermediate page-1 state would visibly collapse the
  // threaded list before preload re-expands it. load() then holds the replies publish (internal
  // state only) and the follow-up preload performs ONE publish — LazyForEach reuses items whose
  // renderKey is unchanged, so only new/changed nodes rebuild instead of the whole tree.
  private heldRepliesPublish: boolean = false
  // Chronological reply list as last pushed to the data source. While a publish is held, internal
  // this.replies (fresh page-1) deliberately diverges from the on-screen rows, so UI floor lookups
  // must resolve here — a floor computed from internal state would be wrong for rows materialized
  // mid-hold and then frozen into reused LazyForEach nodes by the final publish (renderKey carries
  // no floor). Outside the held window this is the same array reference as this.replies.
  private publishedReplies: V2exReply[] = []
  // In-flight preload-all, exposed so a racing loadMoreReplies/load() can join it instead of
  // fetching duplicate pages or publishing partial state underneath it.
  private preloadAllPromise: Promise<void> | null = null

  constructor(topicId: number) {
    this.topicId = topicId
  }

  setOnlyOp(enabled: boolean): void {
    this.onlyOp = enabled
    this.replyDisplayMode = enabled
      ? ReplyDisplaySettings.MODE_OP
      : ReplyDisplaySettings.MODE_THREAD
    this.publishVisibleReplies()
  }

  setReplyDisplayMode(mode: string): void {
    this.replyDisplayMode = ReplyDisplaySettings.normalizeMode(mode)
    this.onlyOp = this.replyDisplayMode === ReplyDisplaySettings.MODE_OP
    this.publishVisibleReplies()
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
  triggerThreadPreloadIfNeeded(hotRepliesEnabled: boolean = false): void {
    if ((!this.isThreadMode() && !hotRepliesEnabled) || !this.repliesHasMore || this.allRepliesLoaded) {
      this.flushHeldRepliesPublish()
      return
    }
    const estimatedTotal = this.estimateTotalReplies()
    if (estimatedTotal > DetailViewModel.PRELOAD_REPLY_LIMIT) {
      this.needsPreloadConfirm = true
      this.flushHeldRepliesPublish()
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
    this.publishVisibleReplies()
  }

  getReplyFloor(replyId: number): number {
    if (replyId <= 0) {
      return 0
    }
    // Floors are a pure UI-position concept: resolve against what is on screen (publishedReplies),
    // never the internal list, or held-window lookups would mislabel visible rows.
    for (let i = 0; i < this.publishedReplies.length; i++) {
      if (this.publishedReplies[i].id === replyId) {
        return i + 1
      }
    }
    return 0
  }

  getLoadedRepliesSnapshot(): V2exReply[] {
    return this.replies.slice()
  }

  getHotReplies(enabled: boolean, maxCount: number, minThanks: number): V2exReply[] {
    if (!enabled) {
      return []
    }
    return HotReplyCoordinator.filterCandidates(this.hotReplyCandidates, maxCount, minThanks)
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
    // While a reload holds the publish, the data source still shows the old full thread and
    // this.replies is the fresh page-1 — pushing it here would collapse the list. Mutate internal
    // state only; the preload's final publish (which re-merges the action overlay) carries the
    // thank state out, and the page-level highlight covers the interim frames.
    if (snapshot !== null) {
      this.syncHotReplyCandidateFromLoadedReply(replyId)
      if (!this.heldRepliesPublish) {
        this.publishVisibleReplies()
      }
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
      this.syncHotReplyCandidateSnapshot(snapshot)
      if (!this.heldRepliesPublish) {
        this.publishVisibleReplies()
      }
    }
  }

  private syncHotReplyCandidateFromLoadedReply(replyId: number): void {
    const reply = this.findLoadedReply(replyId)
    if (reply) {
      this.syncHotReplyCandidateValues(reply.id, reply.thanks || 0, !!reply.thanked, reply.renderKey)
    }
  }

  private syncHotReplyCandidateSnapshot(snapshot: ReplyThankSnapshot): void {
    this.syncHotReplyCandidateValues(
      snapshot.replyId,
      snapshot.previousThanks,
      snapshot.wasThanked,
      snapshot.previousRenderKey,
    )
  }

  private findLoadedReply(replyId: number): V2exReply | null {
    if (replyId <= 0) {
      return null
    }
    for (let i = 0; i < this.replies.length; i++) {
      const reply = this.replies[i]
      if (reply && reply.id === replyId) {
        return reply
      }
    }
    return null
  }

  private syncHotReplyCandidateValues(
    replyId: number,
    thanks: number,
    thanked: boolean,
    renderKey?: string,
  ): void {
    if (replyId <= 0 || this.hotReplyCandidates.length === 0) {
      return
    }
    const next: V2exReply[] = []
    let changed = false
    for (let i = 0; i < this.hotReplyCandidates.length; i++) {
      const candidate = JSON.parse(JSON.stringify(this.hotReplyCandidates[i])) as V2exReply
      if (this.syncHotReplyCandidateTree(candidate, replyId, thanks, thanked, renderKey)) {
        changed = true
      }
      next.push(candidate)
    }
    if (changed) {
      this.hotReplyCandidates = next
    }
  }

  private syncHotReplyCandidateTree(
    reply: V2exReply,
    replyId: number,
    thanks: number,
    thanked: boolean,
    renderKey?: string,
  ): boolean {
    let changed = false
    if (reply && reply.id === replyId) {
      reply.thanks = Math.max(0, thanks || 0)
      reply.thanked = thanked
      const baseRenderKey = renderKey || reply.renderKey || reply.id.toString()
      reply.renderKey = `${baseRenderKey}-hot-thanks-${reply.thanks}`
      changed = true
    }
    const children = reply.threadChildren || []
    for (let i = 0; i < children.length; i++) {
      if (this.syncHotReplyCandidateTree(children[i], replyId, thanks, thanked, renderKey)) {
        changed = true
      }
    }
    return changed
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
      this.syncHotReplyCandidateFromLoadedReply(replyId)
      if (!this.heldRepliesPublish) {
        this.publishVisibleReplies()
      }
    }
  }

  setToken(token: string): void {
    this.authToken = token.trim()
  }

  setTopicActionOverlay(overlay: TopicDetailActionOverlay | null): void {
    this.actionOverlay = overlay
    if (this.topic === null && this.replies.length === 0) {
      return
    }
    if (this.heldRepliesPublish) {
      // Post-thank/favorite overlay refreshes land mid-hold all the time (the chain is async);
      // re-merge internally and let the preload's final publish carry the overlay out instead of
      // pushing the page-1 list and collapsing the on-screen thread.
      this.applyMergedTopicDetail(this.topic, this.replies)
    } else {
      this.publishMergedTopicDetail(this.topic, this.replies)
    }
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
      this.publishMergedTopicDetail(
        this.normalizeTopicForRender(cached.topic),
        this.normalizeRepliesForRender(cached.replies),
      )
    } catch (error) {
      console.error('load topic cache failed:', (error as Error).message)
    }
  }

  async load(forceNetwork: boolean = true): Promise<void> {
    if (this.topicId <= 0) {
      this.errorMessage = AppStrings.text($r('app.string.api_error_invalid_topic_id'), 'Invalid topic ID')
      return
    }
    if (this.isPreloadingAll) {
      // A reload racing the in-flight preload-all either eager-publishes a page-1 collapse that
      // sticks (the preload's completion flips allRepliesLoaded mid-reload, so the follow-up
      // trigger skips re-preloading) or gets its fresh tail wholesale-overwritten by the older
      // preload fetch. Serialize behind the preload so the reload starts from a settled state.
      const inFlight = this.preloadAllPromise
      if (inFlight !== null) {
        await inFlight
      }
    }
    this.isLoading = true
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
    if (forceNetwork && this.topic === null) {
      this.replies = []
      this.publishVisibleReplies()
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
          const apiReplies = await this.api.getReplies(this.topicId, cacheBuster)
          replies = apiReplies
          this.repliesSource = 'publicApi'
          this.repliesHasMore = false
        }
        this.repliesUseV2 = false
      }

      this.applyMergedTopicDetail(
        this.normalizeTopicForRender(topic),
        this.normalizeRepliesForRender(replies),
      )
      if (this.shouldHoldRepliesPublish()) {
        // Keep the on-screen full thread (and its repliesLoaded count) untouched; the preload
        // that the page triggers right after load() resolves performs the single real publish.
        this.heldRepliesPublish = true
      } else {
        this.publishVisibleReplies()
      }
      this.repliesLoadMoreState = this.repliesHasMore ? 'idle' : 'endReached'
      if (!this.repliesHasMore) {
        this.allRepliesLoaded = true
      }
      this.saveCache(this.topic, this.replies).catch((_e: Error) => {})
    } catch (error) {
      const e = error as Error
      this.errorMessage = translateApiError(e)
      await this.loadCachedData()
      console.error('Failed to load topic detail:', e.message)
    } finally {
      this.isLoading = false
    }
  }

  async loadMoreReplies(): Promise<void> {
    if (this.isPreloadingAll) {
      // While preload-all is fetching every page, an incremental fetch would duplicate pages and —
      // during a held publish — push a partial list that collapses the on-screen thread. Join the
      // in-flight preload instead of silently no-opping: floor-targeting loops
      // (ensureRepliesLoaded) rely on each loadMoreReplies call making real progress, and the
      // preload's single publish satisfies them with the full list in one await.
      const inFlight = this.preloadAllPromise
      if (inFlight !== null) {
        await inFlight
      }
      return
    }
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
      this.loadMoreErrorMessage = e.message || AppStrings.text($r('app.string.load_more_replies_failed'), 'Load more failed')
      this.failedRepliesPage = nextPage
      this.repliesLoadMoreState = 'loadMoreError'
    } finally {
      this.isRepliesLoadingMore = false
    }
  }

  async loadMoreRepliesV2(): Promise<void> {
    await this.loadMoreReplies()
  }

  // Notification floor repair needs the *target* reply present before it can match by content, but
  // V2EX's #reply anchor is unreliable and the reply can sit on any page — including pages the cookie
  // (web) path never auto-loads up front and that thread-preload only fetches asynchronously, after the
  // jump has already run. So when a verify text is in play, drive loading until that reply appears
  // (joining any in-flight preload first to avoid duplicate fetches), stopping as soon as it is found.
  async loadUntilReplyContent(verifyReplyText: string): Promise<void> {
    const verify = (verifyReplyText || '').trim()
    if (!verify) {
      return
    }
    const inFlight = this.preloadAllPromise
    if (inFlight !== null) {
      try {
        await inFlight
      } catch (_e) {
        // fall through to incremental loading
      }
    }
    let guard = 0
    while (
      !this.loadedRepliesContainContent(verify) &&
      this.repliesHasMore &&
      !this.allRepliesLoaded &&
      guard < 30
    ) {
      guard++
      await this.loadMoreReplies()
    }
  }

  private loadedRepliesContainContent(verify: string): boolean {
    for (let i = 0; i < this.replies.length; i++) {
      const reply = this.replies[i]
      if (reply && ReplyFingerprint.matches(reply.content || reply.content_rendered || '', verify)) {
        return true
      }
    }
    return false
  }

  preloadRemainingReplies(): Promise<void> {
    if (this.isPreloadingAll || this.allRepliesLoaded || this.isLoading) {
      // Already running (or nothing to do): hand back the in-flight run so callers can join it.
      const inFlight = this.preloadAllPromise
      return inFlight !== null ? inFlight : Promise.resolve()
    }
    const run = this.runPreloadRemainingReplies()
    this.preloadAllPromise = run
    return run
  }

  private async runPreloadRemainingReplies(): Promise<void> {
    this.isPreloadingAll = true
    this.preloadProgress = AppStrings.text($r('app.string.preloading_all_replies'), 'Loading all replies…')
    try {
      if (this.repliesSource === 'publicWebPage') {
        await this.preloadWebReplies()
      } else if (this.repliesSource === 'v2') {
        await this.preloadV2Replies()
      }
      this.allRepliesLoaded = true
      this.repliesHasMore = false
      this.repliesLoadMoreState = 'endReached'
      this.publishMergedTopicDetail(this.topic, this.replies)
      this.saveCache(this.topic, this.replies).catch((_e: Error) => {})
    } catch (error) {
      console.error('preload all replies failed:', (error as Error).message)
    } finally {
      // On success the publish above already cleared the held flag; on failure this pushes the
      // held page-1 state out so the UI matches this.replies instead of staying on stale data.
      this.flushHeldRepliesPublish()
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
        this.preloadProgress = AppStrings.format(AppStrings.text($r('app.string.preloading_progress_format'), 'Loading all replies {0}/{1}…'), [`${loaded}`, `${total}`])
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
      this.preloadProgress = AppStrings.format(AppStrings.text($r('app.string.preloading_progress_count_format'), 'Loading all replies {0} items…'), [`${this.replies.length}`])
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
    this.publishMergedTopicDetail(this.topic, this.replies.concat(unique))
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

  // Cached and network replacements use one application point so user-action overlays are applied
  // before the topic/reply data sources can render a default false/empty first frame. Does NOT
  // push to replyDataSource — load() uses it alone when holding the publish for a follow-up preload.
  private applyMergedTopicDetail(topic: V2exTopic | null, replies: V2exReply[]): void {
    const merged = CacheMergeCoordinator.mergeTopicDetail(topic, replies, this.actionOverlay)
    this.topic = merged.topic
    this.replies = merged.replies
  }

  private publishMergedTopicDetail(topic: V2exTopic | null, replies: V2exReply[]): void {
    this.applyMergedTopicDetail(topic, replies)
    this.publishVisibleReplies()
  }

  // Single chokepoint for pushing the visible list into the LazyForEach data source: any publish
  // brings the on-screen list, the floor-lookup snapshot, and the loaded-count text back in sync
  // with this.replies, so the held flag must clear here.
  private publishVisibleReplies(): void {
    this.heldRepliesPublish = false
    this.publishedReplies = this.replies
    const visibleReplies = this.getVisibleReplies()
    this.refreshHotReplyCandidates()
    this.replyDataSource.setData(visibleReplies)
    this.repliesLoaded = this.replies.length
  }

  private refreshHotReplyCandidates(): void {
    this.hotReplyCandidates = HotReplyCoordinator.select(
      this.replies,
      this.topic,
      true,
      HotReplySettings.MAX_MAX_COUNT,
      HotReplySettings.MIN_THANKS,
    )
  }

  // Safety net: if a held page-1 publish never got superseded by a preload publish (preload
  // failed, mode flipped, preconditions changed), push the internal state out so the UI never
  // stays permanently stale relative to this.replies.
  private flushHeldRepliesPublish(): void {
    if (!this.heldRepliesPublish) {
      return
    }
    this.publishVisibleReplies()
  }

  // Mirrors the auto-preload branch of triggerThreadPreloadIfNeeded(): hold the page-1 publish
  // only when the follow-up preload is guaranteed to run unattended and publish the full list.
  // Over-limit topics keep the eager publish because preload waits on the user's confirm dialog.
  private shouldHoldRepliesPublish(): boolean {
    return (
      this.replyDataSource.totalCount() > 0 &&
      this.isThreadMode() &&
      this.repliesHasMore &&
      !this.allRepliesLoaded &&
      this.estimateTotalReplies() <= DetailViewModel.PRELOAD_REPLY_LIMIT
    )
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
