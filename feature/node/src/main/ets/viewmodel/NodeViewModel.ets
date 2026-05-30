import { V2exNode, V2exTopic, ApiService, ApiV2Service, DiagnosticLogger, translateApiError } from 'shared'

export type NodeTopicPageOneSource = 'api_v2' | 'web'

export interface NodeTopicPageOneLoadOptions {
  requestId?: number
  source?: NodeTopicPageOneSource
  fallback?: boolean
}

/**
 * Single-node topic-feed ViewModel (the node-topics half of the former monolithic
 * NodeViewModel). `@ObservedV2`: its only consumer, `NodeTopicPage`, is now a `@ComponentV2`
 * that holds it via `@Local`. The `@Trace` fields are exactly those read inside the page's
 * `build()` / `@Builder`s — marking them is the subscription point (a non-`@Trace` field would
 * leave the list stuck on its initial render after async load → loading-stuck regression).
 * The remaining fields (`nodeDetail*`, pagination cursors) are read only in event handlers, so
 * they stay plain.
 *
 * The node directory/search half lives separately in `NodeIndexViewModel` (`@ObservedV2`),
 * consumed by the migrated `NodePickerPage` / `DiscoverPage`.
 */
@ObservedV2
export class NodeViewModel {
  @Trace nodeTopics: V2exTopic[] = []
  nodeDetail: V2exNode | null = null
  nodeDetailError: string = ''
  nodeTopicsUseV2: boolean = false
  nodeTopicsPage: number = 1
  @Trace nodeTopicsHasMore: boolean = true
  @Trace isNodeTopicsLoadingMore: boolean = false
  @Trace nodeTopicsLoadMoreError: string = ''
  @Trace isLoading: boolean = false
  @Trace errorMessage: string = ''

  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private readonly V2_PAGE_SIZE: number = 10
  private activeNodeTopicsRequestId: number = 0
  private activeNodeTopicsNodeName: string = ''
  private activeNodeTopicsSource: string = ''
  private nodeTopicsPageOneSettled: boolean = false
  private nodeTopicsPageOnePublished: boolean = false

  beginNodeTopicsPageOneLoad(nodeName: string, source: NodeTopicPageOneSource, requestId: number): void {
    this.activeNodeTopicsRequestId = requestId
    this.activeNodeTopicsNodeName = (nodeName || '').trim()
    this.activeNodeTopicsSource = source
    this.nodeTopicsPageOneSettled = false
    this.nodeTopicsPageOnePublished = false
    this.nodeTopicsLoadMoreError = ''
  }

  switchNodeTopicsPageOneSource(nodeName: string, source: NodeTopicPageOneSource, requestId: number): boolean {
    if (!this.isCurrentNodeTopicsRequest(nodeName, requestId) || this.nodeTopicsPageOnePublished) {
      this.logNodeTopicPublishIgnored(nodeName, source, requestId, 1, 0, 'fallback_after_publish')
      return false
    }
    this.activeNodeTopicsSource = source
    return true
  }

  hasNodeTopicsPageOneSettled(): boolean {
    return this.nodeTopicsPageOneSettled
  }

  private isCurrentNodeTopicsRequest(nodeName: string, requestId: number): boolean {
    return requestId <= 0 || (this.activeNodeTopicsRequestId === requestId && this.activeNodeTopicsNodeName === (nodeName || '').trim())
  }

  private shouldPublishNodeTopicsPageOne(
    nodeName: string,
    source: NodeTopicPageOneSource,
    requestId: number,
    page: number,
    count: number,
    fallback: boolean = false
  ): boolean {
    if (requestId <= 0) {
      return true
    }
    if (!this.isCurrentNodeTopicsRequest(nodeName, requestId)) {
      this.logNodeTopicPublishIgnored(nodeName, source, requestId, page, count, 'stale_request')
      return false
    }
    if (this.activeNodeTopicsSource !== source) {
      this.logNodeTopicPublishIgnored(nodeName, source, requestId, page, count, 'losing_source')
      return false
    }
    if (this.nodeTopicsPageOnePublished && fallback) {
      this.logNodeTopicPublishIgnored(nodeName, source, requestId, page, count, 'fallback_after_publish')
      return false
    }
    return true
  }

