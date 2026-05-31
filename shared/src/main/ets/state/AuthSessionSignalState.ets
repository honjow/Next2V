import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the auth session (`StorageKeys.AUTH_SESSION_UPDATED_AT` signal plus the
 * `AUTH_SESSION_USERNAME` / `AUTH_SESSION_AVATAR` / `AUTH_SESSION_VALIDATED_AT` identity fields).
 *
 * `AuthSessionSettings.apply` is the ONE chokepoint that writes all of these (login / logout /
 * re-validate route through it); it dual-writes the V1 `AppStorage` keys (still read by V1
 * `@StorageLink` pages: Index / NotificationPage) AND these `@Trace` fields, so the two stores never
 * diverge. `updatedAt` is the changed-signal pages `@Watch`/`@Monitor` to refresh; `username` /
 * `avatar` / `validatedAt` are the session identity the migrated `@ComponentV2` AccountPage /
 * AccountDetailPage read for display and the validate-skip window.
 *
 * Transitional: drop the `AppStorage` half once every reader has moved to V2.
 */
@ObservedV2
export class AuthSessionSignalState {
  @Trace updatedAt: number = 0
  @Trace username: string = ''
  @Trace avatar: string = ''
  @Trace validatedAt: number = 0
}

const AUTH_SESSION_SIGNAL_V2_KEY: string = 'v2:authSessionUpdatedAt'

/** Returns the app-wide AuthSessionSignalState singleton from AppStorageV2. */
export function connectAuthSessionSignal(): AuthSessionSignalState {
  return AppStorageV2.connect(AuthSessionSignalState, AUTH_SESSION_SIGNAL_V2_KEY, () => new AuthSessionSignalState())!
}
