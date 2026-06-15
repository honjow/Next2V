import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ApiConstants, type ApiDomainOption } from '../constants/ApiConstants'
import { StorageKeys } from '../constants/StorageKeys'
import { HttpClient } from '../network/HttpClient'
import {
  readJsonArray,
  STORE_NAME_SETTINGS,
  SettingsPreferencesStore,
  setAppStorageValue
} from './SettingsStorage'
import { connectApiDomain } from '../state/ApiDomainState'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_SELECTED_BASE_URL: string = StorageKeys.SELECTED_BASE_URL
const KEY_CUSTOM_BASE_URLS: string = StorageKeys.CUSTOM_BASE_URLS
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

  static isPresetBaseUrl(baseUrl: string): boolean {
    const normalized = ApiDomainSettings.normalizeBaseUrl(baseUrl).toLowerCase()
    return ApiConstants.PRESET_DOMAINS.some((option: ApiDomainOption) => option.baseUrl.toLowerCase() === normalized)
  }

  static apply(baseUrl: string): void {
    const normalized = ApiDomainSettings.normalizeBaseUrl(baseUrl)
    HttpClient.getInstance().setBaseUrl(normalized)
    setAppStorageValue<string>(StorageKeys.SELECTED_BASE_URL, normalized)
    // V2 mirror dual-write for @ComponentV2 readers (DomainSettingsPage).
    connectApiDomain().selectedBaseUrl = normalized
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
      ApiDomainSettings.persistCustomBaseUrlInStore(store, normalized)
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
      ApiDomainSettings.persistCustomBaseUrlInStore(store, normalized, false)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save V2EX site settings')
    }
  }

  static async loadCustomBaseUrls(context: common.UIAbilityContext): Promise<string[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const selected = store.getSync(KEY_SELECTED_BASE_URL, '') as string
      return ApiDomainSettings.customBaseUrlsFromStore(store, selected)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read custom V2EX site settings')
    }
  }

  static async saveCustomBaseUrl(context: common.UIAbilityContext, baseUrl: string): Promise<string[]> {
    const normalized = ApiDomainSettings.normalizeBaseUrl(baseUrl)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const urls = ApiDomainSettings.persistCustomBaseUrlInStore(store, normalized, false)
      store.flushSync()
      return urls
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save custom V2EX site settings')
    }
  }

  static customBaseUrlsFromStore(store: SettingsPreferencesStore, selectedBaseUrl: string = ''): string[] {
    const urls = ApiDomainSettings.normalizeCustomBaseUrls(readJsonArray<string>(store, KEY_CUSTOM_BASE_URLS, []))
    const selected = ApiDomainSettings.normalizeBaseUrl(selectedBaseUrl)
    if (selected && !ApiDomainSettings.isPresetBaseUrl(selected)) {
      return ApiDomainSettings.ensureCustomBaseUrl(urls, selected)
    }
    return urls
  }

  private static persistCustomBaseUrlInStore(
    store: SettingsPreferencesStore,
    baseUrl: string,
    flush: boolean = true
  ): string[] {
    const normalized = ApiDomainSettings.normalizeBaseUrl(baseUrl)
    const urls = ApiDomainSettings.customBaseUrlsFromStore(store)
    if (ApiDomainSettings.isPresetBaseUrl(normalized)) {
      return urls
    }
    const next = ApiDomainSettings.ensureCustomBaseUrl(urls, normalized)
    store.putSync(KEY_CUSTOM_BASE_URLS, JSON.stringify(next))
    if (flush) {
      store.flushSync()
    }
    return next
  }

  private static ensureCustomBaseUrl(source: string[], baseUrl: string): string[] {
    const normalized = ApiDomainSettings.normalizeBaseUrl(baseUrl)
    const result = ApiDomainSettings.normalizeCustomBaseUrls(source)
    if (!normalized || ApiDomainSettings.isPresetBaseUrl(normalized)) {
      return result
    }
    if (!result.includes(normalized)) {
      result.push(normalized)
    }
    return result
  }

  private static normalizeCustomBaseUrls(source: string[]): string[] {
    const result: string[] = []
    for (const item of source) {
      const normalized = ApiDomainSettings.normalizeBaseUrl(item)
      if (!normalized || ApiDomainSettings.isPresetBaseUrl(normalized) || result.includes(normalized)) {
        continue
      }
      result.push(normalized)
    }
    return result
  }
}
