import { AppStrings } from 'shared'
import type {
  SearchSourceMode,
  Sov2exHit,
} from 'shared'
import type {
  RemoteDateRange,
  RemoteTopicItem,
  SearchResultFilter,
} from '../components/SearchPageComponents'

export type SearchActionCommand = 'filter' | 'refresh' | ''

export interface RemoteSearchState {
  results: RemoteTopicItem[]
  total: number
  from: number
  error: string
}

export class SearchPageStateCoordinator {
  static parseActionCommand(rawCommand: string): SearchActionCommand {
    const raw = (rawCommand || '').trim()
    if (!raw) {
      return ''
    }
    const parts = raw.split(':')
    const action = parts.length > 0 ? parts[parts.length - 1] : ''
    if (action === 'filter' || action === 'refresh') {
      return action
    }
    return ''
  }

  static parsePendingQuery(command: string): string {
    const raw = (command || '').trim()
    if (!raw) {
      return ''
    }
    const stampedQueryMatch = raw.match(/^\d+:(.+)$/)
    const query = stampedQueryMatch && stampedQueryMatch[1] ? stampedQueryMatch[1] : raw
    return query.trim()
  }

  static usesNodeIndex(sourceMode: SearchSourceMode): boolean {
    return sourceMode === 'localWithNodes'
  }

  static shouldShowTopicResults(filter: SearchResultFilter): boolean {
    return filter === 'all' || filter === 'topics' || filter === 'users'
  }

  static shouldShowNodeResults(filter: SearchResultFilter): boolean {
    return filter === 'all' || filter === 'nodes'
  }

  static topicSectionTitle(filter: SearchResultFilter): string {
    return filter === 'users' ? AppStrings.text($r('app.string.search_user_related_topics'), 'User-related topics') : AppStrings.text($r('app.string.search_topic_results'), 'Topic results')
  }

  static emptyTopicHint(filter: SearchResultFilter): string {
    return filter === 'users' ? AppStrings.text($r('app.string.search_no_local_user_topics'), 'No local topics match this user') : AppStrings.text($r('app.string.search_no_topics'), 'No matching topics')
  }

  static sourceModeSummary(sourceMode: SearchSourceMode): string {
    if (sourceMode === 'remote') {
      return AppStrings.text($r('app.string.search_sov2ex'), 'Use SOV2EX site search')
    }
    if (sourceMode === 'externalWeb') {
      return AppStrings.text($r('app.string.search_external_summary'), 'The official API has no topic search; use the system browser to search V2EX topics')
    }
    if (SearchPageStateCoordinator.usesNodeIndex(sourceMode)) {
      return AppStrings.text($r('app.string.search_local_with_nodes_summary'), 'Search favorites, recently viewed, followed nodes, offline cache, and node library')
    }
    return AppStrings.text($r('app.string.search_local_summary'), 'Search favorites, recently viewed, followed nodes, and offline cache')
  }

  static loadingSummary(isCacheLoading: boolean, isNodeIndexLoading: boolean): string {
    if (isCacheLoading && isNodeIndexLoading) {
      return AppStrings.text($r('app.string.search_index_loading'), 'Loading indexes')
    }
    if (isCacheLoading) {
      return AppStrings.text($r('app.string.search_cache_loading'), 'Loading cache')
    }
    return AppStrings.text($r('app.string.search_nodes_loading'), 'Loading nodes')
  }

  static emptyNodeHint(sourceMode: SearchSourceMode): string {
    if (SearchPageStateCoordinator.usesNodeIndex(sourceMode)) {
      return AppStrings.text($r('app.string.search_nodes_library_empty_hint'), 'The node library and your followed nodes will appear here')
    }
    return AppStrings.text($r('app.string.search_followed_nodes_empty_hint'), 'Your followed nodes will appear here')
  }

  static resetRemoteState(): RemoteSearchState {
    return {
      results: [],
      total: 0,
      from: 0,
      error: '',
    }
  }

  static hasRemoteFilters(username: string, node: string, dateRange: RemoteDateRange): boolean {
    return username.trim().length > 0 || node.trim().length > 0 || dateRange !== 'all'
  }

  static remoteGte(dateRange: RemoteDateRange, nowSeconds: number = Math.floor(Date.now() / 1000)): number {
    if (dateRange === 'all') {
      return 0
    }
    const day = 24 * 60 * 60
    if (dateRange === 'day') {
      return nowSeconds - day
    }
    if (dateRange === 'week') {
      return nowSeconds - 7 * day
    }
    if (dateRange === 'month') {
      return nowSeconds - 30 * day
    }
    return nowSeconds - 365 * day
  }

  static buildExternalTopicSearchUrl(query: string): string {
    return `https://www.bing.com/search?q=${encodeURIComponent(`site:v2ex.com/t ${query}`)}`
  }

  static remoteHitToItem(hit: Sov2exHit): RemoteTopicItem {
    const source = hit._source || {}
    const rawId = source.id || Number.parseInt(hit._id || '0')
    return {
      id: rawId || 0,
      title: SearchPageStateCoordinator.cleanHighlightText(source.title || ''),
      username: source.member || '',
      content: SearchPageStateCoordinator.cleanHighlightText(
        SearchPageStateCoordinator.firstHighlight(hit) || source.content || '',
      ),
      created: SearchPageStateCoordinator.cleanCreated(source.created || ''),
      replies: source.replies || 0,
      nodeId: source.node || 0,
    }
  }

  private static firstHighlight(hit: Sov2exHit): string {
    const highlight = hit.highlight
    if (!highlight) {
      return ''
    }
    const reply = highlight.replyListContent
    if (reply && reply.length > 0) {
      return reply[0]
    }
    if (highlight.content && highlight.content.length > 0) {
      return highlight.content[0]
    }
    if (highlight.title && highlight.title.length > 0) {
      return highlight.title[0]
    }
    return ''
  }

  private static cleanHighlightText(text: string): string {
    return (text ?? '')
      .replace(/<em>/g, '')
      .replace(/<\/em>/g, '')
      .replace(/\s+/g, ' ')
      .trim()
  }

  private static cleanCreated(created: string): string {
    return (created ?? '').replace('T', ' ').slice(0, 16)
  }
}
