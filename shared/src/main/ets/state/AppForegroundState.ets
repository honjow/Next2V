import { AppStorageV2 } from '@kit.ArkUI'

/**
 * App-wide foreground/background flag, written by EntryAbility's onForeground/onBackground lifecycle.
 * Read by AutoDailyCheckinService to choose how to surface a check-in result: the auto redeem finishes
 * ~10-15s after launch (often after the user has left the app), so a transient toast would be missed —
 * when backgrounded we post a system notification instead. Single-writer: only EntryAbility mutates it.
 */
@ObservedV2
export class AppForegroundState {
  // Starts true: the ability is foreground when it first loads content, and onForeground confirms it.
  @Trace foreground: boolean = true
}

const APP_FOREGROUND_V2_KEY: string = 'v2:appForeground'

/** Returns the app-wide AppForegroundState singleton from AppStorageV2. */
export function connectAppForeground(): AppForegroundState {
  return AppStorageV2.connect(
    AppForegroundState,
    APP_FOREGROUND_V2_KEY,
    () => new AppForegroundState(),
  )!
}

/** Single-writer publish helper used by EntryAbility's lifecycle callbacks. */
export function publishAppForeground(foreground: boolean): void {
  connectAppForeground().foreground = foreground
}
