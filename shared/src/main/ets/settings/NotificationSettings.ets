import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { V2exNotification } from '../network/NetworkTypes'

const STORE_NAME: string = 'next2v_notifications'
const KEY_CACHE: string = 'lastLoadedNotifications'
const MAX_CACHED_NOTIFICATIONS: number = 80

export interface NotificationCacheSnapshot {
  ownerKey: string
  items: V2exNotification[]
  page: number
  hasMore: boolean
  updatedAt: number
}

export class NotificationSettings {
  static async loadCache(context: common.UIAbilityContext, ownerKey: string): Promise<NotificationCacheSnapshot> {
    if (!ownerKey) {
      return NotificationSettings.empty(ownerKey)
    }
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_CACHE, '') as string
      const snapshot = NotificationSettings.parseCache(raw)
      if (!snapshot || snapshot.ownerKey !== ownerKey) {
        return NotificationSettings.empty(ownerKey)
      }
      return snapshot
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取通知缓存失败')
    }
  }

  static async saveCache(
    context: common.UIAbilityContext,
    ownerKey: string,
    items: V2exNotification[],
    page: number,
    hasMore: boolean
  ): Promise<NotificationCacheSnapshot> {
    if (!ownerKey) {
      return NotificationSettings.empty(ownerKey)
    }
    try {
      const snapshot: NotificationCacheSnapshot = {
        ownerKey: ownerKey,
        items: NotificationSettings.normalizeItems(items),
        page: page > 0 ? page : 1,
        hasMore: hasMore,
        updatedAt: Math.floor(Date.now() / 1000)
      }
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_CACHE, JSON.stringify(snapshot))
      store.flushSync()
      return snapshot
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存通知缓存失败')
    }
  }

  static async clearCache(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_CACHE)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '清理通知缓存失败')
    }
  }

  private static empty(ownerKey: string): NotificationCacheSnapshot {
    return {
      ownerKey: ownerKey,
      items: [],
      page: 1,
      hasMore: true,
      updatedAt: 0
    }
  }

  private static parseCache(raw: string): NotificationCacheSnapshot | null {
    if (!raw) {
      return null
    }
    try {
      const parsed = JSON.parse(raw) as NotificationCacheSnapshot
      if (!parsed || !Array.isArray(parsed.items) || !parsed.ownerKey) {
        return null
      }
      return {
        ownerKey: parsed.ownerKey,
        items: NotificationSettings.normalizeItems(parsed.items),
        page: parsed.page > 0 ? parsed.page : 1,
        hasMore: parsed.hasMore === true,
        updatedAt: parsed.updatedAt > 0 ? parsed.updatedAt : 0
      }
    } catch (error) {
      return null
    }
  }

  private static normalizeItems(items: V2exNotification[]): V2exNotification[] {
    if (!Array.isArray(items)) {
      return []
    }
    return items
      .filter((item: V2exNotification) => item && item.id > 0)
      .slice(0, MAX_CACHED_NOTIFICATIONS)
  }
}
