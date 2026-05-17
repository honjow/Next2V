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
    return filter === 'users' ? '用户相关主题' : '主题结果'
  }

  static emptyTopicHint(filter: SearchResultFilter): string {
    return filter === 'users' ? '没有匹配该用户的本地主题' : '没有匹配的主题'
  }

  static sourceModeSummary(sourceMode: SearchSourceMode): string {
    if (sourceMode === 'remote') {
      return '使用 SOV2EX 站内搜索'
    }
    if (sourceMode === 'externalWeb') {
      return '官方 API 暂无主题搜索，使用系统浏览器搜索 V2EX 主题'
    }
    if (SearchPageStateCoordinator.usesNodeIndex(sourceMode)) {
      return '在收藏 / 最近浏览 / 关注节点 / 离线缓存 / 节点库中搜索'
    }
    return '在收藏 / 最近浏览 / 关注节点 / 离线缓存中搜索'
  }

  static loadingSummary(isCacheLoading: boolean, isNodeIndexLoading: boolean): string {
    if (isCacheLoading && isNodeIndexLoading) {
      return '索引加载中'
    }
    if (isCacheLoading) {
      return '缓存加载中'
    }
    return '节点加载中'
  }

  static emptyNodeHint(sourceMode: SearchSourceMode): string {
    if (SearchPageStateCoordinator.usesNodeIndex(sourceMode)) {
      return '节点库和你关注的节点会出现在这里'
    }
    return '你关注的节点会出现在这里'
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
