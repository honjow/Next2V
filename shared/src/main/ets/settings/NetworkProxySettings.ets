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

  static defaultSnapshot(): NetworkProxySettingsSnapshot {
    return { mode: 'off', host: '', port: 0, username: '', password: '', exclusionList: [] }
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
      username: (snapshot.username || '').trim(),
      password: snapshot.password || '',
      exclusionList: NetworkProxySettings.normalizeExclusionList(snapshot.exclusionList || []),
    }
  }

  static normalizeMode(mode: string): NetworkProxyMode {
    if (mode === 'system' || mode === 'http' || mode === 'socks5') {
      return mode
    }
    return 'off'
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
