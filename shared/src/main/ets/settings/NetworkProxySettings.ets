import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connection } from '@kit.NetworkKit'
import { StorageKeys } from '../constants/StorageKeys'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, readJsonObject, setAppStorageValue, writeJsonValue } from './SettingsStorage'

export type NetworkProxyMode = 'off' | 'system' | 'http' | 'socks5'

export interface NetworkProxySettingsSnapshot {
  mode: NetworkProxyMode
  host: string
  port: number
  username: string
  password: string
  exclusionList: string[]
}

export interface NetworkProxyProfile {
  id: string
  type: 'http' | 'socks5'
  name?: string
  host: string
  port: number
  username?: string
  password?: string
  exclusionList?: string[]
}

export interface NetworkProxyProfilesSnapshot {
  enabled: boolean
  activeProfileId: string
  profiles: NetworkProxyProfile[]
}

export interface NetworkProxyValidationResult {
  ok: boolean
  message: string
}

const KEY_NETWORK_PROXY: string = 'networkProxySettings'

export class NetworkProxySettings {
  static readonly MODE_OFF: NetworkProxyMode = 'off'
  static readonly MODE_SYSTEM: NetworkProxyMode = 'system'
  static readonly MODE_HTTP: NetworkProxyMode = 'http'
  static readonly MODE_SOCKS5: NetworkProxyMode = 'socks5'
  static readonly SYSTEM_PROFILE_ID: string = 'system'

  static defaultSnapshot(): NetworkProxySettingsSnapshot {
    return { mode: 'off', host: '', port: 0, username: '', password: '', exclusionList: [] }
  }

  static defaultProfilesSnapshot(): NetworkProxyProfilesSnapshot {
    return { enabled: false, activeProfileId: NetworkProxySettings.SYSTEM_PROFILE_ID, profiles: [] }
  }

