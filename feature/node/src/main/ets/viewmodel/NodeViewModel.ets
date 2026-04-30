import { V2exNode, V2exTopic, ApiService } from 'shared'

/**
 * 节点页 ViewModel
 */
@Observed
export class NodeViewModel {
  allNodes: V2exNode[] = []
  nodeTopics: V2exTopic[] = []
  isLoading: boolean = false

  private api: ApiService = new ApiService()

  /** 加载所有节点 */
  async loadAllNodes(): Promise<void> {
    this.isLoading = true
    try {
      this.allNodes = await this.api.getAllNodes()
    } catch (error) {
      console.error('Failed to load nodes:', error.message)
    } finally {
      this.isLoading = false
    }
  }

  /** 加载指定节点下的主题 */
  async loadNodeTopics(nodeName: string): Promise<void> {
    this.isLoading = true
    try {
      this.nodeTopics = await this.api.getTopicsByNode(nodeName)
    } catch (error) {
      console.error('Failed to load node topics:', error.message)
    } finally {
      this.isLoading = false
    }
  }
}
