import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings } from '../i18n/AppStrings'
import { SettingDescriptor, applyDescriptorValue, readDescriptorValue } from './SettingsDescriptor'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_REPLY_ACTION_ALIGNMENT_MODE: string = StorageKeys.REPLY_ACTION_ALIGNMENT_MODE

export type ReplyActionAlignmentMode = 'smartGrip' | 'followOperation' | 'fixedLeft' | 'fixedRight' | ''

export interface ReplyActionAlignmentOption {
  label: string
  mode: ReplyActionAlignmentMode
}

function normalizeReplyActionAlignmentMode(mode: string): ReplyActionAlignmentMode {
  const value = (mode || '').trim()
  if (
    value === ReplyActionAlignmentSettings.MODE_SMART_GRIP ||
    value === ReplyActionAlignmentSettings.MODE_FOLLOW_OPERATION ||
    value === ReplyActionAlignmentSettings.MODE_FIXED_LEFT ||
    value === ReplyActionAlignmentSettings.MODE_FIXED_RIGHT
  ) {
    return value as ReplyActionAlignmentMode
  }
  return ReplyActionAlignmentSettings.MODE_UNSET
}

class ReplyActionAlignmentModeDescriptor implements SettingDescriptor<string> {
  readonly storageKey: string = StorageKeys.REPLY_ACTION_ALIGNMENT_MODE
  readonly preferenceKey: string = KEY_REPLY_ACTION_ALIGNMENT_MODE
  readonly defaultValue: string = ''

  normalize(mode: string): string {
    return normalizeReplyActionAlignmentMode(mode)
  }
}

export const REPLY_ACTION_ALIGNMENT_MODE_DESCRIPTOR: SettingDescriptor<string> = new ReplyActionAlignmentModeDescriptor()

export class ReplyActionAlignmentSettings {
  static readonly MODE_UNSET: ReplyActionAlignmentMode = ''
  static readonly MODE_SMART_GRIP: ReplyActionAlignmentMode = 'smartGrip'
  static readonly MODE_FOLLOW_OPERATION: ReplyActionAlignmentMode = 'followOperation'
  static readonly MODE_FIXED_LEFT: ReplyActionAlignmentMode = 'fixedLeft'
  static readonly MODE_FIXED_RIGHT: ReplyActionAlignmentMode = 'fixedRight'

  static apply(mode: string): void {
    applyDescriptorValue<string>(REPLY_ACTION_ALIGNMENT_MODE_DESCRIPTOR, mode)
  }

  static async load(context: common.UIAbilityContext): Promise<ReplyActionAlignmentMode> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return ReplyActionAlignmentSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取回复按钮对齐方式失败')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<ReplyActionAlignmentMode> {
    const normalized = readDescriptorValue<string>(store, REPLY_ACTION_ALIGNMENT_MODE_DESCRIPTOR) as ReplyActionAlignmentMode
    ReplyActionAlignmentSettings.apply(normalized)
    return normalized
  }

  static async save(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized = applyDescriptorValue<string>(REPLY_ACTION_ALIGNMENT_MODE_DESCRIPTOR, mode)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_REPLY_ACTION_ALIGNMENT_MODE, normalized)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存回复按钮对齐方式失败')
    }
  }

  static normalizeMode(mode: string): ReplyActionAlignmentMode {
    return REPLY_ACTION_ALIGNMENT_MODE_DESCRIPTOR.normalize(mode) as ReplyActionAlignmentMode
  }

  static defaultMode(smartGripSupported: boolean): ReplyActionAlignmentMode {
    return smartGripSupported
      ? ReplyActionAlignmentSettings.MODE_SMART_GRIP
      : ReplyActionAlignmentSettings.MODE_FOLLOW_OPERATION
  }

  static effectiveMode(mode: string, smartGripSupported: boolean): ReplyActionAlignmentMode {
    const normalized = ReplyActionAlignmentSettings.normalizeMode(mode)
    if (normalized === ReplyActionAlignmentSettings.MODE_UNSET) {
      return ReplyActionAlignmentSettings.defaultMode(smartGripSupported)
    }
    if (normalized === ReplyActionAlignmentSettings.MODE_SMART_GRIP && !smartGripSupported) {
      return ReplyActionAlignmentSettings.MODE_FOLLOW_OPERATION
    }
    return normalized
  }

  static modeText(mode: string, smartGripSupported: boolean): string {
    const effective = ReplyActionAlignmentSettings.effectiveMode(mode, smartGripSupported)
    if (effective === ReplyActionAlignmentSettings.MODE_SMART_GRIP) {
      return AppStrings.t(AppStrings.R_SMART_GRIP, 'Smart grip')
    }
    if (effective === ReplyActionAlignmentSettings.MODE_FIXED_LEFT) {
      return AppStrings.t(AppStrings.R_FIXED_LEFT, 'Fixed left')
    }
    if (effective === ReplyActionAlignmentSettings.MODE_FIXED_RIGHT) {
      return AppStrings.t(AppStrings.R_FIXED_RIGHT, 'Fixed right')
    }
    return AppStrings.t(AppStrings.R_FOLLOW_OPERATION, 'Follow operation')
  }

  static availableOptions(smartGripSupported: boolean): ReplyActionAlignmentOption[] {
    const options: ReplyActionAlignmentOption[] = []
    if (smartGripSupported) {
      options.push({ label: AppStrings.t(AppStrings.R_SMART_GRIP, 'Smart grip'), mode: ReplyActionAlignmentSettings.MODE_SMART_GRIP })
    }
    options.push({ label: AppStrings.t(AppStrings.R_FOLLOW_OPERATION, 'Follow operation'), mode: ReplyActionAlignmentSettings.MODE_FOLLOW_OPERATION })
    options.push({ label: AppStrings.t(AppStrings.R_FIXED_LEFT, 'Fixed left'), mode: ReplyActionAlignmentSettings.MODE_FIXED_LEFT })
    options.push({ label: AppStrings.t(AppStrings.R_FIXED_RIGHT, 'Fixed right'), mode: ReplyActionAlignmentSettings.MODE_FIXED_RIGHT })
    return options
  }
}
