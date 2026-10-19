import { AppStorageV2 } from '@kit.ArkUI'

export const SUBTAB_STYLE_UNDERLINE: string = 'underline'
export const SUBTAB_STYLE_CAPSULE: string = 'capsule'
// V2Next product decision (2026-10-19, revised same day): the default is capsule, aligning the
// fresh-install experience with NextE. An explicit saved preference (underline OR capsule) must
// survive startup through SubTabStyleSettings' restore; only users without any saved value see
// this default. The underline style itself stays fully available in the settings menu.
export const SUBTAB_STYLE_DEFAULT: string = SUBTAB_STYLE_CAPSULE

/**
 * V2 mirror of the shared sub-tab style setting ('layout.subTabStyle').
 *
 * Mirrors the NextE shared implementation (erosTeam/NextE#8 capsule sub-tabs, maintainer
 * commit ebd3f4b3), with the V2Next default kept as underline per the 2026-10-19 decision.
 * SubTabStyleSettings.apply() is the single writer; @ComponentV2 readers (the shared SubTabBar,
 * FeedPills, SettingsPage) connect this holder to repaint live on a style switch.
 */
@ObservedV2
export class SubTabStyleState {
  @Trace style: string = SUBTAB_STYLE_DEFAULT
}

const SUBTAB_STYLE_V2_KEY: string = 'v2:subTabStyle'

/** Returns the app-wide SubTabStyleState singleton from AppStorageV2. */
export function connectSubTabStyle(): SubTabStyleState {
  return AppStorageV2.connect(
    SubTabStyleState,
    SUBTAB_STYLE_V2_KEY,
    () => new SubTabStyleState(),
  )!
}
