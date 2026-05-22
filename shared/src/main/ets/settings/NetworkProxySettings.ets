import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connection } from '@kit.NetworkKit'
import { StorageKeys } from '../constants/StorageKeys'
import { AppStrings } from '../i18n/AppStrings'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, readJsonArray, readJsonObject, setAppStorageValue, writeJsonValue } from './SettingsStorage'

export type NetworkProxyMode = 'off' | 'system' | 'http' | 'socks5'
export type NetworkProxyScheme = 'http' | 'https'

export interface NetworkProxySettingsSnapshot {
  mode: NetworkProxyMode
  host: string
  port: number
  proxyScheme?: NetworkProxyScheme
  username: string
  password: string
  exclusionList: string[]
}

export interface NetworkProxyValidationResult {
  ok: boolean
  message: string
}

export interface NetworkProxyProfile {
  id: string
  name: string
  snapshot: NetworkProxySettingsSnapshot
  updatedAt: number
}

export interface NetworkProxyProfilesState {
  profiles: NetworkProxyProfile[]
  activeProfileId: string
}

const KEY_NETWORK_PROXY: string = 'networkProxySettings'
const KEY_NETWORK_PROXY_PROFILES: string = 'networkProxyProfiles'
const KEY_NETWORK_PROXY_ACTIVE_PROFILE_ID: string = 'networkProxyActiveProfileId'

export class NetworkProxySettings {
  static readonly MODE_OFF: NetworkProxyMode = 'off'
  static readonly MODE_SYSTEM: NetworkProxyMode = 'system'
  static readonly MODE_HTTP: NetworkProxyMode = 'http'
  static readonly MODE_SOCKS5: NetworkProxyMode = 'socks5'
  static readonly MODE_HTTP_PROXY: NetworkProxyScheme = 'http'
  static readonly MODE_HTTPS_PROXY: NetworkProxyScheme = 'https'

  static defaultSnapshot(): NetworkProxySettingsSnapshot {
    return { mode: 'off', host: '', port: 0, proxyScheme: 'http', username: '', password: '', exclusionList: [] }
  }

