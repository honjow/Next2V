import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { connectHotReplySettings } from '../state/HotReplySettingsState'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_ENABLED: string = StorageKeys.HOT_REPLIES_ENABLED
const KEY_MAX_COUNT: string = StorageKeys.HOT_REPLIES_MAX_COUNT
const KEY_MIN_THANKS: string = StorageKeys.HOT_REPLIES_MIN_THANKS
const KEY_CHILD_REPLIES_EXPANDED: string = StorageKeys.HOT_REPLIES_CHILD_REPLIES_EXPANDED

export interface HotReplySettingsSnapshot {
  enabled: boolean
  maxCount: number
  minThanks: number
  childRepliesExpanded: boolean
}

export class HotReplySettings {
  static readonly DEFAULT_ENABLED: boolean = true
  static readonly DEFAULT_MAX_COUNT: number = 5
  static readonly DEFAULT_MIN_THANKS: number = 3
  static readonly DEFAULT_CHILD_REPLIES_EXPANDED: boolean = false
  static readonly MIN_MAX_COUNT: number = 1
  static readonly MAX_MAX_COUNT: number = 10
  static readonly MIN_THANKS: number = 1
  static readonly MAX_THANKS: number = 99

  static apply(
    enabled: boolean,
    maxCount: number,
    minThanks: number,
    childRepliesExpanded: boolean,
  ): HotReplySettingsSnapshot {
    const normalized = HotReplySettings.normalizeSnapshot({
      enabled: enabled,
      maxCount: maxCount,
      minThanks: minThanks,
      childRepliesExpanded: childRepliesExpanded,
    })
    setAppStorageValue<boolean>(KEY_ENABLED, normalized.enabled)
    setAppStorageValue<number>(KEY_MAX_COUNT, normalized.maxCount)
    setAppStorageValue<number>(KEY_MIN_THANKS, normalized.minThanks)
    setAppStorageValue<boolean>(KEY_CHILD_REPLIES_EXPANDED, normalized.childRepliesExpanded)
    const state = connectHotReplySettings()
    state.enabled = normalized.enabled
    state.maxCount = normalized.maxCount
    state.minThanks = normalized.minThanks
    state.childRepliesExpanded = normalized.childRepliesExpanded
    return normalized
  }

  static async load(context: common.UIAbilityContext): Promise<HotReplySettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return HotReplySettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read hot reply settings')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<HotReplySettingsSnapshot> {
    const enabled = store.getSync(KEY_ENABLED, HotReplySettings.DEFAULT_ENABLED) as boolean
    const maxCount = store.getSync(KEY_MAX_COUNT, HotReplySettings.DEFAULT_MAX_COUNT) as number
    const minThanks = store.getSync(KEY_MIN_THANKS, HotReplySettings.DEFAULT_MIN_THANKS) as number
    const childRepliesExpanded = store.getSync(
      KEY_CHILD_REPLIES_EXPANDED,
      HotReplySettings.DEFAULT_CHILD_REPLIES_EXPANDED,
    ) as boolean
    return HotReplySettings.apply(enabled, maxCount, minThanks, childRepliesExpanded)
  }

  static async save(
    context: common.UIAbilityContext,
    enabled: boolean,
    maxCount: number,
    minThanks: number,
    childRepliesExpanded: boolean,
  ): Promise<void> {
    const normalized = HotReplySettings.apply(enabled, maxCount, minThanks, childRepliesExpanded)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_ENABLED, normalized.enabled)
      store.putSync(KEY_MAX_COUNT, normalized.maxCount)
      store.putSync(KEY_MIN_THANKS, normalized.minThanks)
      store.putSync(KEY_CHILD_REPLIES_EXPANDED, normalized.childRepliesExpanded)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save hot reply settings')
    }
  }

  static normalizeSnapshot(snapshot: HotReplySettingsSnapshot): HotReplySettingsSnapshot {
    return {
      enabled: snapshot.enabled === true,
      maxCount: HotReplySettings.normalizeMaxCount(snapshot.maxCount),
      minThanks: HotReplySettings.normalizeMinThanks(snapshot.minThanks),
      childRepliesExpanded: snapshot.childRepliesExpanded === true,
    }
  }

  static normalizeMaxCount(value: number): number {
    if (Number.isNaN(value)) {
      return HotReplySettings.DEFAULT_MAX_COUNT
    }
    const rounded = Math.floor(value)
    if (rounded < HotReplySettings.MIN_MAX_COUNT) {
      return HotReplySettings.MIN_MAX_COUNT
    }
    if (rounded > HotReplySettings.MAX_MAX_COUNT) {
      return HotReplySettings.MAX_MAX_COUNT
    }
    return rounded
  }

  static normalizeMinThanks(value: number): number {
    if (Number.isNaN(value)) {
      return HotReplySettings.DEFAULT_MIN_THANKS
    }
    const rounded = Math.floor(value)
    if (rounded < HotReplySettings.MIN_THANKS) {
      return HotReplySettings.MIN_THANKS
    }
    if (rounded > HotReplySettings.MAX_THANKS) {
      return HotReplySettings.MAX_THANKS
    }
    return rounded
  }
}
