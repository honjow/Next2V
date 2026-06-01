import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the auto daily check-in runtime state (`StorageKeys.AUTO_DAILY_CHECKIN_ENABLED` and the
 * last-attempt / last-success breadcrumb keys).
 *
 * `AutoDailyCheckinSettings.apply()` is the single chokepoint — hydration `loadFromStore`, settings
 * `save`, and the `saveLast*` state writers all route through it — and it publishes these `@Trace`
 * fields while still mirroring the preferences-backed AppStorage keys for the contract-pinned settings
 * hydration path. `AutoDailyCheckinSettings`' getters (used by `AutoDailyCheckinService`'s skip/dedup
 * logic) read this mirror; defaults match the settings defaults (enabled = true, breadcrumbs empty).
 */
@ObservedV2
export class AutoDailyCheckinState {
  @Trace enabled: boolean = true
  @Trace lastAttemptDate: string = ''
  @Trace lastAttemptIdentity: string = ''
  @Trace lastSuccessDate: string = ''
}

const AUTO_DAILY_CHECKIN_V2_KEY: string = 'v2:autoDailyCheckin'

/** Returns the app-wide AutoDailyCheckinState singleton from AppStorageV2. */
export function connectAutoDailyCheckin(): AutoDailyCheckinState {
  return AppStorageV2.connect(AutoDailyCheckinState, AUTO_DAILY_CHECKIN_V2_KEY, () => new AutoDailyCheckinState())!
}
