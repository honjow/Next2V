import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the notification unread-badge count.
 *
 * Written by `Index.refreshNotificationBadge` (badge count from the unread probe) and cleared by
 * `NotificationPage` when the list is viewed; the migrated `@ComponentV2` `Index` reads this `@Trace`
 * field in its tab-bar badge and `NotificationPage` reads it imperatively to capture the entry count.
 * Writers route through `publishNotificationUnreadCount`. Pure-V2: the legacy NOTIFICATION_UNREAD_COUNT
 * AppStorage half was retired once no reader read it.
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
  connectNotificationUnread().count = value
}
