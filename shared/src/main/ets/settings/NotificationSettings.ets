import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { V2exNotification } from '../network/NetworkTypes'
import { STORE_NAME_NOTIFICATIONS } from './SettingsStores'
import { AppStrings } from '../i18n/AppStrings'

const STORE_NAME: string = STORE_NAME_NOTIFICATIONS
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
      throw new Error(e.message || 'Failed to read notification cache')
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
      throw new Error(e.message || 'Failed to save notification cache')
    }
  }

  static async clearCache(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_CACHE)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text(AppStrings.R_NOTIFICATION_CACHE_CLEAR_FAILED, 'Failed to clear notification cache'))
    }
  }

  static async exportCacheForBackup(context: common.UIAbilityContext): Promise<NotificationCacheSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_CACHE, '') as string
      const snapshot = NotificationSettings.parseCache(raw)
      return snapshot || NotificationSettings.empty('')
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to export notification cache')
    }
  }

  static async restoreCacheFromBackup(context: common.UIAbilityContext, snapshot: NotificationCacheSnapshot): Promise<void> {
    try {
      const normalized: NotificationCacheSnapshot = {
        ownerKey: snapshot.ownerKey || '',
        items: NotificationSettings.normalizeItems(snapshot.items),
        page: snapshot.page > 0 ? snapshot.page : 1,
        hasMore: snapshot.hasMore === true,
        updatedAt: snapshot.updatedAt > 0 ? snapshot.updatedAt : 0
      }
      const store = await preferences.getPreferences(context, STORE_NAME)
      if (!normalized.ownerKey || normalized.items.length === 0) {
        store.deleteSync(KEY_CACHE)
      } else {
        store.putSync(KEY_CACHE, JSON.stringify(normalized))
      }
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to restore notification cache')
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