  private publishNodeTopicsPageOne(
    nodeName: string,
    source: NodeTopicPageOneSource,
    requestId: number,
    topics: V2exTopic[],
    hasMore: boolean
  ): void {
    this.nodeTopics = topics
    this.nodeTopicsHasMore = hasMore
    this.nodeTopicsPageOnePublished = true
    this.nodeTopicsPageOneSettled = true
    DiagnosticLogger.info('ui_lifecycle', 'node_topic_source_success', {
      nodeName: (nodeName || '').trim(),
      source: source,
      page: 1,
      requestId: requestId,
      count: topics.length,
      firstIds: this.firstTopicIds(topics)
    })
  }

  private markNodeTopicsPageOneFailed(
    nodeName: string,
    source: NodeTopicPageOneSource,
    requestId: number,
    error: Error
  ): void {
    if (this.isCurrentNodeTopicsRequest(nodeName, requestId) && this.activeNodeTopicsSource === source && !this.nodeTopicsPageOnePublished) {
      this.nodeTopicsPageOneSettled = true
    }
    DiagnosticLogger.warn('ui_lifecycle', 'node_topic_source_fail', {
      nodeName: (nodeName || '').trim(),
      source: source,
      page: 1,
      requestId: requestId,
      count: 0,
      firstIds: [],
      errorKind: error.name || 'Error'
    }, error)
  }

  private logNodeTopicPublishIgnored(
    nodeName: string,
    source: NodeTopicPageOneSource,
    requestId: number,
    page: number,
    count: number,
    reason: string
  ): void {
    DiagnosticLogger.info('ui_lifecycle', 'node_topic_publish_ignored', {
      nodeName: (nodeName || '').trim(),
      source: source,
      page: page,
      requestId: requestId,
      count: count,
      firstIds: [],
      reason: reason,
      activeRequestId: this.activeNodeTopicsRequestId,
      activeSource: this.activeNodeTopicsSource
    })
  }

  private firstTopicIds(topics: V2exTopic[]): number[] {
    const ids: number[] = []
    const total = Math.min(3, topics.length)
    for (let i = 0; i < total; i++) {
      ids.push(topics[i].id)
    }
    return ids
  }

  /** Load topics under the specified node */
  async loadNodeTopics(nodeName: string, options?: NodeTopicPageOneLoadOptions): Promise<boolean> {
    const loadOptions = options || {}
    const requestId = loadOptions.requestId || 0
    const source: NodeTopicPageOneSource = loadOptions.source || 'web'
    this.isLoading = true
    this.errorMessage = ''
    this.nodeTopicsUseV2 = false
    this.nodeTopicsPage = 1
    this.nodeTopicsHasMore = true
    this.nodeTopicsLoadMoreError = ''
    try {
      const snapshot = await this.api.getNodeTopicsPage(nodeName, 1)
      if (!this.shouldPublishNodeTopicsPageOne(nodeName, source, requestId, 1, snapshot.topics.length, loadOptions.fallback === true)) {
        return false
      }
      this.publishNodeTopicsPageOne(nodeName, source, requestId, snapshot.topics, snapshot.hasMore)
      return true
    } catch (error) {
      const e = error as Error
      this.errorMessage = translateApiError(error)
      this.markNodeTopicsPageOneFailed(nodeName, source, requestId, e)
      console.error('Failed to load node topics:', e.message)
      return false
    } finally {
      this.isLoading = false
    }
  }

  /** Load node detail (public API, for showing real topic count when Token is not configured) */
  async loadNodeDetail(nodeName: string): Promise<void> {
    this.nodeDetailError = ''
    try {
      this.nodeDetail = await this.api.getNodeByName(nodeName)
    } catch (error) {
      this.nodeDetail = null
      this.nodeDetailError = translateApiError(error)
    }
  }

