import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_AUTO_HIDE: string = StorageKeys.TOPIC_DETAIL_REPLY_BUTTON_AUTO_HIDE

export interface TopicDetailReplyActionSettingsSnapshot {
  autoHide: boolean
}

export class TopicDetailReplyActionSettings {
  static readonly DEFAULT_AUTO_HIDE: boolean = true

  static apply(autoHide: boolean): void {
    setAppStorageValue<boolean>(StorageKeys.TOPIC_DETAIL_REPLY_BUTTON_AUTO_HIDE, autoHide)
  }

  static isAutoHideEnabled(): boolean {
    return AppStorage.get<boolean>(StorageKeys.TOPIC_DETAIL_REPLY_BUTTON_AUTO_HIDE) ??
      TopicDetailReplyActionSettings.DEFAULT_AUTO_HIDE
  }

  static async load(context: common.UIAbilityContext): Promise<TopicDetailReplyActionSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return TopicDetailReplyActionSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read topic detail reply action settings')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<TopicDetailReplyActionSettingsSnapshot> {
    const autoHide = store.getSync(
      KEY_AUTO_HIDE,
      TopicDetailReplyActionSettings.DEFAULT_AUTO_HIDE,
    ) as boolean
    TopicDetailReplyActionSettings.apply(autoHide)
    return { autoHide: autoHide }
  }

  static async save(context: common.UIAbilityContext, autoHide: boolean): Promise<void> {
    TopicDetailReplyActionSettings.apply(autoHide)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_AUTO_HIDE, autoHide)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save topic detail reply action settings')
    }
  }
}
