import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the API-token auth identity (`StorageKeys.AUTH_TOKEN_CONFIGURED` /
 * `StorageKeys.AUTH_USERNAME`).
 *
 * `AuthSettings.apply(token, username)` is the ONE chokepoint that writes both keys (load / saveToken
 * / clear all route through it); it dual-writes the V1 `AppStorage` keys (still read by V1
 * `@StorageLink`) AND these `@Trace` fields, read by the migrated `@ComponentV2` AccountPage
 * (token-account presence + fallback username display).
 *
 * Transitional: drop the `AppStorage` half once every reader has moved to V2.
 */
@ObservedV2
export class AuthIdentityState {
  @Trace tokenConfigured: boolean = false
  @Trace username: string = ''
}

const AUTH_IDENTITY_V2_KEY: string = 'v2:authIdentity'

/** Returns the app-wide AuthIdentityState singleton from AppStorageV2. */
export function connectAuthIdentity(): AuthIdentityState {
  return AppStorageV2.connect(AuthIdentityState, AUTH_IDENTITY_V2_KEY, () => new AuthIdentityState())!
}
