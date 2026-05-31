import { AppStorageV2 } from '@kit.ArkUI'
import { StorageKeys } from '../constants/StorageKeys'

/**
 * V2 mirror of the pending deep-link command (`StorageKeys.PENDING_V2EX_URL`).
 *
 * Written by `EntryAbility` on a cold/warm deep link and cleared by `Index` after consuming it; the
 * migrated `@ComponentV2` `Index` reads this `@Trace` field and `@Monitor`s it to route the pending URL.
 * Writers route through `publishPendingV2exUrl` (write-through: AppStorage + mirror). Transitional: drop
 * the AppStorage half once no V1 `@StorageLink` reads the key.
 */
@ObservedV2
export class PendingV2exUrlState {
  @Trace command: string = ''
}

const PENDING_V2EX_URL_V2_KEY: string = 'v2:pendingV2exUrl'

/** Returns the app-wide PendingV2exUrlState singleton from AppStorageV2. */
export function connectPendingV2exUrl(): PendingV2exUrlState {
  return AppStorageV2.connect(PendingV2exUrlState, PENDING_V2EX_URL_V2_KEY, () => new PendingV2exUrlState())!
}

export function publishPendingV2exUrl(value: string): void {
  AppStorage.setOrCreate<string>(StorageKeys.PENDING_V2EX_URL, value)
  connectPendingV2exUrl().command = value
}
