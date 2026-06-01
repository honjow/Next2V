import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 command bus for the notification appbar (`'v2:notificationAction'`).
 *
 * One-directional bus: the `@ComponentV2` `Index.ets` notification title-bar menu writes a `<token>:<action>`
 * string (`Index.sendNotificationAction`, the single writer) for the refresh menu item, and the
 * `@ComponentV2` `NotificationPage` reacts via `@Monitor('<member>.command')` to refresh its list.
 * There is no writeback on this command.
 *
 * The legacy V1 `AppStorage` (`notificationAction`) key + its dual-write were retired once no reader
 * read the V1 half. (Note: the separate `NOTIFICATION_UNREAD_COUNT` badge key is unrelated and still
 * an imperative AppStorage read — see `NotificationUnreadState`.)
 */
@ObservedV2
export class NotificationActionState {
  @Trace command: string = ''
}

const NOTIFICATION_ACTION_V2_KEY: string = 'v2:notificationAction'

/** Returns the app-wide NotificationActionState singleton from AppStorageV2. */
export function connectNotificationAction(): NotificationActionState {
  return AppStorageV2.connect(NotificationActionState, NOTIFICATION_ACTION_V2_KEY, () => new NotificationActionState())!
}
