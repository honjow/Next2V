import { preferences } from '@kit.ArkData'

export { STORE_NAME_SETTINGS } from './SettingsStores'
export type SettingsPreferencesStore = preferences.Preferences

export function setAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value)
  }
}
