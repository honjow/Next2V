import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ApiConstants } from '../constants/ApiConstants'
import { StorageKeys } from '../constants/StorageKeys'
import { HttpClient } from '../network/HttpClient'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_SELECTED_BASE_URL: string = StorageKeys.SELECTED_BASE_URL
const KEY_USE_CO_DOMAIN: string = StorageKeys.USE_CO_DOMAIN

export interface ApiDomainSnapshot {
  baseUrl: string
  migratedFromCoDomain: boolean
}

export interface DomainValidationResult {
  ok: boolean
  baseUrl: string
  message: string
}

// Legacy ApiDomainSettings naming is kept to avoid cross-module churn; it now
// represents the selected V2EX base URL shared by API calls, HTML pages, cookie
// ownership, and proxy validation rather than an API-only endpoint.
export class ApiDomainSettings {
  private static migratedFromLegacyCoDomain: boolean = false

  static didMigrateFromLegacyCoDomain(): boolean {
    return ApiDomainSettings.migratedFromLegacyCoDomain
  }

  static normalizeBaseUrl(value: string): string {
    const raw = (value || '').trim()
    if (!raw) {
      return ApiConstants.BASE_URL_COM
    }
    const withoutTrailingSlash = raw.endsWith('/') ? raw.slice(0, raw.length - 1) : raw
    const lower = withoutTrailingSlash.toLowerCase()
    const preset = ApiConstants.PRESET_DOMAINS.find(option => option.baseUrl.toLowerCase() === lower)
    if (preset) {
      return preset.baseUrl
    }
    if (lower === ApiConstants.BASE_URL_CO) {
      return ApiConstants.BASE_URL_COM
    }
    return withoutTrailingSlash
  }

  static apply(baseUrl: string): void {
    const normalized = ApiDomainSettings.normalizeBaseUrl(baseUrl)
    HttpClient.getInstance().setBaseUrl(normalized)
    setAppStorageValue<string>(StorageKeys.SELECTED_BASE_URL, normalized)
    setAppStorageValue<boolean>(StorageKeys.USE_CO_DOMAIN, false)
  }

  static async load(context: common.UIAbilityContext): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return ApiDomainSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read V2EX site settings')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<string> {
    const selected = store.getSync(KEY_SELECTED_BASE_URL, '') as string
    if (selected) {
      const normalized = ApiDomainSettings.normalizeBaseUrl(selected)
      ApiDomainSettings.apply(normalized)
      return normalized
    }
    const migrated = ApiDomainSettings.migrateFromUseCoDomain(store)
    ApiDomainSettings.apply(migrated.baseUrl)
    return migrated.baseUrl
  }

  static migrateFromUseCoDomain(store: SettingsPreferencesStore): ApiDomainSnapshot {
    const useCoDomain = store.getSync(KEY_USE_CO_DOMAIN, false) as boolean
    const baseUrl = useCoDomain ? ApiConstants.BASE_URL_COM : ApiConstants.BASE_URL_COM
    ApiDomainSettings.migratedFromLegacyCoDomain = useCoDomain
    // v2ex.co has been DNS-dead since at least 2026-05-26. Users migrating from
    // the boolean useCoDomain=true are redirected to www.v2ex.com; the old key is
    // deleted after the new baseUrl is persisted so future startup is idempotent.
    store.putSync(KEY_SELECTED_BASE_URL, baseUrl)
    store.deleteSync(KEY_USE_CO_DOMAIN)
    store.flushSync()
    return { baseUrl, migratedFromCoDomain: useCoDomain }
  }

  static async save(context: common.UIAbilityContext, baseUrl: string): Promise<void> {
    const normalized = ApiDomainSettings.normalizeBaseUrl(baseUrl)
    ApiDomainSettings.apply(normalized)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_SELECTED_BASE_URL, normalized)
      store.deleteSync(KEY_USE_CO_DOMAIN)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save V2EX site settings')
    }
  }
}
