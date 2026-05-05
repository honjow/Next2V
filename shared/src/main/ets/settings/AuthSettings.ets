import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'

const STORE_NAME: string = 'next2v_auth'
const KEY_TOKEN: string = 'personalAccessToken'
const KEY_USERNAME: string = 'username'

export interface AuthSnapshot {
  token: string
  username: string
}

export class AuthSettings {
  static async load(context: common.UIAbilityContext): Promise<AuthSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const token = store.getSync(KEY_TOKEN, '') as string
      const username = store.getSync(KEY_USERNAME, '') as string
      AuthSettings.apply(token, username)
      return { token, username }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取登录设置失败')
    }
  }

  static async saveToken(context: common.UIAbilityContext, token: string, username: string = ''): Promise<void> {
    try {
      const cleanToken = token.trim()
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_TOKEN, cleanToken)
      if (username) {
        store.putSync(KEY_USERNAME, username)
      }
      store.flushSync()
      AuthSettings.apply(cleanToken, username)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存登录设置失败')
    }
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_TOKEN)
      store.deleteSync(KEY_USERNAME)
      store.flushSync()
      AuthSettings.apply('', '')
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '清除登录设置失败')
    }
  }

  static apply(token: string, username: string): void {
    AppStorage.setOrCreate<boolean>(StorageKeys.AUTH_TOKEN_CONFIGURED, token.trim().length > 0)
    AppStorage.setOrCreate<string>(StorageKeys.AUTH_USERNAME, username)
  }
}
