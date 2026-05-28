import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ApiService } from '../network/ApiService'
import type { V2exNode } from '../network/NetworkTypes'
import { NodeSearchUtils } from '../utils/NodeSearchUtils'

export interface NodeIndexLoadResult {
  nodes: V2exNode[]
  fromCache: boolean
}

export class NodeIndexRepository {
  private static memoryNodes: V2exNode[] | null = null
  private static inFlight: Promise<NodeIndexLoadResult> | null = null

  static async getNodes(api: ApiService = new ApiService(), forceRefresh: boolean = false): Promise<NodeIndexLoadResult> {
    if (!forceRefresh && NodeIndexRepository.memoryNodes) {
      DiagnosticLogger.info('ui_lifecycle', 'node_index_repository_memory_hit', {
        count: NodeIndexRepository.memoryNodes.length
      })
      const cachedResult: NodeIndexLoadResult = { nodes: NodeIndexRepository.memoryNodes, fromCache: true }
      return cachedResult
    }
    if (!forceRefresh && NodeIndexRepository.inFlight) {
      DiagnosticLogger.info('ui_lifecycle', 'node_index_repository_join_inflight', {})
      return NodeIndexRepository.inFlight
    }

    const startedAt = Date.now()
    DiagnosticLogger.info('ui_lifecycle', 'node_index_repository_load_start', {
      forceRefresh: forceRefresh
    })
    NodeIndexRepository.inFlight = api.getAllNodes()
      .then((nodes: V2exNode[]) => {
        const fetchedAt = Date.now()
        const sorted = NodeSearchUtils.sortByPopularity(nodes)
        NodeIndexRepository.memoryNodes = sorted
        DiagnosticLogger.info('ui_lifecycle', 'node_index_repository_load_done', {
          count: sorted.length,
          fromCache: false,
          fetchMs: fetchedAt - startedAt,
          sortMs: Date.now() - fetchedAt,
          totalMs: Date.now() - startedAt
        })
        const result: NodeIndexLoadResult = { nodes: sorted, fromCache: false }
        return result
      })
      .finally(() => {
        NodeIndexRepository.inFlight = null
      })
    return NodeIndexRepository.inFlight
  }

  static clearMemoryCache(): void {
    NodeIndexRepository.memoryNodes = null
    NodeIndexRepository.inFlight = null
  }
}
