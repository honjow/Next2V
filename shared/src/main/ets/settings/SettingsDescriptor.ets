import { preferences } from '@kit.ArkData'
import { SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

export interface SettingDescriptor<T> {
  readonly storageKey: string
  readonly preferenceKey: string
  readonly defaultValue: T
  normalize(value: T): T
}

export function readDescriptorValue<T>(store: SettingsPreferencesStore, descriptor: SettingDescriptor<T>): T {
  return descriptor.normalize(store.getSync(descriptor.preferenceKey, descriptor.defaultValue as preferences.ValueType) as T)
}

export function applyDescriptorValue<T>(descriptor: SettingDescriptor<T>, value: T): T {
  const normalized = descriptor.normalize(value)
  setAppStorageValue<T>(descriptor.storageKey, normalized)
  return normalized
}
