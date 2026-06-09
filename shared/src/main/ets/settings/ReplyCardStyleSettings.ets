import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings } from '../i18n/AppStrings'
import { SettingDescriptor, applyDescriptorValue, readDescriptorValue } from './SettingsDescriptor'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore } from './SettingsStorage'
import { connectReplyCardStyle } from '../state/ReplyCardStyleState'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_REPLY_CARD_STYLE: string = StorageKeys.REPLY_CARD_STYLE
const STYLE_STANDARD: string = 'standard'
const STYLE_COMPACT: string = 'compact'

function normalizeReplyCardStyle(style: string): string {
  const value = (style || '').trim()
  if (value === STYLE_COMPACT) {
    return value
  }
  return STYLE_STANDARD
}

class ReplyCardStyleDescriptor implements SettingDescriptor<string> {
  readonly storageKey: string = StorageKeys.REPLY_CARD_STYLE
  readonly preferenceKey: string = KEY_REPLY_CARD_STYLE
  readonly defaultValue: string = STYLE_STANDARD

  normalize(style: string): string {
    return normalizeReplyCardStyle(style)
  }
}

export const REPLY_CARD_STYLE_DESCRIPTOR: SettingDescriptor<string> = new ReplyCardStyleDescriptor()

export class ReplyCardStyleSettings {
  static readonly STYLE_STANDARD: string = STYLE_STANDARD
  static readonly STYLE_COMPACT: string = STYLE_COMPACT

  static apply(style: string): string {
    const normalized = applyDescriptorValue<string>(REPLY_CARD_STYLE_DESCRIPTOR, style)
    // V2 mirror dual-write: keeps the migrated @ComponentV2 ReplyCard in sync with the legacy
    // AppStorage key still read by the V1 SettingsPage @StorageLink. apply() is the single
    // AppStorage writer for REPLY_CARD_STYLE — both load and save route through it.
    connectReplyCardStyle().replyCardStyle = normalized
    return normalized
  }

  static async load(context: common.UIAbilityContext): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return ReplyCardStyleSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read reply style settings')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<string> {
    const normalized = readDescriptorValue<string>(store, REPLY_CARD_STYLE_DESCRIPTOR)
    ReplyCardStyleSettings.apply(normalized)
    return normalized
  }

  static async save(context: common.UIAbilityContext, style: string): Promise<void> {
    const normalized = ReplyCardStyleSettings.apply(style)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_REPLY_CARD_STYLE, normalized)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save reply style settings')
    }
  }

  static normalize(style: string): string {
    return REPLY_CARD_STYLE_DESCRIPTOR.normalize(style)
  }

  static styleText(style: string): string {
    if (ReplyCardStyleSettings.normalize(style) === STYLE_COMPACT) {
      return AppStrings.text($r('app.string.density_compact'), 'Compact')
    }
    return AppStrings.text($r('app.string.density_standard'), 'Standard')
  }
}
