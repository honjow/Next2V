import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the active multi-account id (`StorageKeys.ACTIVE_ACCOUNT_ID`).
 *
 * `AccountStore.applyActiveAccountId()` is the ONE chokepoint that writes the key (setActiveId /
 * restoreActiveId / remove-active / clearAll route through it); it dual-writes the V1 `AppStorage`
 * key (still read by V1 `@StorageLink`) AND this `@Trace` field, which the migrated `@ComponentV2`
 * AccountPage / AccountDetailPage `@Monitor` to reload account identity when the active account
 * changes (switch / logout). This mirror only reflects WHICH account is active; it never performs a
 * switch — the AccountStore state machine still owns switch/remove/restore semantics.
 *
 * Transitional: drop the `AppStorage` half once every reader has moved to V2.
 */
@ObservedV2
export class ActiveAccountState {
  @Trace id: string = ''
}

const ACTIVE_ACCOUNT_V2_KEY: string = 'v2:activeAccountId'

/** Returns the app-wide ActiveAccountState singleton from AppStorageV2. */
export function connectActiveAccount(): ActiveAccountState {
  return AppStorageV2.connect(ActiveAccountState, ACTIVE_ACCOUNT_V2_KEY, () => new ActiveAccountState())!
}
