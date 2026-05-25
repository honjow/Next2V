import { V2exNode, V2exTopic, ApiService, ApiV2Service, NodeSearchUtils, translateApiError } from 'shared'

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
  keyword: string = ''
  errorMessage: string = ''

  private allNodes: V2exNode[] = []

  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private readonly V2_PAGE_SIZE: number = 10

  /** Load all nodes */
  async loadAllNodes(): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''
    try {
      const nodes = await this.api.getAllNodes()
      this.allNodes = NodeSearchUtils.sortByPopularity(nodes)
      this.applyNodeFilter()
    } catch (error) {
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

  private applyNodeFilter(): void {
    this.nodeDataSource.setData(NodeSearchUtils.filter(this.allNodes, this.keyword))
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