  static apply(snapshot: NetworkProxySettingsSnapshot): void {
    const normalized = NetworkProxySettings.normalize(snapshot)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_MODE, normalized.mode)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_HOST, normalized.host)
    setAppStorageValue<number>(StorageKeys.NETWORK_PROXY_PORT, normalized.port)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_SCHEME, normalized.proxyScheme || 'http')
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_USERNAME, normalized.username)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_PASSWORD, normalized.password)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_EXCLUSION_LIST, normalized.exclusionList.join('\n'))
  }

  static async load(context: common.UIAbilityContext): Promise<NetworkProxySettingsSnapshot> {
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    return NetworkProxySettings.loadFromStore(store)
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<NetworkProxySettingsSnapshot> {
    const snapshot = NetworkProxySettings.normalize(readJsonObject<NetworkProxySettingsSnapshot>(store, KEY_NETWORK_PROXY, NetworkProxySettings.defaultSnapshot()) || NetworkProxySettings.defaultSnapshot())
    NetworkProxySettings.apply(snapshot)
    return snapshot
  }

  static async save(context: common.UIAbilityContext, snapshot: NetworkProxySettingsSnapshot): Promise<NetworkProxySettingsSnapshot> {
    const normalized = NetworkProxySettings.normalize(snapshot)
    const validation = NetworkProxySettings.validate(normalized)
    if (!validation.ok) {
      throw new Error(validation.message)
    }
    NetworkProxySettings.apply(normalized)
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    writeJsonValue<NetworkProxySettingsSnapshot>(store, KEY_NETWORK_PROXY, normalized)
    return normalized
  }

  static current(): NetworkProxySettingsSnapshot {
    return NetworkProxySettings.normalize({
      mode: (AppStorage.get<string>(StorageKeys.NETWORK_PROXY_MODE) || 'off') as NetworkProxyMode,
      host: AppStorage.get<string>(StorageKeys.NETWORK_PROXY_HOST) || '',
      port: AppStorage.get<number>(StorageKeys.NETWORK_PROXY_PORT) || 0,
      proxyScheme: NetworkProxySettings.normalizeProxyScheme(AppStorage.get<string>(StorageKeys.NETWORK_PROXY_SCHEME) || 'http'),
      username: AppStorage.get<string>(StorageKeys.NETWORK_PROXY_USERNAME) || '',
      password: AppStorage.get<string>(StorageKeys.NETWORK_PROXY_PASSWORD) || '',
      exclusionList: NetworkProxySettings.parseExclusionList(AppStorage.get<string>(StorageKeys.NETWORK_PROXY_EXCLUSION_LIST) || ''),
    })
  }

  static normalize(snapshot: NetworkProxySettingsSnapshot): NetworkProxySettingsSnapshot {
    const mode = NetworkProxySettings.normalizeMode(snapshot.mode)
    return {
      mode,
      host: (snapshot.host || '').trim(),
      port: NetworkProxySettings.normalizePort(snapshot.port),
      proxyScheme: mode === 'http' ? NetworkProxySettings.normalizeProxyScheme(snapshot.proxyScheme || 'http') : 'http',
      username: mode === 'http' || mode === 'socks5' ? (snapshot.username || '').trim() : '',
      password: mode === 'http' || mode === 'socks5' ? (snapshot.password || '') : '',
      exclusionList: NetworkProxySettings.normalizeExclusionList(snapshot.exclusionList || []),
    }
  }

  static normalizeMode(mode: string): NetworkProxyMode {
    if (mode === 'system' || mode === 'http' || mode === 'socks5') {
      return mode
    }
    return 'off'
  }

  static normalizeProxyScheme(scheme: string): NetworkProxyScheme {
    return scheme === 'https' ? 'https' : 'http'
  }

  static parseExclusionList(text: string): string[] {
    return NetworkProxySettings.normalizeExclusionList((text || '').split(/[\n,]/))
  }

  static exclusionListText(snapshot: NetworkProxySettingsSnapshot): string {
    return NetworkProxySettings.normalize(snapshot).exclusionList.join('\n')
  }

  static label(mode: NetworkProxyMode): string {
    switch (mode) {
      case 'system':
        return AppStrings.t(AppStrings.R_SYSTEM_PROXY, 'System proxy')
      case 'http':
        return AppStrings.t(AppStrings.R_HTTP_PROXY, 'HTTP proxy')
      case 'socks5':
        return AppStrings.t(AppStrings.R_SOCKS5_PROXY, 'SOCKS5 proxy')
      case 'off':
      default:
        return AppStrings.t(AppStrings.R_COMMON_CLOSED, 'Off')
    }
  }

  static summary(snapshot: NetworkProxySettingsSnapshot): string {
    const normalized = NetworkProxySettings.normalize(snapshot)
    if (normalized.mode === 'http' || normalized.mode === 'socks5') {
      if (normalized.host && normalized.port > 0) {
        const scheme = normalized.mode === 'http' && normalized.proxyScheme === 'https' ? AppStrings.t(AppStrings.R_HTTPS_PROXY_ENTRY, 'HTTPS proxy endpoint') : NetworkProxySettings.label(normalized.mode)
        return `${scheme} · ${normalized.host}:${normalized.port}`
      }
      return `${NetworkProxySettings.label(normalized.mode)} · ${AppStrings.t(AppStrings.R_PROXY_NOT_CONFIGURED, 'Not configured')}`
    }
    return NetworkProxySettings.label(normalized.mode)
  }

  static validate(snapshot: NetworkProxySettingsSnapshot): NetworkProxyValidationResult {
    const normalized = NetworkProxySettings.normalize(snapshot)
    if (normalized.mode === 'off' || normalized.mode === 'system') {
      return { ok: true, message: '' }
    }
    if (!NetworkProxySettings.isValidHost(normalized.host)) {
      return { ok: false, message: AppStrings.t(AppStrings.R_INVALID_PROXY_HOST, 'Enter a valid proxy host') }
    }
    if (!NetworkProxySettings.isValidPort(normalized.port)) {
      return { ok: false, message: AppStrings.t(AppStrings.R_INVALID_PROXY_PORT, 'Port must be 1-65535') }
    }
    return { ok: true, message: '' }
  }

  static canUseSocks5(snapshot: NetworkProxySettingsSnapshot): boolean {
    const normalized = NetworkProxySettings.normalize(snapshot)
    return normalized.mode === 'socks5' && NetworkProxySettings.validate(normalized).ok
  }

  static buildHttpProxy(snapshot: NetworkProxySettingsSnapshot): connection.HttpProxy | undefined {
    const normalized = NetworkProxySettings.normalize(snapshot)
    if (normalized.mode !== 'http' || normalized.proxyScheme !== 'http' || !NetworkProxySettings.validate(normalized).ok) {
      return undefined
    }
    const proxy: connection.HttpProxy = {
      host: normalized.host,
      port: normalized.port,
      exclusionList: normalized.exclusionList,
    }
    if (normalized.username) {
      proxy.username = normalized.username
      proxy.password = normalized.password
    }
    return proxy
  }

  static buildSocks5Url(snapshot: NetworkProxySettingsSnapshot): string {
    const normalized = NetworkProxySettings.normalize(snapshot)
    const userinfo = NetworkProxySettings.buildProxyUserInfo(normalized)
    return `socks5://${userinfo}${normalized.host}:${normalized.port}`
  }

  static buildHttpUrl(snapshot: NetworkProxySettingsSnapshot): string {
    const normalized = NetworkProxySettings.normalize(snapshot)
    const userinfo = NetworkProxySettings.buildProxyUserInfo(normalized)
    return `${normalized.proxyScheme}://${userinfo}${normalized.host}:${normalized.port}`
  }

  private static buildProxyUserInfo(snapshot: NetworkProxySettingsSnapshot): string {
    const normalized = NetworkProxySettings.normalize(snapshot)
    return normalized.username ? `${NetworkProxySettings.encodeUserInfo(normalized.username)}:${NetworkProxySettings.encodeUserInfo(normalized.password)}@` : ''
  }

  private static encodeUserInfo(value: string): string {
    return encodeURIComponent(value)
  }

  private static normalizePort(value: number): number {
    const port = Math.floor(Number(value) || 0)
    return port >= 0 && port <= 65535 ? port : 0
  }

  private static isValidPort(port: number): boolean {
    return Number.isInteger(port) && port >= 1 && port <= 65535
  }

  private static isValidHost(host: string): boolean {
    const value = (host || '').trim()
    if (!value || value.length > 253 || value.indexOf('://') >= 0 || /\s/.test(value)) {
      return false
    }
    return /^[A-Za-z0-9._:-]+$/.test(value) || value.indexOf('.') >= 0
  }

  private static normalizeExclusionList(values: string[]): string[] {
    const seen: Record<string, boolean> = {}
    const result: string[] = []
    for (const raw of values) {
      const item = (raw || '').trim()
      if (!item || seen[item]) {
        continue
      }
      seen[item] = true
      result.push(item)
    }
    return result
  }
}

