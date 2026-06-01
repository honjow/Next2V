import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 store of the API rate-limit snapshot (limit / remaining / reset / updatedAt).
 *
 * `ApiV2Service.saveRateLimitSnapshot()` is the ONE chokepoint that writes this snapshot after each
 * authenticated API response, updating these `@Trace` fields read by the migrated `@ComponentV2`
 * AccountPage's rate-limit summary so it updates live as requests are made.
 *
 * This is the sole store: the legacy `AppStorage` (`StorageKeys.API_RATE_LIMIT_*`) dual-write was
 * retired once every reader moved to V2. Do not reintroduce a legacy `AppStorage` half.
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
