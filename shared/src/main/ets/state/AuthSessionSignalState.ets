import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the auth-session-changed signal (`StorageKeys.AUTH_SESSION_UPDATED_AT`).
 *
 * `AuthSessionSettings.apply` bumps this timestamp whenever the login session changes
 * (login / logout / re-validate); pages `@Watch`/`@Monitor` it to refresh themselves. The
 * value is written at ONE chokepoint (`AuthSessionSettings.apply`), which dual-writes the
 * V1 `AppStorage` key (still read by V1 `@StorageLink` pages: Index / AccountPage /
 * AccountDetailPage / NotificationPage) AND this `@Trace` field, so the two stores never
 * diverge.
 *
 * A `@ComponentV2` consumer holds the singleton and runs a side-effect via
 * `@Monitor('<member>.updatedAt')` when the session changes.
 *
 * Transitional: drop the `AppStorage` half once every reader has moved to V2.
 */
@ObservedV2
export class AuthSessionSignalState {
  @Trace updatedAt: number = 0
}

const AUTH_SESSION_SIGNAL_V2_KEY: string = 'v2:authSessionUpdatedAt'

/** Returns the app-wide AuthSessionSignalState singleton from AppStorageV2. */
export function connectAuthSessionSignal(): AuthSessionSignalState {
  return AppStorageV2.connect(AuthSessionSignalState, AUTH_SESSION_SIGNAL_V2_KEY, () => new AuthSessionSignalState())!
}
