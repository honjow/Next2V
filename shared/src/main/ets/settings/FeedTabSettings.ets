import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ApiConstants, TabItem } from '../constants/ApiConstants'
import { StorageKeys } from '../constants/StorageKeys'
import { FeedTabBridge } from '../state/FeedTabState'
import { STORE_NAME_FEED_TABS } from './SettingsStores'

const STORE_NAME: string = STORE_NAME_FEED_TABS
const KEY_VISIBLE_KEYS: string = 'visibleKeys'
const KEY_LAST_SELECTED_KEY: string = 'lastSelectedKey'
const NODE_KEY_PREFIX: string = 'node:'

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
    const tabs: TabItem[] = []
    for (const key of normalized) {
      const builtIn = ApiConstants.TAB_ITEMS.find((tab: TabItem) => tab.key === key)
      if (builtIn) {
        tabs.push(builtIn)
        continue
      }
      const nodeName = FeedTabSettings.nodeNameFromKey(key)
      if (nodeName) {
        tabs.push({ key, label: nodeName })
      }
    }
    return tabs
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

  static moveKey(keysJson: string, key: string, direction: number): string {
    const keys = FeedTabSettings.normalizeKeys(FeedTabSettings.parseKeys(keysJson))
    const idx = keys.indexOf(key)
    if (idx < 0) {
      return JSON.stringify(keys)
    }
    const nextIdx = idx + direction
    if (nextIdx < 0 || nextIdx >= keys.length) {
      return JSON.stringify(keys)
    }
    const item = keys[idx]
    keys.splice(idx, 1)
    keys.splice(nextIdx, 0, item)
    return JSON.stringify(FeedTabSettings.normalizeKeys(keys))
  }

  static addNode(keysJson: string, nodeName: string): string {
    const cleanName = FeedTabSettings.normalizeNodeName(nodeName)
    if (!cleanName) {
      return keysJson
    }
    const keys = FeedTabSettings.normalizeKeys(FeedTabSettings.parseKeys(keysJson))
    const key = FeedTabSettings.nodeKey(cleanName)
    if (keys.indexOf(key) < 0) {
      keys.push(key)
    }
    return JSON.stringify(FeedTabSettings.normalizeKeys(keys))
  }

  static isNodeKey(key: string): boolean {
    return FeedTabSettings.nodeNameFromKey(key).length > 0
  }

  static nodeNameFromKey(key: string): string {
    if (!key || key.indexOf(NODE_KEY_PREFIX) !== 0) {
      return ''
    }
    return FeedTabSettings.normalizeNodeName(key.slice(NODE_KEY_PREFIX.length))
  }

  static normalizeNodeName(nodeName: string): string {
    const clean = (nodeName || '').trim().toLowerCase()
    return /^[a-z0-9_-]{1,48}$/.test(clean) ? clean : ''
  }

  static async load(context: common.UIAbilityContext): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const keysJson = store.getSync(KEY_VISIBLE_KEYS, FeedTabSettings.defaultKeysJson()) as string
      const lastSelectedKey = store.getSync(KEY_LAST_SELECTED_KEY, '') as string
      const normalized = JSON.stringify(FeedTabSettings.normalizeKeys(FeedTabSettings.parseKeys(keysJson)))
      FeedTabSettings.apply(normalized)
      const selectedKey = FeedTabSettings.selectedKeyOrFallback(normalized, lastSelectedKey)
      FeedTabSettings.applySelectedKey(selectedKey)
      if (selectedKey !== lastSelectedKey) {
        store.putSync(KEY_LAST_SELECTED_KEY, selectedKey)
        store.flushSync()
      }
      return normalized
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read home tab settings')
    }
  }

  static async save(context: common.UIAbilityContext, keysJson: string): Promise<string> {
    try {
      const normalized = JSON.stringify(FeedTabSettings.normalizeKeys(FeedTabSettings.parseKeys(keysJson)))
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_VISIBLE_KEYS, normalized)
      const selectedKey = FeedTabSettings.selectedKeyOrFallback(
        normalized,
        AppStorage.get<string>(StorageKeys.FEED_TAB) || '')
      store.putSync(KEY_LAST_SELECTED_KEY, selectedKey)
      store.flushSync()
      FeedTabSettings.apply(normalized)
      FeedTabSettings.applySelectedKey(selectedKey)
      return normalized
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save home tab settings')
    }
  }

  static async saveSelectedKey(context: common.UIAbilityContext, key: string): Promise<string> {
    try {
      const keysJson = AppStorage.get<string>(StorageKeys.FEED_TAB_KEYS) || FeedTabSettings.defaultKeysJson()
      const selectedKey = FeedTabSettings.selectedKeyOrFallback(keysJson, key)
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_LAST_SELECTED_KEY, selectedKey)
      store.flushSync()
      FeedTabSettings.applySelectedKey(selectedKey)
      return selectedKey
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save selected home tab')
    }
  }

  static apply(keysJson: string): void {
    // Dual-writes the AppStorage key (still read imperatively by FeedTabSettings.ets bootstrap reads)
    // AND the V2 FeedTabState mirror, so bootstrap restore and settings reorder both seed/update the mirror.
    FeedTabBridge.publishKeys(keysJson || FeedTabSettings.defaultKeysJson())
  }

  static applySelectedKey(key: string): void {
    FeedTabBridge.publishSelectedKey(key || FeedTabSettings.defaultKeys()[0])
  }

  private static selectedKeyOrFallback(keysJson: string, key: string): string {
    const tabs = FeedTabSettings.tabsFromKeysJson(keysJson)
    if (tabs.find((tab: TabItem) => tab.key === key)) {
      return key
    }
    return tabs.length > 0 ? tabs[0].key : FeedTabSettings.defaultKeys()[0]
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
      const validKey = valid.indexOf(key) >= 0 || FeedTabSettings.isNodeKey(key)
      if (!validKey || result.indexOf(key) >= 0) {
        continue
      }
      result.push(key)
    }
    if (result.length === 0) {
      return FeedTabSettings.defaultKeys()
    }
    return result
  }

  private static nodeKey(nodeName: string): string {
    return `${NODE_KEY_PREFIX}${nodeName}`
  }
}
