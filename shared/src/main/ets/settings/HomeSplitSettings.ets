import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_SPLIT_RATIO: string = StorageKeys.HOME_SPLIT_RATIO

/**
 * Remembers the user's dragged feed-pane width as a RATIO of the window width, so the split comes
 * back at the same proportion on the next launch and after rotation (a stored vp width would mean
 * something different once the large-screen window changes shape).
 */
export class HomeSplitSettings {
  // 0 = nothing stored yet; the split layout seeds its own default and only persists after a drag.
  static readonly UNSET_RATIO: number = 0
  static readonly MIN_RATIO: number = 0.2
  static readonly MAX_RATIO: number = 0.6

  static ratio(): number {
    const stored: number | undefined = AppStorage.get<number>(KEY_SPLIT_RATIO)
    if (stored === undefined) {
      return HomeSplitSettings.UNSET_RATIO
    }
    return HomeSplitSettings.normalizeRatio(stored)
  }

  static normalizeRatio(ratio: number): number {
    if (!Number.isFinite(ratio) || ratio <= 0) {
      return HomeSplitSettings.UNSET_RATIO
    }
    return Math.max(HomeSplitSettings.MIN_RATIO, Math.min(HomeSplitSettings.MAX_RATIO, ratio))
  }

  static apply(ratio: number): number {
    const normalized = HomeSplitSettings.normalizeRatio(ratio)
    setAppStorageValue<number>(KEY_SPLIT_RATIO, normalized)
    return normalized
  }

  static async load(context: common.UIAbilityContext): Promise<number> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return HomeSplitSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read home split settings')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<number> {
    const raw = store.getSync(KEY_SPLIT_RATIO, HomeSplitSettings.UNSET_RATIO) as number
    return HomeSplitSettings.apply(raw)
  }

  static async save(context: common.UIAbilityContext, ratio: number): Promise<void> {
    const normalized = HomeSplitSettings.apply(ratio)
    const store = await preferences.getPreferences(context, STORE_NAME)
    store.putSync(KEY_SPLIT_RATIO, normalized)
    store.flushSync()
  }
}
