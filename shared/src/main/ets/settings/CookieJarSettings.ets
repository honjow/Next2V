import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { webview } from '@kit.ArkWeb'
import { ApiConstants } from '../constants/ApiConstants'
import { StorageKeys } from '../constants/StorageKeys'
import { HttpClient } from '../network/HttpClient'
import { ApiDomainSettings } from './ApiDomainSettings'
import { setAppStorageValue } from './SettingsStorage'
import { STORE_NAME_COOKIEJAR } from './SettingsStores'

const STORE_NAME: string = STORE_NAME_COOKIEJAR
const KEY_COOKIE_COM: string = 'cookieCom'
const KEY_COOKIE_CO: string = 'cookieCo'
const KEY_COOKIES_BY_BASE_URL: string = 'cookiesByBaseUrl'
const KEY_UPDATED_AT: string = 'updatedAt'

export interface CookieJarSnapshot {
  cookiesByBaseUrl: Record<string, string>
  updatedAt: number
}

interface CookiePair {
  name: string
  value: string
}

export class CookieJarSettings {
  private static cookiesByBaseUrl: Record<string, string> = {}
  private static updatedAt: number = 0

  static getCookieForBaseUrl(baseUrl: string): string {
    // Cookies are keyed by exact baseUrl string, not shared across domains.
    // While all *.v2ex.com subdomains proxy the same origin and cookies are technically
    // interchangeable, silently sharing cookies would leak credentials to a user-entered
    // custom domain that could be a phishing site. Explicit re-login per domain is the
    // safe default; a future opt-in 'copy cookie' action may be added for convenience.
    const normalized = CookieJarSettings.normalizeBaseUrl(baseUrl)
    return (CookieJarSettings.cookiesByBaseUrl[normalized] || '').trim()
  }

  static getCurrentCookie(): string {
    return CookieJarSettings.getCookieForBaseUrl(HttpClient.getInstance().getBaseUrl())
  }

  static getUpdatedAt(): number {
    return CookieJarSettings.updatedAt
  }

