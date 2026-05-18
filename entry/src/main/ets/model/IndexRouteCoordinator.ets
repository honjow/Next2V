import type {
  ImagePreviewParams,
  NodeTopicListParams,
  TopicDetailParams,
  UserProfileParams,
  V2exRoute,
} from 'shared'

export interface ReplyEditorRouteParams {
  topicId: number
  topicTitle: string
  initialContent: string
}

export class IndexRouteCoordinator {
  private static numberParam(param: Object, key: string): number {
    try {
      const value = (param as Record<string, Object>)[key]
      return typeof value === 'number' && Number.isFinite(value) ? value : 0
    } catch (_error) {
      return 0
    }
  }

  private static stringParam(param: Object, key: string): string {
    try {
      const value = (param as Record<string, Object>)[key]
      return typeof value === 'string' ? value : ''
    } catch (_error) {
      return ''
    }
  }

  static topicDetailRouteParams(param: Object): TopicDetailParams {
    const topicId = IndexRouteCoordinator.numberParam(param, 'topicId')
    const targetFloor = IndexRouteCoordinator.numberParam(param, 'targetFloor')
    if (targetFloor > 0) {
      return { topicId, targetFloor }
    }
    return { topicId }
  }

  static replyEditorRouteParams(param: Object): ReplyEditorRouteParams {
    return {
      topicId: IndexRouteCoordinator.numberParam(param, 'topicId'),
      topicTitle: IndexRouteCoordinator.stringParam(param, 'topicTitle'),
      initialContent: IndexRouteCoordinator.stringParam(param, 'initialContent'),
    }
  }

  static imagePreviewRouteParams(param: Object): ImagePreviewParams {
    return { url: IndexRouteCoordinator.stringParam(param, 'url') }
  }

  static nodeTopicRouteParams(param: Object): NodeTopicListParams {
    const nodeName = IndexRouteCoordinator.stringParam(param, 'nodeName')
    const nodeTitle = IndexRouteCoordinator.stringParam(param, 'nodeTitle')
    return { nodeName, nodeTitle }
  }

  static userProfileRouteParams(param: Object): UserProfileParams {
    return { username: IndexRouteCoordinator.stringParam(param, 'username') }
  }

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
