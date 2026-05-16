import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { webview } from '@kit.ArkWeb'
import { ApiConstants } from '../constants/ApiConstants'
import { StorageKeys } from '../constants/StorageKeys'
import { HttpClient } from '../network/HttpClient'
import { setAppStorageValue } from './SettingsStorage'
import { STORE_NAME_COOKIEJAR } from './SettingsStores'

const STORE_NAME: string = STORE_NAME_COOKIEJAR
const KEY_COOKIE_COM: string = 'cookieCom'
const KEY_COOKIE_CO: string = 'cookieCo'
const KEY_UPDATED_AT: string = 'updatedAt'

export interface CookieJarSnapshot {
  comCookie: string
  coCookie: string
  updatedAt: number
}

interface CookiePair {
  name: string
  value: string
}

export class CookieJarSettings {
  private static comCookie: string = ''
  private static coCookie: string = ''
  private static updatedAt: number = 0

  static getCookieForBaseUrl(baseUrl: string): string {
    return (baseUrl === ApiConstants.BASE_URL_CO ? CookieJarSettings.coCookie : CookieJarSettings.comCookie).trim()
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
      const comCookie = store.getSync(KEY_COOKIE_COM, '') as string
      const coCookie = store.getSync(KEY_COOKIE_CO, '') as string
      const updatedAt = store.getSync(KEY_UPDATED_AT, 0) as number
      CookieJarSettings.apply({ comCookie, coCookie, updatedAt })
      CookieJarSettings.restoreToWebCookieManager().catch((error: Error) => {
        console.error('restore web cookies failed: ' + error.message)
      })
      return { comCookie, coCookie, updatedAt }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取 Cookie 设置失败')
    }
  }

  static async saveForBaseUrl(context: common.UIAbilityContext, baseUrl: string, cookie: string): Promise<void> {
    const cleanCookie = cookie.trim()
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      if (baseUrl === ApiConstants.BASE_URL_CO) {
        store.putSync(KEY_COOKIE_CO, cleanCookie)
        CookieJarSettings.coCookie = cleanCookie
      } else {
        store.putSync(KEY_COOKIE_COM, cleanCookie)
        CookieJarSettings.comCookie = cleanCookie
      }
      CookieJarSettings.updatedAt = Date.now()
      store.putSync(KEY_UPDATED_AT, CookieJarSettings.updatedAt)
      store.flushSync()
      CookieJarSettings.apply({
        comCookie: CookieJarSettings.comCookie,
        coCookie: CookieJarSettings.coCookie,
        updatedAt: CookieJarSettings.updatedAt
      })
      await CookieJarSettings.restoreToWebCookieManager()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存 Cookie 设置失败')
    }
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_COOKIE_COM)
      store.deleteSync(KEY_COOKIE_CO)
      store.deleteSync(KEY_UPDATED_AT)
      store.flushSync()
      CookieJarSettings.apply({ comCookie: '', coCookie: '', updatedAt: 0 })
      try {
        await webview.WebCookieManager.clearAllCookies()
      } catch (error) {
        const e = error as Error
        console.error('clear web cookies failed: ' + (e.message || 'unknown'))
      }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '清除 Cookie 设置失败')
    }
  }

  static apply(snapshot: CookieJarSnapshot): void {
    CookieJarSettings.comCookie = snapshot.comCookie || ''
    CookieJarSettings.coCookie = snapshot.coCookie || ''
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
      const pair: CookiePair = { name, value }
      res.push(pair)
    }
    return res
  }
}
