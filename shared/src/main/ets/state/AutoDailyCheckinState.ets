import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the auto daily check-in ON/OFF toggle (`StorageKeys.AUTO_DAILY_CHECKIN_ENABLED`).
 * `AutoDailyCheckinSettings.apply()` is the single chokepoint that publishes this `@Trace` field; the
 * SettingsPage switch reads it. There is no "last attempt / last success" state — V2EX is the source of
 * truth, so the service never persists a "signed today" flag.
 */
@ObservedV2
export class AutoDailyCheckinState {
  @Trace enabled: boolean = true
}

const AUTO_DAILY_CHECKIN_V2_KEY: string = 'v2:autoDailyCheckin'

/** Returns the app-wide AutoDailyCheckinState singleton from AppStorageV2. */
export function connectAutoDailyCheckin(): AutoDailyCheckinState {
  return AppStorageV2.connect(
    AutoDailyCheckinState,
    AUTO_DAILY_CHECKIN_V2_KEY,
    () => new AutoDailyCheckinState(),
  )!
}
