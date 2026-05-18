import { TopicDetailParams } from 'shared'
import { NotificationMetadata } from '../viewmodel/NotificationCenterViewModel'

export interface NotificationCardDisplay {
  kindTag: string
  readTag: string
  titleText: string
  bodyText: string
  replyContent: string
  replyRenderedContent: string
  memberName: string
  avatarUrl: string
}

export class NotificationPageCoordinator {
  static displayFor(meta: NotificationMetadata): NotificationCardDisplay {
    return {
      kindTag: meta.kindTag,
      readTag: meta.readTag,
      titleText: meta.title,
      bodyText: meta.body,
      replyContent: meta.replyContent,
      replyRenderedContent: meta.replyRenderedContent,
      memberName: meta.memberName,
      avatarUrl: meta.avatarUrl
    }
  }

  static routeParams(meta: NotificationMetadata): TopicDetailParams | null {
    if (meta.topicId <= 0) {
      return null
    }
    if (meta.targetFloor && meta.targetFloor > 0) {
      return { topicId: meta.topicId, targetFloor: meta.targetFloor }
    }
    return { topicId: meta.topicId }
  }

  static shouldRefreshVisible(
    hasAuth: boolean,
    hasStoredAuthSignal: boolean,
    isLoading: boolean,
    isLoadingMore: boolean,
    notificationCount: number,
    loadedFromCache: boolean
  ): boolean {
    if (!hasAuth) {
      return hasStoredAuthSignal
    }
    if (isLoading || isLoadingMore) {
      return false
    }
    return notificationCount === 0 || loadedFromCache
  }

  static shouldRefreshNotifications(
    hasAuth: boolean,
    isLoading: boolean,
    isLoadingMore: boolean,
    notificationCount: number,
    force: boolean,
    loadedFromCache: boolean
  ): boolean {
    if (!hasAuth || isLoading || isLoadingMore) {
      return false
    }
    return force || notificationCount === 0 || loadedFromCache
  }

  static ownerKey(username: string, storedUsername: string, sessionUsername: string): string {
    let owner = (username || '').trim()
    if (!owner) {
      owner = (storedUsername || '').trim()
    }
    if (!owner) {
      owner = (sessionUsername || '').trim()
    }
    return owner ? 'member:' + owner : ''
  }
}