  static async load(context: common.UIAbilityContext): Promise<CookieJarSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const snapshot = CookieJarSettings.loadFromStore(store)
      CookieJarSettings.apply(snapshot)
      CookieJarSettings.restoreToWebCookieManager().catch((error: Error) => {
        console.error('restore web cookies failed: ' + error.message)
      })
      return snapshot
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read cookie settings')
    }
  }

  static loadFromStore(store: preferences.Preferences): CookieJarSnapshot {
    const updatedAt = store.getSync(KEY_UPDATED_AT, 0) as number
    const raw = store.getSync(KEY_COOKIES_BY_BASE_URL, '') as string
    if (raw) {
      return { cookiesByBaseUrl: CookieJarSettings.parseCookieMap(raw), updatedAt }
    }

    const migrated: Record<string, string> = {}
    const comCookie = (store.getSync(KEY_COOKIE_COM, '') as string).trim()
    const coCookie = (store.getSync(KEY_COOKIE_CO, '') as string).trim()
    if (comCookie) {
      migrated[ApiConstants.BASE_URL_COM] = comCookie
    }
    if (coCookie) {
      migrated[ApiConstants.BASE_URL_CO] = coCookie
      if (!comCookie || ApiDomainSettings.didMigrateFromLegacyCoDomain()) {
        // Legacy useCoDomain=true users are redirected from the DNS-dead v2ex.co
        // endpoint to www.v2ex.com. Copy the active old co slot to the selected
        // fallback domain so those users keep their session; this is limited to
        // the first-party legacy domain and never applies to custom hosts.
        migrated[ApiConstants.BASE_URL_COM] = coCookie
      }
    }
    if (Object.keys(migrated).length > 0) {
      store.putSync(KEY_COOKIES_BY_BASE_URL, JSON.stringify(migrated))
      store.deleteSync(KEY_COOKIE_COM)
      store.deleteSync(KEY_COOKIE_CO)
      store.flushSync()
    }
    return { cookiesByBaseUrl: migrated, updatedAt }
  }

  static async saveForBaseUrl(context: common.UIAbilityContext, baseUrl: string, cookie: string): Promise<void> {
    const cleanCookie = cookie.trim()
    const normalized = CookieJarSettings.normalizeBaseUrl(baseUrl)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      if (cleanCookie) {
        CookieJarSettings.cookiesByBaseUrl[normalized] = cleanCookie
      } else {
        CookieJarSettings.cookiesByBaseUrl = CookieJarSettings.withoutBaseUrl(CookieJarSettings.cookiesByBaseUrl, normalized)
      }
      CookieJarSettings.updatedAt = Date.now()
      store.putSync(KEY_COOKIES_BY_BASE_URL, JSON.stringify(CookieJarSettings.cookiesByBaseUrl))
      store.putSync(KEY_UPDATED_AT, CookieJarSettings.updatedAt)
      store.deleteSync(KEY_COOKIE_COM)
      store.deleteSync(KEY_COOKIE_CO)
      store.flushSync()
      CookieJarSettings.apply({
        cookiesByBaseUrl: CookieJarSettings.cookiesByBaseUrl,
        updatedAt: CookieJarSettings.updatedAt
      })
      await CookieJarSettings.restoreToWebCookieManager()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save cookie settings')
    }
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_COOKIES_BY_BASE_URL)
      store.deleteSync(KEY_COOKIE_COM)
      store.deleteSync(KEY_COOKIE_CO)
      store.deleteSync(KEY_UPDATED_AT)
      store.flushSync()
      CookieJarSettings.apply({ cookiesByBaseUrl: {}, updatedAt: 0 })
      try {
        await webview.WebCookieManager.clearAllCookies()
      } catch (error) {
        const e = error as Error
        console.error('clear web cookies failed: ' + (e.message || 'unknown'))
      }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to clear cookie settings')
    }
  }

  static async clearForBaseUrl(context: common.UIAbilityContext, baseUrl: string): Promise<void> {
    const cleanBaseUrl = CookieJarSettings.normalizeBaseUrl(baseUrl)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const previousCookie = CookieJarSettings.getCookieForBaseUrl(cleanBaseUrl)
      CookieJarSettings.cookiesByBaseUrl = CookieJarSettings.withoutBaseUrl(CookieJarSettings.cookiesByBaseUrl, cleanBaseUrl)
      CookieJarSettings.updatedAt = Object.keys(CookieJarSettings.cookiesByBaseUrl).length > 0 ? Date.now() : 0
      if (CookieJarSettings.updatedAt > 0) {
        store.putSync(KEY_UPDATED_AT, CookieJarSettings.updatedAt)
      } else {
        store.deleteSync(KEY_UPDATED_AT)
      }
      store.putSync(KEY_COOKIES_BY_BASE_URL, JSON.stringify(CookieJarSettings.cookiesByBaseUrl))
      store.flushSync()
      CookieJarSettings.apply({
        cookiesByBaseUrl: CookieJarSettings.cookiesByBaseUrl,
        updatedAt: CookieJarSettings.updatedAt
      })
      CookieJarSettings.expireWebCookiesForBaseUrl(cleanBaseUrl, previousCookie)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to clear current-domain cookie settings')
    }
  }

  static apply(snapshot: CookieJarSnapshot): void {
    CookieJarSettings.cookiesByBaseUrl = CookieJarSettings.cloneCookieMap(snapshot.cookiesByBaseUrl)
    CookieJarSettings.updatedAt = snapshot.updatedAt || 0
    CookieJarSettings.refreshConfiguredState()
  }

  static refreshConfiguredState(): void {
    const current = CookieJarSettings.getCurrentCookie()
    setAppStorageValue<boolean>(StorageKeys.AUTH_COOKIE_CONFIGURED, current.length > 0)
  }

  static async restoreCurrentToWebCookieManager(): Promise<void> {
    await CookieJarSettings.restoreToWebCookieManager()
  }

  private static normalizeBaseUrl(baseUrl: string): string {
    const raw = (baseUrl || ApiConstants.BASE_URL_COM).trim()
    return raw.endsWith('/') ? raw.slice(0, raw.length - 1) : raw
  }

  private static cloneCookieMap(source: Record<string, string>): Record<string, string> {
    const result = JSON.parse('{}') as Record<string, string>
    Object.keys(source).forEach((key: string) => {
      const normalized = CookieJarSettings.normalizeBaseUrl(key)
      const value = (source[key] || '').trim()
      if (value) {
        result[normalized] = value
      }
    })
    return result
  }

  private static withoutBaseUrl(source: Record<string, string>, baseUrl: string): Record<string, string> {
    const normalizedBaseUrl = CookieJarSettings.normalizeBaseUrl(baseUrl)
    const result = JSON.parse('{}') as Record<string, string>
    Object.keys(source).forEach((key: string) => {
      const normalized = CookieJarSettings.normalizeBaseUrl(key)
      const value = (source[key] || '').trim()
      if (value && normalized !== normalizedBaseUrl) {
        result[normalized] = value
      }
    })
    return result
  }

  private static parseCookieMap(raw: string): Record<string, string> {
    try {
      const parsed = JSON.parse(raw) as Record<string, string>
      return CookieJarSettings.cloneCookieMap(parsed)
    } catch (_error) {
      return {}
    }
  }

  private static async restoreToWebCookieManager(): Promise<void> {
    const baseUrl = HttpClient.getInstance().getBaseUrl()
    const cookieHeader = CookieJarSettings.getCookieForBaseUrl(baseUrl)
    if (!cookieHeader) {
      return
    }
    const pairs = CookieJarSettings.parseCookiePairs(cookieHeader)
    if (pairs.length === 0) {
      return
    }
    for (const pair of pairs) {
      try {
        webview.WebCookieManager.configCookieSync(baseUrl, `${pair.name}=${pair.value}; Path=/`, false, true)
      } catch (error) {
        const e = error as Error
        console.error('config cookie failed: ' + (e.message || 'unknown'))
      }
    }
    try {
      webview.WebCookieManager.saveCookieSync()
    } catch (error) {
      try {
        await webview.WebCookieManager.saveCookieAsync()
      } catch (e) {
        // Ignore web cookie save failures; cookies will still live in-memory.
      }
    }
  }

  private static parseCookiePairs(cookieHeader: string): CookiePair[] {
    const res: CookiePair[] = []
    const parts = cookieHeader.split(';').map(p => p.trim()).filter(p => p.length > 0)
    for (const part of parts) {
      const idx = part.indexOf('=')
      if (idx <= 0) {
        continue
      }
      const name = part.slice(0, idx).trim()
      const value = part.slice(idx + 1).trim()
      if (!name || !value) {
        continue
      }
      res.push({ name, value })
    }
    return res
  }

  private static expireWebCookiesForBaseUrl(baseUrl: string, cookieHeader: string): void {
    const pairs = CookieJarSettings.parseCookiePairs(cookieHeader)
    if (pairs.length === 0) {
      return
    }
    for (const pair of pairs) {
      try {
        webview.WebCookieManager.configCookieSync(
          baseUrl,
          `${pair.name}=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT`,
          false,
          true
        )
      } catch (error) {
        const e = error as Error
        console.error('expire web cookie failed: ' + (e.message || 'unknown'))
      }
    }
    try {
      webview.WebCookieManager.saveCookieSync()
    } catch (_error) {
      // Preferences has already been cleared; WebView will sync on the next explicit cookie restore.
    }
  }
}
