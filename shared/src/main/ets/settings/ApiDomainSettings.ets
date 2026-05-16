import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ApiConstants } from '../constants/ApiConstants'
import { StorageKeys } from '../constants/StorageKeys'
import { HttpClient } from '../network/HttpClient'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = STORE_NAME_SETTINGS
const KEY_USE_CO_DOMAIN: string = StorageKeys.USE_CO_DOMAIN

export class ApiDomainSettings {
  static apply(useCoDomain: boolean): void {
    HttpClient.getInstance().setBaseUrl(useCoDomain ? ApiConstants.BASE_URL_CO : ApiConstants.BASE_URL_COM)
    setAppStorageValue<boolean>(StorageKeys.USE_CO_DOMAIN, useCoDomain)
  }

  static async load(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return ApiDomainSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取 API 域名设置失败')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<boolean> {
    const useCoDomain = store.getSync(KEY_USE_CO_DOMAIN, false) as boolean
    ApiDomainSettings.apply(useCoDomain)
    return useCoDomain
  }

  static async save(context: common.UIAbilityContext, useCoDomain: boolean): Promise<void> {
    ApiDomainSettings.apply(useCoDomain)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_USE_CO_DOMAIN, useCoDomain)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存 API 域名设置失败')
    }
  }
}