  static apply(snapshot: NetworkProxySettingsSnapshot): void {
    const normalized = NetworkProxySettings.normalize(snapshot)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_MODE, normalized.mode)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_HOST, normalized.host)
    setAppStorageValue<number>(StorageKeys.NETWORK_PROXY_PORT, normalized.port)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_USERNAME, normalized.username)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_PASSWORD, normalized.password)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_EXCLUSION_LIST, normalized.exclusionList.join('\n'))
  }

  static applyProfiles(snapshot: NetworkProxyProfilesSnapshot): NetworkProxyProfilesSnapshot {
    const normalized = NetworkProxySettings.normalizeProfiles(snapshot)
    setAppStorageValue<boolean>(StorageKeys.NETWORK_PROXY_ENABLED, normalized.enabled)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_ACTIVE_PROFILE_ID, normalized.activeProfileId)
    setAppStorageValue<string>(StorageKeys.NETWORK_PROXY_PROFILES, JSON.stringify(normalized.profiles))
    NetworkProxySettings.apply(NetworkProxySettings.effectiveSnapshot(normalized))
    return normalized
  }

  static async load(context: common.UIAbilityContext): Promise<NetworkProxyProfilesSnapshot> {
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    return NetworkProxySettings.loadFromStore(store)
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<NetworkProxyProfilesSnapshot> {
    const raw = readJsonObject<Object>(store, KEY_NETWORK_PROXY, null)
    const snapshot = NetworkProxySettings.normalizeProfilesFromPersisted(raw)
    NetworkProxySettings.applyProfiles(snapshot)
    return snapshot
  }

  static async save(context: common.UIAbilityContext, snapshot: NetworkProxySettingsSnapshot): Promise<NetworkProxySettingsSnapshot> {
    const normalized = NetworkProxySettings.normalize(snapshot)
    const validation = NetworkProxySettings.validate(normalized)
    if (!validation.ok) {
      throw new Error(validation.message)
    }
    const profiles = NetworkProxySettings.migrateLegacy(normalized)
    NetworkProxySettings.applyProfiles(profiles)
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    writeJsonValue<NetworkProxyProfilesSnapshot>(store, KEY_NETWORK_PROXY, profiles)
    return normalized
  }

  static async saveProfiles(context: common.UIAbilityContext, snapshot: NetworkProxyProfilesSnapshot): Promise<NetworkProxyProfilesSnapshot> {
    const normalized = NetworkProxySettings.normalizeProfiles(snapshot)
    const validation = NetworkProxySettings.validateProfiles(normalized)
    if (!validation.ok) {
      throw new Error(validation.message)
    }
    NetworkProxySettings.applyProfiles(normalized)
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    writeJsonValue<NetworkProxyProfilesSnapshot>(store, KEY_NETWORK_PROXY, normalized)
    return normalized
  }

  static current(): NetworkProxySettingsSnapshot {
    return NetworkProxySettings.normalize({
      mode: (AppStorage.get<string>(StorageKeys.NETWORK_PROXY_MODE) || 'off') as NetworkProxyMode,
      host: AppStorage.get<string>(StorageKeys.NETWORK_PROXY_HOST) || '',
      port: AppStorage.get<number>(StorageKeys.NETWORK_PROXY_PORT) || 0,
      username: AppStorage.get<string>(StorageKeys.NETWORK_PROXY_USERNAME) || '',
      password: AppStorage.get<string>(StorageKeys.NETWORK_PROXY_PASSWORD) || '',
      exclusionList: NetworkProxySettings.parseExclusionList(AppStorage.get<string>(StorageKeys.NETWORK_PROXY_EXCLUSION_LIST) || ''),
    })
  }

  static currentProfiles(): NetworkProxyProfilesSnapshot {
    const enabled = AppStorage.get<boolean>(StorageKeys.NETWORK_PROXY_ENABLED) || false
    const activeProfileId = AppStorage.get<string>(StorageKeys.NETWORK_PROXY_ACTIVE_PROFILE_ID) || NetworkProxySettings.SYSTEM_PROFILE_ID
    const profiles = NetworkProxySettings.parseProfilesJson(AppStorage.get<string>(StorageKeys.NETWORK_PROXY_PROFILES) || '[]')
    return NetworkProxySettings.normalizeProfiles({ enabled, activeProfileId, profiles })
  }

  static effectiveSnapshot(snapshot: NetworkProxyProfilesSnapshot): NetworkProxySettingsSnapshot {
    const normalized = NetworkProxySettings.normalizeProfiles(snapshot)
    if (!normalized.enabled) {
      return NetworkProxySettings.defaultSnapshot()
    }
    if (normalized.activeProfileId === NetworkProxySettings.SYSTEM_PROFILE_ID) {
      return { mode: 'system', host: '', port: 0, username: '', password: '', exclusionList: [] }
    }
    const profile = NetworkProxySettings.findProfile(normalized.profiles, normalized.activeProfileId)
    if (!profile) {
      return NetworkProxySettings.defaultSnapshot()
    }
    return NetworkProxySettings.snapshotFromProfile(profile)
  }

  static normalize(snapshot: NetworkProxySettingsSnapshot): NetworkProxySettingsSnapshot {
    const mode = NetworkProxySettings.normalizeMode(snapshot.mode)
    return {
      mode,
      host: (snapshot.host || '').trim(),
      port: NetworkProxySettings.normalizePort(snapshot.port),
      username: mode === 'http' ? (snapshot.username || '').trim() : '',
      password: mode === 'http' ? (snapshot.password || '') : '',
      exclusionList: NetworkProxySettings.normalizeExclusionList(snapshot.exclusionList || []),
    }
  }

  static normalizeProfiles(snapshot: NetworkProxyProfilesSnapshot): NetworkProxyProfilesSnapshot {
    const profiles: NetworkProxyProfile[] = []
    const seen: Record<string, boolean> = {}
    for (const raw of snapshot.profiles || []) {
      const profile = NetworkProxySettings.normalizeProfile(raw)
      if (!profile || seen[profile.id] || profile.id === NetworkProxySettings.SYSTEM_PROFILE_ID) {
        continue
      }
      seen[profile.id] = true
      profiles.push(profile)
    }
    let activeProfileId = (snapshot.activeProfileId || NetworkProxySettings.SYSTEM_PROFILE_ID).trim()
    if (activeProfileId !== NetworkProxySettings.SYSTEM_PROFILE_ID && !NetworkProxySettings.findProfile(profiles, activeProfileId)) {
      activeProfileId = NetworkProxySettings.SYSTEM_PROFILE_ID
    }
    return { enabled: !!snapshot.enabled, activeProfileId, profiles }
  }

  static normalizeProfile(raw: NetworkProxyProfile): NetworkProxyProfile | null {
    const type = raw.type === 'socks5' ? 'socks5' : 'http'
    const id = (raw.id || NetworkProxySettings.newProfileId()).trim()
    const host = (raw.host || '').trim()
    const port = NetworkProxySettings.normalizePort(raw.port)
    if (!id || !host || port <= 0) {
      return null
    }
    const result: NetworkProxyProfile = {
      id,
      type,
      host,
      port,
      exclusionList: NetworkProxySettings.normalizeExclusionList(raw.exclusionList || []),
    }
    const name = (raw.name || '').trim()
    if (name) {
      result.name = name
    }
    if (type === 'http') {
      const username = (raw.username || '').trim()
      if (username) {
        result.username = username
        result.password = raw.password || ''
      }
    }
    return result
  }

  static normalizeMode(mode: string): NetworkProxyMode {
    if (mode === 'system' || mode === 'http' || mode === 'socks5') {
      return mode
    }
    return 'off'
  }

  static parseProfilesJson(text: string): NetworkProxyProfile[] {
    try {
      const parsed = JSON.parse(text || '[]') as NetworkProxyProfile[]
      if (!Array.isArray(parsed)) {
        return []
      }
      const normalized = NetworkProxySettings.normalizeProfiles({ enabled: true, activeProfileId: NetworkProxySettings.SYSTEM_PROFILE_ID, profiles: parsed })
      return normalized.profiles
    } catch (_error) {
      return []
    }
  }

  static parseExclusionList(text: string): string[] {
    return NetworkProxySettings.normalizeExclusionList((text || '').split(/[\n,]/))
  }

  static exclusionListText(snapshot: NetworkProxySettingsSnapshot): string {
    return NetworkProxySettings.normalize(snapshot).exclusionList.join('\n')
  }

  static profileTitle(profile: NetworkProxyProfile): string {
    const normalized = NetworkProxySettings.normalizeProfile(profile)
    if (!normalized) {
      return ''
    }
    if (normalized.name) {
      return normalized.name
    }
    return `${NetworkProxySettings.label(normalized.type)} ${normalized.host}:${normalized.port}`
  }

  static profileSubtitle(profile: NetworkProxyProfile): string {
    const normalized = NetworkProxySettings.normalizeProfile(profile)
    if (!normalized) {
      return ''
    }
    const base = `${NetworkProxySettings.label(normalized.type)} · ${normalized.host}:${normalized.port}`
    if (normalized.type === 'socks5') {
      return `${base} · 不支持认证`
    }
    return base
  }

  static label(mode: NetworkProxyMode | 'http' | 'socks5'): string {
    switch (mode) {
      case 'system':
        return '系统代理'
      case 'http':
        return 'HTTP 代理'
      case 'socks5':
        return 'SOCKS5 代理'
      case 'off':
      default:
        return '关闭'
    }
  }

  static summary(snapshot: NetworkProxySettingsSnapshot): string {
    const normalized = NetworkProxySettings.normalize(snapshot)
    if (normalized.mode === 'http' || normalized.mode === 'socks5') {
      if (normalized.host && normalized.port > 0) {
        return `${NetworkProxySettings.label(normalized.mode)} · ${normalized.host}:${normalized.port}`
      }
      return `${NetworkProxySettings.label(normalized.mode)} · 未配置`
    }
    return NetworkProxySettings.label(normalized.mode)
  }

  static validate(snapshot: NetworkProxySettingsSnapshot): NetworkProxyValidationResult {
    const normalized = NetworkProxySettings.normalize(snapshot)
    if (normalized.mode === 'off' || normalized.mode === 'system') {
      return { ok: true, message: '' }
    }
    if (!NetworkProxySettings.isValidHost(normalized.host)) {
      return { ok: false, message: '请输入有效代理主机' }
    }
    if (!NetworkProxySettings.isValidPort(normalized.port)) {
      return { ok: false, message: '端口需为 1-65535' }
    }
    return { ok: true, message: '' }
  }

  static validateProfiles(snapshot: NetworkProxyProfilesSnapshot): NetworkProxyValidationResult {
    const effective = NetworkProxySettings.effectiveSnapshot(snapshot)
    return NetworkProxySettings.validate(effective)
  }

  static canUseSocks5(snapshot: NetworkProxySettingsSnapshot): boolean {
    const normalized = NetworkProxySettings.normalize(snapshot)
    return normalized.mode === 'socks5' && NetworkProxySettings.validate(normalized).ok
  }

  static buildHttpProxy(snapshot: NetworkProxySettingsSnapshot): connection.HttpProxy | undefined {
    const normalized = NetworkProxySettings.normalize(snapshot)
    if (normalized.mode !== 'http' || !NetworkProxySettings.validate(normalized).ok) {
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
    return `socks5://${normalized.host}:${normalized.port}`
  }

  static buildHttpUrl(snapshot: NetworkProxySettingsSnapshot): string {
    const normalized = NetworkProxySettings.normalize(snapshot)
    return `http://${normalized.host}:${normalized.port}`
  }

  static newProfileId(): string {
    return `proxy-${Date.now()}-${Math.floor(Math.random() * 100000)}`
  }

  static snapshotFromProfile(profile: NetworkProxyProfile): NetworkProxySettingsSnapshot {
    const normalized = NetworkProxySettings.normalizeProfile(profile)
    if (!normalized) {
      return NetworkProxySettings.defaultSnapshot()
    }
    return NetworkProxySettings.normalize({
      mode: normalized.type,
      host: normalized.host,
      port: normalized.port,
      username: normalized.type === 'http' ? (normalized.username || '') : '',
      password: normalized.type === 'http' ? (normalized.password || '') : '',
      exclusionList: normalized.exclusionList || [],
    })
  }

  static findProfile(profiles: NetworkProxyProfile[], id: string): NetworkProxyProfile | undefined {
    return profiles.find((profile: NetworkProxyProfile) => profile.id === id)
  }

  private static normalizeProfilesFromPersisted(raw: Object | null): NetworkProxyProfilesSnapshot {
    if (!raw) {
      return NetworkProxySettings.defaultProfilesSnapshot()
    }
    const candidate = raw as NetworkProxyProfilesSnapshot
    if (Array.isArray(candidate.profiles)) {
      return NetworkProxySettings.normalizeProfiles(candidate)
    }
    return NetworkProxySettings.migrateLegacy(raw as NetworkProxySettingsSnapshot)
  }

  private static migrateLegacy(raw: NetworkProxySettingsSnapshot): NetworkProxyProfilesSnapshot {
    const legacy = NetworkProxySettings.normalize(raw || NetworkProxySettings.defaultSnapshot())
    const profiles: NetworkProxyProfile[] = []
    let activeProfileId = NetworkProxySettings.SYSTEM_PROFILE_ID
    if ((legacy.mode === 'http' || legacy.mode === 'socks5') && legacy.host && legacy.port > 0) {
      const id = NetworkProxySettings.newProfileId()
      const profile: NetworkProxyProfile = {
        id,
        type: legacy.mode,
        host: legacy.host,
        port: legacy.port,
        exclusionList: legacy.exclusionList,
      }
      if (legacy.mode === 'http' && legacy.username) {
        profile.username = legacy.username
        profile.password = legacy.password
      }
      profiles.push(profile)
      activeProfileId = id
    }
    return NetworkProxySettings.normalizeProfiles({
      enabled: legacy.mode !== 'off',
      activeProfileId: legacy.mode === 'system' ? NetworkProxySettings.SYSTEM_PROFILE_ID : activeProfileId,
      profiles,
    })
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
