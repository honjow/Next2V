import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the avatar-appearance setting (`StorageKeys.AVATAR_APPEARANCE`).
 *
 * `AvatarAppearanceSettings.apply()` is the single AppStorage writer for this key
 * (settings hydration + the settings-page dropdown both route through it). During the
 * State Management V1->V2 backbone migration it dual-writes: the legacy `AppStorage`
 * key (read by any remaining V1 `@StorageProp`, e.g. `SettingsPage`) AND this `@Trace`
 * field (read by `@ComponentV2` `Avatar`). Transitional — drop the `AppStorage` half
 * once every appearance reader is V2.
 */
@ObservedV2
export class AvatarAppearanceState {
  // Default mirrors AvatarAppearanceSettings.APPEARANCE_SOFT ('soft'); the real
  // value is published by AvatarAppearanceSettings.apply() at hydration.
  @Trace appearance: string = 'soft'
}

const AVATAR_APPEARANCE_V2_KEY: string = 'v2:avatarAppearance'

/** Returns the app-wide AvatarAppearanceState singleton from AppStorageV2. */
export function connectAvatarAppearance(): AvatarAppearanceState {
  return AppStorageV2.connect(
    AvatarAppearanceState,
    AVATAR_APPEARANCE_V2_KEY,
    () => new AvatarAppearanceState(),
  )!
}
