import { AppStorageV2 } from '@kit.ArkUI'
import { StorageKeys } from '../constants/StorageKeys'

/**
 * V2 mirror of the notification unread-badge count (`StorageKeys.NOTIFICATION_UNREAD_COUNT`).
 *
 * Written by `Index.refreshNotificationBadge` (badge count from the unread probe) and cleared by
 * `NotificationPage` when the list is viewed; the migrated `@ComponentV2` `Index` reads this `@Trace`
 * field in its tab-bar badge. Writers route through `publishNotificationUnreadCount` (write-through:
 * AppStorage + mirror). Transitional: drop the AppStorage half once no V1 `@StorageLink` reads the key.
 */
@ObservedV2
export class NotificationUnreadState {
  @Trace count: number = 0
}

const NOTIFICATION_UNREAD_V2_KEY: string = 'v2:notificationUnread'

/** Returns the app-wide NotificationUnreadState singleton from AppStorageV2. */
export function connectNotificationUnread(): NotificationUnreadState {
  return AppStorageV2.connect(NotificationUnreadState, NOTIFICATION_UNREAD_V2_KEY, () => new NotificationUnreadState())!
}

export function publishNotificationUnreadCount(value: number): void {
  AppStorage.setOrCreate<number>(StorageKeys.NOTIFICATION_UNREAD_COUNT, value)
  connectNotificationUnread().count = value
}