  /** Load node detail (API v2, requires Token) */
  async loadNodeDetailV2(nodeName: string, token: string): Promise<void> {
    const cleanToken = token.trim()
    if (!cleanToken) {
      this.nodeDetail = null
      this.nodeDetailError = ''
      return
    }
    this.nodeDetailError = ''
    try {
      const res = await this.apiV2.getNode(cleanToken, nodeName)
      this.nodeDetail = res.data
    } catch (error) {
      this.nodeDetail = null
      this.nodeDetailError = translateApiError(error)
    }
  }

  /** Load topics under the specified node (API v2, supports pagination, requires Token) */
  async loadNodeTopicsV2(nodeName: string, token: string, options?: NodeTopicPageOneLoadOptions): Promise<boolean> {
    const loadOptions = options || {}
    const requestId = loadOptions.requestId || 0
    const source: NodeTopicPageOneSource = loadOptions.source || 'api_v2'
    this.isLoading = true
    this.errorMessage = ''
    this.nodeTopicsUseV2 = true
    this.nodeTopicsPage = 1
    this.nodeTopicsHasMore = true
    this.nodeTopicsLoadMoreError = ''
    try {
      const res = await this.apiV2.getNodeTopics(token, nodeName, 1)
      const items = res.data || []
      if (!this.shouldPublishNodeTopicsPageOne(nodeName, source, requestId, 1, items.length, loadOptions.fallback === true)) {
        return false
      }
      this.publishNodeTopicsPageOne(nodeName, source, requestId, items, items.length >= this.V2_PAGE_SIZE)
      return true
    } catch (error) {
      const e = error as Error
      this.errorMessage = translateApiError(error)
      this.markNodeTopicsPageOneFailed(nodeName, source, requestId, e)
      return false
    } finally {
      this.isLoading = false
    }
  }

  async loadMoreNodeTopicsV2(nodeName: string, token: string): Promise<void> {
    if (!this.nodeTopicsUseV2 || this.isLoading || !this.nodeTopicsPageOneSettled || this.isNodeTopicsLoadingMore || !this.nodeTopicsHasMore) {
      return
    }
    const nextPage = this.nodeTopicsPage + 1
    this.isNodeTopicsLoadingMore = true
    this.nodeTopicsLoadMoreError = ''
    try {
      const res = await this.apiV2.getNodeTopics(token, nodeName, nextPage)
      const items = res.data || []
      const merged = this.nodeTopics.slice()
      merged.push(...items)
      this.nodeTopics = merged
      this.nodeTopicsPage = nextPage
      this.nodeTopicsHasMore = items.length >= this.V2_PAGE_SIZE
    } catch (error) {
      this.nodeTopicsLoadMoreError = translateApiError(error)
      this.nodeTopicsHasMore = false
    } finally {
      this.isNodeTopicsLoadingMore = false
    }
  }

  async loadMoreNodeTopics(nodeName: string): Promise<void> {
    if (this.nodeTopicsUseV2 || this.isLoading || !this.nodeTopicsPageOneSettled || this.isNodeTopicsLoadingMore || !this.nodeTopicsHasMore) {
      return
    }
    const nextPage = this.nodeTopicsPage + 1
    this.isNodeTopicsLoadingMore = true
    this.nodeTopicsLoadMoreError = ''
    try {
      const snapshot = await this.api.getNodeTopicsPage(nodeName, nextPage)
      const merged = this.nodeTopics.slice()
      merged.push(...snapshot.topics)
      this.nodeTopics = merged
      this.nodeTopicsPage = nextPage
      this.nodeTopicsHasMore = snapshot.hasMore
    } catch (error) {
      this.nodeTopicsLoadMoreError = translateApiError(error)
    } finally {
      this.isNodeTopicsLoadingMore = false
    }
  }
}
