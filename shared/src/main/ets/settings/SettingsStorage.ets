export const STORE_NAME_SETTINGS: string = 'next2v_settings'

export function setAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value)
  }
}
