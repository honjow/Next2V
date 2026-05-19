import { common } from '@kit.AbilityKit'
import { NotificationSettings, V2exNotification } from 'shared'
import { NotificationPageCoordinator } from './NotificationPageCoordinator'

export interface NotificationCacheLoadResult {
  skipped: boolean
  shouldApplyItems: boolean
  updatedAt: number
  items: V2exNotification[]
  page: number
  hasMore: boolean
}

export interface NotificationCacheSaveResult {
  updatedAt: number
}

export class NotificationCacheCoordinator {
  static async load(
    context: common.UIAbilityContext,
    username: string,
    storedUsername: string,
    sessionUsername: string,
    source: string,
    currentCount: number,
    loadedFromCache: boolean
  ): Promise<NotificationCacheLoadResult> {
    const ownerKey = NotificationPageCoordinator.ownerKey(username, storedUsername, sessionUsername, source)
    if (!ownerKey || (currentCount > 0 && !loadedFromCache)) {
      return NotificationCacheCoordinator.skippedLoadResult()
    }
    const snapshot = await NotificationSettings.loadCache(context, ownerKey)
    const shouldApplyItems = snapshot.items.length > 0 && !(currentCount > 0 && !loadedFromCache)
    return {
      skipped: false,
      shouldApplyItems,
      updatedAt: snapshot.updatedAt,
      items: snapshot.items,
      page: snapshot.page,
      hasMore: snapshot.hasMore
    }
  }

  static async save(
    context: common.UIAbilityContext,
    username: string,
    storedUsername: string,
    sessionUsername: string,
    source: string,
    items: V2exNotification[],
    page: number,
    hasMore: boolean
  ): Promise<NotificationCacheSaveResult> {
    const ownerKey = NotificationPageCoordinator.ownerKey(username, storedUsername, sessionUsername, source)
    if (!ownerKey) {
      return { updatedAt: 0 }
    }
    const snapshot = await NotificationSettings.saveCache(context, ownerKey, items, page, hasMore)
    return { updatedAt: snapshot.updatedAt }
  }

  private static skippedLoadResult(): NotificationCacheLoadResult {
    return {
      skipped: true,
      shouldApplyItems: false,
      updatedAt: 0,
      items: [],
      page: 1,
      hasMore: true
    }
  }
}
