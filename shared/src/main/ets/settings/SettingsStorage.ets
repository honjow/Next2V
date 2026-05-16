import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

export { STORE_NAME_SETTINGS } from './SettingsStores'
export type SettingsPreferencesStore = preferences.Preferences

export async function withPreferencesStore<T>(
  context: common.UIAbilityContext,
  storeName: string,
  action: (store: SettingsPreferencesStore) => T
): Promise<T> {
  const store = await preferences.getPreferences(context, storeName)
  return action(store)
}

export function readJsonArray<T>(store: SettingsPreferencesStore, key: string, fallback: T[]): T[] {
  try {
    const raw = store.getSync(key, JSON.stringify(fallback)) as string
    if (!raw) {
      return fallback.slice()
    }
    const parsed = JSON.parse(raw) as T[]
    if (!Array.isArray(parsed)) {
      return fallback.slice()
    }
    return parsed
  } catch (_error) {
    return fallback.slice()
  }
}

export function readJsonObject<T>(store: SettingsPreferencesStore, key: string, fallback: T | null): T | null {
  try {
    const raw = store.getSync(key, fallback === null ? '' : JSON.stringify(fallback)) as string
    if (!raw) {
      return fallback
    }
    const parsed = JSON.parse(raw) as T
    return parsed ? parsed : fallback
  } catch (_error) {
    return fallback
  }
}

export function writeJsonValue<T>(store: SettingsPreferencesStore, key: string, value: T, flush: boolean = true): void {
  store.putSync(key, JSON.stringify(value))
  if (flush) {
    store.flushSync()
  }
}

export function deleteKeysAndFlush(store: SettingsPreferencesStore, keys: string[]): void {
  for (const key of keys) {
    store.deleteSync(key)
  }
  store.flushSync()
}

export function setAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value)
  }
}
