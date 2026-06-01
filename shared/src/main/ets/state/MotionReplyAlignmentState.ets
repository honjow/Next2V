import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 store of the reply-action alignment runtime state:
 *   - `alignmentMode` mirrors `StorageKeys.REPLY_ACTION_ALIGNMENT_MODE` ('' | 'smartGrip' |
 *     'followOperation' | 'fixedLeft' | 'fixedRight'). `ReplyActionAlignmentSettings.apply()` (the
 *     settings chokepoint, also hit by SettingsBootstrap.restoreReplyActionAlignment) seeds it while
 *     still projecting the legacy AppStorage key via the shared descriptor; `MotionHandStateService`
 *     additionally writes a resolved default here (runtime carrier, not persisted) when the mode is
 *     unset, exactly as it previously wrote the AppStorage key.
 *   - `holdingHandSupported` mirrors `StorageKeys.MOTION_HOLDING_HAND_SUPPORTED`; `MotionHandStateService`
 *     is its sole writer (true/false on holdingHandChanged subscription success/failure).
 *
 * The migrated readers — SettingsPage hydration and MotionHandStateService's effective-mode /
 * default-resolution logic — read these `@Trace` fields instead of `AppStorage.get`. Defaults match the
 * prior `?? MODE_UNSET` / `?? false` fallbacks.
 */
@ObservedV2
export class MotionReplyAlignmentState {
  @Trace alignmentMode: string = ''
  @Trace holdingHandSupported: boolean = false
}

const MOTION_REPLY_ALIGNMENT_V2_KEY: string = 'v2:motionReplyAlignment'

/** Returns the app-wide MotionReplyAlignmentState singleton from AppStorageV2. */
export function connectMotionReplyAlignment(): MotionReplyAlignmentState {
  return AppStorageV2.connect(
    MotionReplyAlignmentState,
    MOTION_REPLY_ALIGNMENT_V2_KEY,
    () => new MotionReplyAlignmentState(),
  )!
}
