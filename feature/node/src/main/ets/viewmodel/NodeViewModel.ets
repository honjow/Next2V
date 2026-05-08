import { V2exNode, V2exTopic, ApiService, ApiV2Service, NodeSearchUtils } from 'shared'

/**
 * 节点数据源 — 用于 LazyForEach
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
 * 节点页 ViewModel
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

  /** 加载所有节点 */
  async loadAllNodes(): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''
    try {
      const nodes = await this.api.getAllNodes()
      this.allNodes = NodeSearchUtils.sortByPopularity(nodes)
      this.applyNodeFilter()
    } catch (error) {
      this.errorMessage = error.message || '节点加载失败'
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

  /** 加载指定节点下的主题 */
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
      this.errorMessage = error.message || '节点主题加载失败'
      console.error('Failed to load node topics:', error.message)
    } finally {
      this.isLoading = false
    }
  }

  /** 加载节点详情（公开 API，用于未配置 Token 时仍显示真实主题总数） */
  async loadNodeDetail(nodeName: string): Promise<void> {
    this.nodeDetailError = ''
    try {
      this.nodeDetail = await this.api.getNodeByName(nodeName)
    } catch (error) {
      this.nodeDetail = null
      this.nodeDetailError = error.message || '节点信息加载失败'
    }
  }

  /** 加载节点详情（API v2，需要 Token） */
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
      this.nodeDetailError = error.message || '节点信息加载失败'
    }
  }

  /** 加载指定节点下的主题（API v2，支持分页，需要 Token） */
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
      this.errorMessage = error.message || '节点主题加载失败'
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
      this.nodeTopicsLoadMoreError = error.message || '加载更多失败'
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
      this.nodeTopicsLoadMoreError = error.message || '加载更多失败'
    } finally {
      this.isNodeTopicsLoadingMore = false
    }
  }
}
