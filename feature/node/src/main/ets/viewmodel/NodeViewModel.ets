import { V2exNode, V2exTopic, ApiService, ApiV2Service, DiagnosticLogger, NodeIndexRepository, NodeSearchUtils, translateApiError } from 'shared'

export type NodeIndexLoadPhase = 'idle' | 'loading' | 'loaded' | 'error'

export interface NodeIndexLoadOptions {
  forceRefresh?: boolean
  publishDefaultNodes?: boolean
}

/**
 * Node data source — for LazyForEach
 */
export class NodeDataSource implements IDataSource {
  private dataArray: V2exNode[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number {
    return this.dataArray.length
  }

  getData(index: number): V2exNode {
    return this.dataArray[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener)
    if (pos >= 0) {
      this.listeners.splice(pos, 1)
    }
  }

  setData(data: V2exNode[]): void {
    this.dataArray = data
    this.listeners.forEach(listener => listener.onDataReloaded())
  }
}

/**
 * Node page ViewModel
 */
@Observed
export class NodeViewModel {
  nodeDataSource: NodeDataSource = new NodeDataSource()
  nodeTopics: V2exTopic[] = []
  nodeDetail: V2exNode | null = null
  nodeDetailError: string = ''
  nodeTopicsUseV2: boolean = false
  nodeTopicsPage: number = 1
  nodeTopicsHasMore: boolean = true
  isNodeTopicsLoadingMore: boolean = false
  nodeTopicsLoadMoreError: string = ''
  isLoading: boolean = false
  nodeIndexPhase: NodeIndexLoadPhase = 'idle'
  keyword: string = ''
  errorMessage: string = ''

  private allNodes: V2exNode[] = []
  private publishDefaultNodes: boolean = true

  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private readonly V2_PAGE_SIZE: number = 10

  /** Load all nodes */
  async loadAllNodes(options?: NodeIndexLoadOptions): Promise<void> {
    const loadOptions: NodeIndexLoadOptions = options || {}
    const publishDefaultNodes = loadOptions.publishDefaultNodes !== false
    this.publishDefaultNodes = publishDefaultNodes
    this.isLoading = true
    this.nodeIndexPhase = 'loading'
    this.errorMessage = ''
    const startedAt = Date.now()
    try {
      const result = await NodeIndexRepository.getNodes(this.api, loadOptions.forceRefresh === true)
      this.allNodes = result.nodes
      this.nodeIndexPhase = 'loaded'
      this.applyNodeFilter(publishDefaultNodes)
      DiagnosticLogger.info('ui_lifecycle', 'node_index_viewmodel_load_done', {
        count: this.allNodes.length,
        fromCache: result.fromCache,
        publishDefaultNodes: publishDefaultNodes,
        totalMs: Date.now() - startedAt
      })
    } catch (error) {
      this.nodeIndexPhase = 'error'
      this.errorMessage = translateApiError(error)
      console.error('Failed to load nodes:', error.message)
    } finally {
      this.isLoading = false
    }
  }

  setNodeFilter(keyword: string): void {
    this.keyword = keyword
    this.applyNodeFilter()
  }

  hasNodeIndexSettled(): boolean {
    return this.nodeIndexPhase === 'loaded' || this.nodeIndexPhase === 'error'
  }

  defaultNodePreview(): V2exNode[] {
    return this.allNodes
  }

  private applyNodeFilter(publishDefaultNodes: boolean = this.publishDefaultNodes): void {
    const startedAt = Date.now()
    const hasKeyword = (this.keyword || '').trim().length > 0
    const data = (!hasKeyword && !publishDefaultNodes) ? [] : NodeSearchUtils.filter(this.allNodes, this.keyword)
    this.nodeDataSource.setData(data)
    DiagnosticLogger.info('ui_lifecycle', 'node_index_publish_done', {
      keywordLength: (this.keyword || '').trim().length,
      allCount: this.allNodes.length,
      publishedCount: data.length,
      publishDefaultNodes: publishDefaultNodes,
      totalMs: Date.now() - startedAt
    })
  }

  /** Load topics under the specified node */
  async loadNodeTopics(nodeName: string): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''
    this.nodeTopicsUseV2 = false
    this.nodeTopicsPage = 1
    this.nodeTopicsHasMore = true
    this.nodeTopicsLoadMoreError = ''
    try {
      const snapshot = await this.api.getNodeTopicsPage(nodeName, 1)
      this.nodeTopics = snapshot.topics
      this.nodeTopicsHasMore = snapshot.hasMore
    } catch (error) {
      this.errorMessage = translateApiError(error)
      console.error('Failed to load node topics:', error.message)
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
  async loadNodeTopicsV2(nodeName: string, token: string): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''
    this.nodeTopicsUseV2 = true
    this.nodeTopicsPage = 1
    this.nodeTopicsHasMore = true
    this.nodeTopicsLoadMoreError = ''
    try {
      const res = await this.apiV2.getNodeTopics(token, nodeName, 1)
      const items = res.data || []
      this.nodeTopics = items
      this.nodeTopicsHasMore = items.length >= this.V2_PAGE_SIZE
    } catch (error) {
      this.errorMessage = translateApiError(error)
    } finally {
      this.isLoading = false
    }
  }

  async loadMoreNodeTopicsV2(nodeName: string, token: string): Promise<void> {
    if (!this.nodeTopicsUseV2 || this.isNodeTopicsLoadingMore || !this.nodeTopicsHasMore) {
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
    if (this.nodeTopicsUseV2 || this.isNodeTopicsLoadingMore || !this.nodeTopicsHasMore) {
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
