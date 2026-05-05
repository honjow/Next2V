import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ApiConstants } from '../constants/ApiConstants'
import { StorageKeys } from '../constants/StorageKeys'
import { HttpClient } from '../network/HttpClient'

const STORE_NAME: string = 'next2v_settings'
const KEY_USE_CO_DOMAIN: string = 'useCoDomain'

export class ApiDomainSettings {
  static apply(useCoDomain: boolean): void {
    HttpClient.getInstance().setBaseUrl(useCoDomain ? ApiConstants.BASE_URL_CO : ApiConstants.BASE_URL_COM)
    AppStorage.setOrCreate<boolean>(StorageKeys.USE_CO_DOMAIN, useCoDomain)
  }

  static async load(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const useCoDomain = store.getSync(KEY_USE_CO_DOMAIN, false) as boolean
      ApiDomainSettings.apply(useCoDomain)
      return useCoDomain
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取 API 域名设置失败')
    }
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
