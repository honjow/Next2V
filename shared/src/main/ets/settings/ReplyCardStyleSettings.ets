import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'

const STORE_NAME: string = 'next2v_settings'
const KEY_REPLY_CARD_STYLE: string = 'replyCardStyle'
const STYLE_STANDARD: string = 'standard'
const STYLE_COMPACT: string = 'compact'

export class ReplyCardStyleSettings {
  static readonly STYLE_STANDARD: string = STYLE_STANDARD
  static readonly STYLE_COMPACT: string = STYLE_COMPACT

  static apply(style: string): void {
    ReplyCardStyleSettings.setAppStorageValue<string>(
      StorageKeys.REPLY_CARD_STYLE,
      ReplyCardStyleSettings.normalize(style),
    )
  }

  static async load(context: common.UIAbilityContext): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const style = ReplyCardStyleSettings.normalize(
        store.getSync(KEY_REPLY_CARD_STYLE, STYLE_STANDARD) as string,
      )
      ReplyCardStyleSettings.apply(style)
      return style
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取回复样式设置失败')
    }
  }

  static async save(context: common.UIAbilityContext, style: string): Promise<void> {
    const normalized = ReplyCardStyleSettings.normalize(style)
    ReplyCardStyleSettings.apply(normalized)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_REPLY_CARD_STYLE, normalized)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存回复样式设置失败')
    }
  }

  static normalize(style: string): string {
    const value = (style || '').trim()
    if (value === STYLE_COMPACT) {
      return value
    }
    return STYLE_STANDARD
  }

  static styleText(style: string): string {
    if (ReplyCardStyleSettings.normalize(style) === STYLE_COMPACT) {
      return '紧凑'
    }
    return '标准'
  }

  private static setAppStorageValue<T>(key: string, value: T): void {
    if (!AppStorage.set<T>(key, value)) {
      AppStorage.setOrCreate<T>(key, value)
    }
  }
}
