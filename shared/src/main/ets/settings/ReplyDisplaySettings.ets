import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings } from '../i18n/AppStrings'
import { SettingDescriptor, applyDescriptorValue, readDescriptorValue } from './SettingsDescriptor'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_REPLY_DISPLAY_MODE: string = StorageKeys.REPLY_DISPLAY_MODE
const MODE_THREAD: string = 'thread'
const MODE_THREAD_WITH_MENTION: string = 'threadWithMention'
const MODE_THREAD_REDUNDANT: string = 'threadRedundant'
const MODE_OP: string = 'op'
const MODE_ORIGIN: string = 'origin'

function normalizeReplyDisplayMode(mode: string): string {
  const value = (mode || '').trim()
  if (value === MODE_THREAD_WITH_MENTION || value === MODE_THREAD_REDUNDANT || value === MODE_OP || value === MODE_ORIGIN) {
    return value
  }
  return MODE_THREAD
}

class ReplyDisplayModeDescriptor implements SettingDescriptor<string> {
  readonly storageKey: string = StorageKeys.REPLY_DISPLAY_MODE
  readonly preferenceKey: string = KEY_REPLY_DISPLAY_MODE
  readonly defaultValue: string = MODE_THREAD

  normalize(mode: string): string {
    return normalizeReplyDisplayMode(mode)
  }
}

export const REPLY_DISPLAY_MODE_DESCRIPTOR: SettingDescriptor<string> = new ReplyDisplayModeDescriptor()

export class ReplyDisplaySettings {
  static readonly MODE_THREAD: string = MODE_THREAD
  static readonly MODE_THREAD_WITH_MENTION: string = MODE_THREAD_WITH_MENTION
  static readonly MODE_THREAD_REDUNDANT: string = MODE_THREAD_REDUNDANT
  static readonly MODE_OP: string = MODE_OP
  static readonly MODE_ORIGIN: string = MODE_ORIGIN

  static apply(mode: string): void {
    applyDescriptorValue<string>(REPLY_DISPLAY_MODE_DESCRIPTOR, mode)
  }

  static async load(context: common.UIAbilityContext): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return ReplyDisplaySettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取回复显示设置失败')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<string> {
    const normalized = readDescriptorValue<string>(store, REPLY_DISPLAY_MODE_DESCRIPTOR)
    ReplyDisplaySettings.apply(normalized)
    return normalized
  }

  static async save(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized = applyDescriptorValue<string>(REPLY_DISPLAY_MODE_DESCRIPTOR, mode)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_REPLY_DISPLAY_MODE, normalized)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存回复显示设置失败')
    }
  }

  static normalizeMode(mode: string): string {
    return REPLY_DISPLAY_MODE_DESCRIPTOR.normalize(mode)
  }

  static modeText(mode: string): string {
    const value = ReplyDisplaySettings.normalizeMode(mode)
    if (value === MODE_THREAD_WITH_MENTION) {
      return AppStrings.text(AppStrings.R_THREADED_AT, 'Threaded (@)')
    }
    if (value === MODE_THREAD_REDUNDANT) {
      return AppStrings.text(AppStrings.R_THREADED_REDUNDANT, 'Redundant threaded')
    }
    if (value === MODE_OP) {
      return AppStrings.text(AppStrings.R_OP_ONLY, 'Original poster only')
    }
    if (value === MODE_ORIGIN) {
      return AppStrings.text(AppStrings.R_ORIGINAL, 'Original')
    }
    return AppStrings.text(AppStrings.R_THREADED, 'Threaded')
  }
}
