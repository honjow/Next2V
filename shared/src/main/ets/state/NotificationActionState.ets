import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the notification appbar command (`StorageKeys.NOTIFICATION_ACTION`).
 *
 * One-directional bus: the V1 `Index.ets` notification title-bar menu writes a `<token>:<action>`
 * string (`Index.sendNotificationAction`, the single writer) for the refresh menu item, and the
 * `@ComponentV2` `NotificationPage` reacts via `@Monitor('<member>.command')` to refresh its list.
 * There is no writeback on this key.
 *
 * During the State Management V1->V2 migration the command lives in BOTH stores at once: the writer
 * dual-writes the V1 `AppStorage` key AND this `@Trace` field, mirroring the `NodeTopicActionState`
 * precedent.
 *
 * Transitional: drop the `AppStorage` half once the writer no longer needs it.
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
