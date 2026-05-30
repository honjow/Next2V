import { V2exNode, ApiService, DiagnosticLogger, NodeIndexRepository, NodeSearchUtils, translateApiError } from 'shared'

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
 * Node directory / search ViewModel.
 *
 * @ObservedV2 (not V1 @Observed) so the @ComponentV2 node-index pages (NodePickerPage,
 * DiscoverPage) observe the build()-read scalars below via @Trace. Split out of the
 * former monolithic NodeViewModel: it holds only the node directory + search half, which
 * is disjoint from the single-node topic-feed half (still V1 NodeViewModel, used by the
 * still-V1 NodeTopicPage). nodeDataSource is a plain IDataSource observed by LazyForEach,
 * so it needs no @Trace.
 */
@ObservedV2
export class NodeIndexViewModel {
  nodeDataSource: NodeDataSource = new NodeDataSource()
  @Trace isLoading: boolean = false
  @Trace nodeIndexPhase: NodeIndexLoadPhase = 'idle'
  @Trace keyword: string = ''
  @Trace errorMessage: string = ''

  private allNodes: V2exNode[] = []
  private publishDefaultNodes: boolean = true
  private api: ApiService = new ApiService()

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
}
