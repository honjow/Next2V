import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the home-tab auto-hide preference (`StorageKeys.HOME_TAB_AUTO_HIDE`).
 *
 * Dual-written at the single settings chokepoint `HomeTabSettings.save`; the migrated `@ComponentV2`
 * `Index` reads this `@Trace` field and `@Monitor`s it to (un)bind the tab scrollers. Transitional:
 * drop the AppStorage half once no V1 `@StorageLink` reads the key.
 */
@ObservedV2
export class HomeTabAutoHideState {
  @Trace autoHide: boolean = true
}

const HOME_TAB_AUTO_HIDE_V2_KEY: string = 'v2:homeTabAutoHide'

/** Returns the app-wide HomeTabAutoHideState singleton from AppStorageV2. */
export function connectHomeTabAutoHide(): HomeTabAutoHideState {
  return AppStorageV2.connect(HomeTabAutoHideState, HOME_TAB_AUTO_HIDE_V2_KEY, () => new HomeTabAutoHideState())!
}
