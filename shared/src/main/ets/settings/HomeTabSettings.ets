import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_AUTO_HIDE: string = StorageKeys.HOME_TAB_AUTO_HIDE

export interface HomeTabSettingsSnapshot {
  autoHide: boolean
}

export class HomeTabSettings {
  static readonly DEFAULT_AUTO_HIDE: boolean = true

  static apply(autoHide: boolean): void {
    setAppStorageValue<boolean>(StorageKeys.HOME_TAB_AUTO_HIDE, autoHide)
  }

  static isAutoHideEnabled(): boolean {
    return AppStorage.get<boolean>(StorageKeys.HOME_TAB_AUTO_HIDE) ?? HomeTabSettings.DEFAULT_AUTO_HIDE
  }

  static async load(context: common.UIAbilityContext): Promise<HomeTabSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return HomeTabSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read home tab settings')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<HomeTabSettingsSnapshot> {
    const autoHide = store.getSync(KEY_AUTO_HIDE, HomeTabSettings.DEFAULT_AUTO_HIDE) as boolean
    HomeTabSettings.apply(autoHide)
    return { autoHide: autoHide }
  }

  static async save(context: common.UIAbilityContext, autoHide: boolean): Promise<void> {
    HomeTabSettings.apply(autoHide)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_AUTO_HIDE, autoHide)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save home tab settings')
    }
  }
}
