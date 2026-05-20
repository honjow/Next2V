import { common } from '@kit.AbilityKit'
import { DiagnosticLogger, NotificationSettings, V2exNotification } from 'shared'
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
    DiagnosticLogger.info('notification', 'notification_cache_coordinator_load', {
      ownerHash: DiagnosticLogger.ownerHash(ownerKey),
      source: source,
      currentCount: currentCount,
      loadedFromCache: loadedFromCache
    })
    if (!ownerKey || (currentCount > 0 && !loadedFromCache)) {
      DiagnosticLogger.info('notification', 'notification_cache_coordinator_load_result', { skipped: true, shouldApplyItems: false, count: 0, updatedAt: 0 })
      return NotificationCacheCoordinator.skippedLoadResult()
    }
    const snapshot = await NotificationSettings.loadCache(context, ownerKey)
    const shouldApplyItems = snapshot.items.length > 0 && !(currentCount > 0 && !loadedFromCache)
    DiagnosticLogger.info('notification', 'notification_cache_coordinator_load_result', {
      skipped: false,
      shouldApplyItems: shouldApplyItems,
      count: snapshot.items.length,
      updatedAt: snapshot.updatedAt
    })
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
      DiagnosticLogger.info('notification', 'notification_cache_coordinator_save_result', { ownerHash: '', source: source, count: 0, updatedAt: 0 })
      return { updatedAt: 0 }
    }
    const snapshot = await NotificationSettings.saveCache(context, ownerKey, items, page, hasMore)
    DiagnosticLogger.info('notification', 'notification_cache_coordinator_save_result', {
      ownerHash: DiagnosticLogger.ownerHash(ownerKey),
      source: source,
      count: items.length,
      updatedAt: snapshot.updatedAt
    })
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
