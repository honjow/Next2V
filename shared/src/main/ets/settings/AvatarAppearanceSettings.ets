import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings } from '../i18n/AppStrings'
import { SettingDescriptor, applyDescriptorValue, readDescriptorValue } from './SettingsDescriptor'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore } from './SettingsStorage'
import { connectAvatarAppearance } from '../state/AvatarAppearanceState'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_AVATAR_APPEARANCE: string = StorageKeys.AVATAR_APPEARANCE
const APPEARANCE_CIRCLE: string = 'circle'
const APPEARANCE_SOFT: string = 'soft'

function normalizeAvatarAppearance(appearance: string): string {
  const value = (appearance || '').trim()
  if (value === APPEARANCE_SOFT) {
    return value
  }
  return APPEARANCE_CIRCLE
}

class AvatarAppearanceDescriptor implements SettingDescriptor<string> {
  readonly storageKey: string = StorageKeys.AVATAR_APPEARANCE
  readonly preferenceKey: string = KEY_AVATAR_APPEARANCE
  readonly defaultValue: string = APPEARANCE_CIRCLE

  normalize(appearance: string): string {
    return normalizeAvatarAppearance(appearance)
  }
}

export const AVATAR_APPEARANCE_DESCRIPTOR: SettingDescriptor<string> = new AvatarAppearanceDescriptor()

export class AvatarAppearanceSettings {
  static readonly APPEARANCE_CIRCLE: string = APPEARANCE_CIRCLE
  static readonly APPEARANCE_SOFT: string = APPEARANCE_SOFT

  // Single dual-write point: writes the legacy V1 AppStorage key (applyDescriptorValue
  // -> setAppStorageValue) AND the V2 mirror, so @StorageProp and @ComponentV2 readers
  // stay in lockstep during the migration. Returns the normalized value.
  static apply(appearance: string): string {
    const normalized = applyDescriptorValue<string>(AVATAR_APPEARANCE_DESCRIPTOR, appearance)
    connectAvatarAppearance().appearance = normalized
    return normalized
  }

  static async load(context: common.UIAbilityContext): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return AvatarAppearanceSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read avatar appearance settings')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<string> {
    const normalized = readDescriptorValue<string>(store, AVATAR_APPEARANCE_DESCRIPTOR)
    AvatarAppearanceSettings.apply(normalized)
    return normalized
  }

  static async save(context: common.UIAbilityContext, appearance: string): Promise<void> {
    // Route through apply() so the AppStorage write AND the V2 mirror stay in sync.
    const normalized = AvatarAppearanceSettings.apply(appearance)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_AVATAR_APPEARANCE, normalized)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save avatar appearance settings')
    }
  }

  static normalize(appearance: string): string {
    return AVATAR_APPEARANCE_DESCRIPTOR.normalize(appearance)
  }

  static radiusForSize(avatarSize: number, appearance: string): number {
    if (AvatarAppearanceSettings.normalize(appearance) === APPEARANCE_SOFT) {
      return Math.round(Math.max(8, Math.min(avatarSize * 0.28, avatarSize / 2)))
    }
    return avatarSize / 2
  }

  static appearanceText(appearance: string): string {
    if (AvatarAppearanceSettings.normalize(appearance) === APPEARANCE_SOFT) {
      return AppStrings.text(AppStrings.R_AVATAR_APPEARANCE_SOFT, 'Soft')
    }
    return AppStrings.text(AppStrings.R_AVATAR_APPEARANCE_CIRCLE, 'Circle')
  }
}
