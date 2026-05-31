import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the API rate-limit snapshot (`StorageKeys.API_RATE_LIMIT_LIMIT` / `_REMAINING` /
 * `_RESET` / `_UPDATED_AT`).
 *
 * `ApiV2Service.saveRateLimitSnapshot()` is the ONE chokepoint that writes those keys after each
 * authenticated API response; it dual-writes the V1 `AppStorage` keys (still read by V1
 * `@StorageLink`) AND these `@Trace` fields, read by the migrated `@ComponentV2` AccountPage's
 * rate-limit summary so it updates live as requests are made.
 *
 * Transitional: drop the `AppStorage` half once every reader has moved to V2.
 */
@ObservedV2
export class ApiRateLimitState {
  @Trace limit: number = 0
  @Trace remaining: number = 0
  @Trace reset: number = 0
  @Trace updatedAt: number = 0
}

const API_RATE_LIMIT_V2_KEY: string = 'v2:apiRateLimit'

/** Returns the app-wide ApiRateLimitState singleton from AppStorageV2. */
export function connectApiRateLimit(): ApiRateLimitState {
  return AppStorageV2.connect(ApiRateLimitState, API_RATE_LIMIT_V2_KEY, () => new ApiRateLimitState())!
}
