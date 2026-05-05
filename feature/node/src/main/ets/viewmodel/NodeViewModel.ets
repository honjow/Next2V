import { V2exNode, V2exTopic, ApiService } from 'shared'

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
  isLoading: boolean = false
  keyword: string = ''
  errorMessage: string = ''

  private allNodes: V2exNode[] = []

  private api: ApiService = new ApiService()

  /** 加载所有节点 */
  async loadAllNodes(): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''
    try {
      const nodes = await this.api.getAllNodes()
      this.allNodes = nodes.sort((a: V2exNode, b: V2exNode) => b.topics - a.topics)
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
    const q = this.keyword.trim().toLowerCase()
    if (q.length === 0) {
      this.nodeDataSource.setData(this.allNodes)
      return
    }
    this.nodeDataSource.setData(this.allNodes.filter((node: V2exNode) => {
      return node.name.toLowerCase().includes(q) ||
        node.title.toLowerCase().includes(q) ||
        node.title_alternative.toLowerCase().includes(q)
    }))
  }

  /** 加载指定节点下的主题 */
  async loadNodeTopics(nodeName: string): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''
    try {
      this.nodeTopics = await this.api.getTopicsByNode(nodeName)
    } catch (error) {
      this.errorMessage = error.message || '节点主题加载失败'
      console.error('Failed to load node topics:', error.message)
    } finally {
      this.isLoading = false
    }
  }
}