export class NetworkProxyProfileSettings {
  static async load(context: common.UIAbilityContext): Promise<NetworkProxyProfilesState> {
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    return NetworkProxyProfileSettings.loadFromStore(store)
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<NetworkProxyProfilesState> {
    const profiles = NetworkProxyProfileSettings.normalizeProfiles(readJsonArray<NetworkProxyProfile>(store, KEY_NETWORK_PROXY_PROFILES, []))
    const activeProfileId = NetworkProxyProfileSettings.validActiveId(store.getSync(KEY_NETWORK_PROXY_ACTIVE_PROFILE_ID, '') as string, profiles)
    return { profiles, activeProfileId }
  }

  static async upsertProfile(context: common.UIAbilityContext, profile: NetworkProxyProfile): Promise<NetworkProxyProfilesState> {
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    const state = await NetworkProxyProfileSettings.loadFromStore(store)
    const normalized = NetworkProxyProfileSettings.normalizeProfile(profile)
    const nextProfiles: NetworkProxyProfile[] = []
    let replaced = false
    for (const item of state.profiles) {
      if (item.id === normalized.id) {
        nextProfiles.push(normalized)
        replaced = true
      } else {
        nextProfiles.push(item)
      }
    }
    if (!replaced) {
      nextProfiles.push(normalized)
    }
    const activeProfileId = state.activeProfileId || normalized.id
    NetworkProxyProfileSettings.writeState(store, nextProfiles, activeProfileId)
    return { profiles: nextProfiles, activeProfileId }
  }

  static async setActiveProfile(context: common.UIAbilityContext, profileId: string): Promise<NetworkProxyProfilesState> {
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    const state = await NetworkProxyProfileSettings.loadFromStore(store)
    const profile = NetworkProxyProfileSettings.findProfile(state.profiles, profileId)
    if (!profile) {
      throw new Error('配置不存在')
    }
    await NetworkProxySettings.save(context, profile.snapshot)
    NetworkProxyProfileSettings.writeState(store, state.profiles, profile.id)
    return { profiles: state.profiles, activeProfileId: profile.id }
  }

  static async deleteProfile(context: common.UIAbilityContext, profileId: string): Promise<NetworkProxyProfilesState> {
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    const state = await NetworkProxyProfileSettings.loadFromStore(store)
    const nextProfiles = state.profiles.filter((profile: NetworkProxyProfile) => profile.id !== profileId)
    let activeProfileId = state.activeProfileId
    if (activeProfileId === profileId) {
      activeProfileId = nextProfiles.length > 0 ? nextProfiles[0].id : ''
      if (activeProfileId) {
        const nextActive = NetworkProxyProfileSettings.findProfile(nextProfiles, activeProfileId)
        if (nextActive) {
          await NetworkProxySettings.save(context, nextActive.snapshot)
        }
      }
    }
    NetworkProxyProfileSettings.writeState(store, nextProfiles, activeProfileId)
    return { profiles: nextProfiles, activeProfileId }
  }

  static createProfile(name: string, snapshot: NetworkProxySettingsSnapshot, id?: string): NetworkProxyProfile {
    const now = Date.now()
    return NetworkProxyProfileSettings.normalizeProfile({
      id: id || `proxy-${now}`,
      name,
      snapshot,
      updatedAt: now,
    })
  }

  private static writeState(store: SettingsPreferencesStore, profiles: NetworkProxyProfile[], activeProfileId: string): void {
    writeJsonValue<NetworkProxyProfile[]>(store, KEY_NETWORK_PROXY_PROFILES, NetworkProxyProfileSettings.normalizeProfiles(profiles), false)
    store.putSync(KEY_NETWORK_PROXY_ACTIVE_PROFILE_ID, activeProfileId)
    store.flushSync()
  }

  private static validActiveId(id: string, profiles: NetworkProxyProfile[]): string {
    if (NetworkProxyProfileSettings.findProfile(profiles, id)) {
      return id
    }
    return profiles.length > 0 ? profiles[0].id : ''
  }

  private static findProfile(profiles: NetworkProxyProfile[], id: string): NetworkProxyProfile | undefined {
    for (const profile of profiles) {
      if (profile.id === id) {
        return profile
      }
    }
    return undefined
  }

  private static normalizeProfiles(profiles: NetworkProxyProfile[]): NetworkProxyProfile[] {
    const seen: Record<string, boolean> = {}
    const result: NetworkProxyProfile[] = []
    for (const raw of profiles || []) {
      const profile = NetworkProxyProfileSettings.normalizeProfile(raw)
      if (!profile.id || seen[profile.id]) {
        continue
      }
      seen[profile.id] = true
      result.push(profile)
    }
    return result
  }

  private static normalizeProfile(profile: NetworkProxyProfile): NetworkProxyProfile {
    const id = (profile.id || `proxy-${Date.now()}`).trim()
    const name = (profile.name || '代理配置').trim() || '代理配置'
    return {
      id,
      name,
      snapshot: NetworkProxySettings.normalize(profile.snapshot || NetworkProxySettings.defaultSnapshot()),
      updatedAt: Math.max(0, Math.floor(Number(profile.updatedAt) || Date.now())),
    }
  }
}
