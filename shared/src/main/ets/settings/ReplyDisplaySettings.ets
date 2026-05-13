import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'

const STORE_NAME: string = 'next2v_settings'
const KEY_REPLY_DISPLAY_MODE: string = 'replyDisplayMode'
const MODE_THREAD: string = 'thread'
const MODE_THREAD_WITH_MENTION: string = 'threadWithMention'
const MODE_THREAD_REDUNDANT: string = 'threadRedundant'
const MODE_OP: string = 'op'
const MODE_ORIGIN: string = 'origin'

export class ReplyDisplaySettings {
  static readonly MODE_THREAD: string = MODE_THREAD
  static readonly MODE_THREAD_WITH_MENTION: string = MODE_THREAD_WITH_MENTION
  static readonly MODE_THREAD_REDUNDANT: string = MODE_THREAD_REDUNDANT
  static readonly MODE_OP: string = MODE_OP
  static readonly MODE_ORIGIN: string = MODE_ORIGIN

  static apply(mode: string): void {
    ReplyDisplaySettings.setAppStorageValue<string>(StorageKeys.REPLY_DISPLAY_MODE, ReplyDisplaySettings.normalizeMode(mode))
  }

  static async load(context: common.UIAbilityContext): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const mode = ReplyDisplaySettings.normalizeMode(store.getSync(KEY_REPLY_DISPLAY_MODE, MODE_THREAD) as string)
      ReplyDisplaySettings.apply(mode)
      return mode
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取回复显示设置失败')
    }
  }

  static async save(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalizedMode = ReplyDisplaySettings.normalizeMode(mode)
    ReplyDisplaySettings.apply(normalizedMode)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_REPLY_DISPLAY_MODE, normalizedMode)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存回复显示设置失败')
    }
  }

  static normalizeMode(mode: string): string {
    const value = (mode || '').trim()
    if (value === MODE_THREAD_WITH_MENTION || value === MODE_THREAD_REDUNDANT || value === MODE_OP || value === MODE_ORIGIN) {
      return value
    }
    return MODE_THREAD
  }

  static modeText(mode: string): string {
    const value = ReplyDisplaySettings.normalizeMode(mode)
    if (value === MODE_THREAD_WITH_MENTION) {
      return '楼中楼(@)'
    }
    if (value === MODE_THREAD_REDUNDANT) {
      return '冗余楼中楼'
    }
    if (value === MODE_OP) {
      return '只看楼主'
    }
    if (value === MODE_ORIGIN) {
      return '原版'
    }
    return '楼中楼'
  }

  private static setAppStorageValue<T>(key: string, value: T): void {
    if (!AppStorage.set<T>(key, value)) {
      AppStorage.setOrCreate<T>(key, value)
    }
  }
}
