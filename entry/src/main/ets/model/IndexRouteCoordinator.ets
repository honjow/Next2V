import type {
  NodeTopicListParams,
  TopicDetailParams,
  UserProfileParams,
  V2exRoute,
} from 'shared'

export class IndexRouteCoordinator {
  static commandPayload(command: string): string {
    const raw = (command || '').trim()
    if (!raw) {
      return ''
    }
    const stampedMatch = raw.match(/^\d+:(.+)$/)
    const payload = stampedMatch && stampedMatch[1] ? stampedMatch[1] : raw
    return payload.trim()
  }

  static simpleCommand(action: string, now: number): string {
    return `${now}:${(action || '').trim()}`
  }

  static topicActionCommand(topicId: number, action: string, now: number): string {
    return `${now}:${topicId}:${(action || '').trim()}`
  }

  static nodeTopicActionCommand(nodeName: string, action: string, now: number): string {
    return `${now}:${(nodeName || '').trim()}:${(action || '').trim()}`
  }

  static userProfileShownCommand(username: string, now: number): string {
    return `${now}:${(username || '').trim()}`
  }

  static pendingSearchQueryCommand(query: string, now: number): string {
    return `${now}:${(query || '').trim()}`
  }

  static topicParams(route: V2exRoute): TopicDetailParams | null {
    if (route.kind !== 'topic' || !route.topicId || route.topicId <= 0) {
      return null
    }
    if (route.targetFloor && route.targetFloor > 0) {
      return { topicId: route.topicId, targetFloor: route.targetFloor }
    }
    return { topicId: route.topicId }
  }

  static userProfileParams(route: V2exRoute): UserProfileParams | null {
    if (route.kind !== 'member' || !route.username) {
      return null
    }
    return { username: route.username }
  }

  static nodeTopicParams(route: V2exRoute): NodeTopicListParams | null {
    if (route.kind !== 'node' || !route.nodeName) {
      return null
    }
    return { nodeName: route.nodeName, nodeTitle: route.nodeName }
  }

  static searchQuery(route: V2exRoute): string {
    if (route.kind !== 'search' || !route.query) {
      return ''
    }
    return route.query.trim()
  }
}
