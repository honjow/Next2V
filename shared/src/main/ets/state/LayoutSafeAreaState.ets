import { AppStorageV2 } from '@kit.ArkUI'
import { StorageKeys } from '../constants/StorageKeys'

/**
 * V2 mirror of the window safe-area / keyboard layout metrics.
 *
 * EntryAbility historically wrote these into V1 `AppStorage`
 * (`StorageKeys.TOP_AVOID_HEIGHT` / `BOTTOM_AVOID_HEIGHT` / `KEYBOARD_HEIGHT`) and
 * `@StorageProp` consumers read them. During the State Management V1->V2 backbone
 * migration the metrics live in BOTH stores at once: V1 `@StorageProp` readers keep
 * reading `AppStorage`, while `@ComponentV2` readers read these `@Trace` fields.
 * `EntryAbility` is the single writer and publishes through `LayoutSafeAreaBridge`,
 * so the two stores never diverge.
 *
 * Transitional: drop the `AppStorage` half (and this whole bridge) once every layout
 * reader has moved to V2.
 */
@ObservedV2
export class LayoutSafeAreaState {
  @Trace topAvoidHeight: number = 0
  @Trace bottomAvoidHeight: number = 0
  @Trace keyboardHeight: number = 0
}

// Single app-wide AppStorageV2 key for the shared safe-area state object.
const LAYOUT_SAFE_AREA_V2_KEY: string = 'v2:layoutSafeArea'

/**
 * Returns the app-wide `LayoutSafeAreaState` singleton from `AppStorageV2`, creating
 * it (zeroed) on first access. Reading its `@Trace` fields inside a `@ComponentV2`
 * `build()` subscribes that component to safe-area / keyboard changes.
 */
export function connectLayoutSafeArea(): LayoutSafeAreaState {
  return AppStorageV2.connect(
    LayoutSafeAreaState,
    LAYOUT_SAFE_AREA_V2_KEY,
    () => new LayoutSafeAreaState(),
  )!
}

/**
 * The single dual-write point for layout metrics. Writes both the legacy V1
 * `AppStorage` keys (still read by `@StorageProp` consumers) and the V2 mirror
 * (read by `@ComponentV2` consumers), keeping the two stores in lockstep until the
 * V1 readers are gone.
 */
export class LayoutSafeAreaBridge {
  static publishInsets(topAvoidHeight: number, bottomAvoidHeight: number): void {
    AppStorage.setOrCreate<number>(StorageKeys.TOP_AVOID_HEIGHT, topAvoidHeight)
    AppStorage.setOrCreate<number>(StorageKeys.BOTTOM_AVOID_HEIGHT, bottomAvoidHeight)
    const state = connectLayoutSafeArea()
    state.topAvoidHeight = topAvoidHeight
    state.bottomAvoidHeight = bottomAvoidHeight
  }

  static publishKeyboardHeight(keyboardHeight: number): void {
    AppStorage.setOrCreate<number>(StorageKeys.KEYBOARD_HEIGHT, keyboardHeight)
    connectLayoutSafeArea().keyboardHeight = keyboardHeight
  }
}
