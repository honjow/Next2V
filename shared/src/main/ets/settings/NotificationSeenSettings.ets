import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { STORE_NAME_SETTINGS } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS

/**
 * Per-account "last seen" timestamp for the notification tab (unix seconds).
 *
 * This is the single truth source for the row-level unread markers: a row is
 * unread iff `created > lastSeen`. It replaces the former entry-badge top-N
 * projection, which raced the async badge probe (V2EX /notifications is
 * consume-on-read, so a missed projection could never be recovered) and only
 * worked for the cookie source.
 *
 * Missing value returns MISSING_LAST_SEEN (treated as "nothing unread") so a
 * fresh install never floods the first page with markers.
 */
export class NotificationSeenSettings {
  static readonly MISSING_LAST_SEEN: number = Number.MAX_SAFE_INTEGER

  private static keyFor(owner: string): string {
    const normalized = (owner || '').trim().toLowerCase() || 'anonymous'
    return `${StorageKeys.NOTIFICATION_LAST_SEEN_PREFIX}${normalized}`
  }

  static async loadLastSeen(context: common.UIAbilityContext, owner: string): Promise<number> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const value = store.getSync(NotificationSeenSettings.keyFor(owner), 0) as number
      return value > 0 ? value : NotificationSeenSettings.MISSING_LAST_SEEN
    } catch (error) {
      console.error('load notification last-seen failed: ' + (error as Error).message)
      return NotificationSeenSettings.MISSING_LAST_SEEN
    }
  }

  static async saveLastSeen(context: common.UIAbilityContext, owner: string, seconds: number): Promise<void> {
    if (seconds <= 0) {
      return
    }
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(NotificationSeenSettings.keyFor(owner), seconds)
      store.flushSync()
    } catch (error) {
      console.error('save notification last-seen failed: ' + (error as Error).message)
    }
  }
}
