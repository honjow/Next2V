import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ApiConstants, TabItem } from '../constants/ApiConstants'
import { StorageKeys } from '../constants/StorageKeys'

const STORE_NAME: string = 'next2v_feed_tabs'
const KEY_VISIBLE_KEYS: string = 'visibleKeys'

export class FeedTabSettings {
  static defaultKeys(): string[] {
    return ApiConstants.TAB_ITEMS.map((tab: TabItem) => tab.key)
  }

  static defaultKeysJson(): string {
    return JSON.stringify(FeedTabSettings.defaultKeys())
  }

  static tabsFromKeysJson(keysJson: string): TabItem[] {
    return FeedTabSettings.tabsFromKeys(FeedTabSettings.parseKeys(keysJson))
  }

  static tabsFromKeys(keys: string[]): TabItem[] {
    const normalized = FeedTabSettings.normalizeKeys(keys)
    return normalized.map((key: string) => ApiConstants.TAB_ITEMS.find((tab: TabItem) => tab.key === key))
      .filter((tab: TabItem | undefined) => !!tab) as TabItem[]
  }

  static isDefault(keysJson: string): boolean {
    return FeedTabSettings.normalizeKeys(FeedTabSettings.parseKeys(keysJson)).join(',') === FeedTabSettings.defaultKeys().join(',')
  }

  static isVisible(keysJson: string, key: string): boolean {
    return FeedTabSettings.normalizeKeys(FeedTabSettings.parseKeys(keysJson)).indexOf(key) >= 0
  }

  static toggleKey(keysJson: string, key: string): string {
    const keys = FeedTabSettings.normalizeKeys(FeedTabSettings.parseKeys(keysJson))
    const idx = keys.indexOf(key)
    if (idx >= 0) {
      if (keys.length <= 1) {
        return JSON.stringify(keys)
      }
      keys.splice(idx, 1)
    } else if (ApiConstants.TAB_ITEMS.find((tab: TabItem) => tab.key === key)) {
      keys.push(key)
    }
    return JSON.stringify(FeedTabSettings.normalizeKeys(keys))
  }

  static async load(context: common.UIAbilityContext): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const keysJson = store.getSync(KEY_VISIBLE_KEYS, FeedTabSettings.defaultKeysJson()) as string
      const normalized = JSON.stringify(FeedTabSettings.normalizeKeys(FeedTabSettings.parseKeys(keysJson)))
      FeedTabSettings.apply(normalized)
      return normalized
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取首页栏目设置失败')
    }
  }

  static async save(context: common.UIAbilityContext, keysJson: string): Promise<string> {
    try {
      const normalized = JSON.stringify(FeedTabSettings.normalizeKeys(FeedTabSettings.parseKeys(keysJson)))
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_VISIBLE_KEYS, normalized)
      store.flushSync()
      FeedTabSettings.apply(normalized)
      return normalized
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存首页栏目设置失败')
    }
  }

  static apply(keysJson: string): void {
    AppStorage.setOrCreate<string>(StorageKeys.FEED_TAB_KEYS, keysJson || FeedTabSettings.defaultKeysJson())
  }

  private static parseKeys(keysJson: string): string[] {
    try {
      const parsed = JSON.parse(keysJson || '[]') as string[]
      return Array.isArray(parsed) ? parsed.filter((key: string) => typeof key === 'string') : []
    } catch (_e) {
      return []
    }
  }

  private static normalizeKeys(keys: string[]): string[] {
    const valid = ApiConstants.TAB_ITEMS.map((tab: TabItem) => tab.key)
    const result: string[] = []
    for (const key of keys) {
      if (valid.indexOf(key) < 0 || result.indexOf(key) >= 0) {
        continue
      }
      result.push(key)
    }
    if (result.length === 0) {
      return FeedTabSettings.defaultKeys()
    }
    return result
  }
}
