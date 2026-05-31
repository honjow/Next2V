import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { connectAuthIdentity } from '../state/AuthIdentityState'
import { setAppStorageValue } from './SettingsStorage'
import { STORE_NAME_AUTH } from './SettingsStores'

const STORE_NAME: string = STORE_NAME_AUTH
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
      throw new Error(e.message || 'Failed to read login settings')
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
      throw new Error(e.message || 'Failed to save login settings')
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
      throw new Error(e.message || 'Failed to clear login settings')
    }
  }

  static apply(token: string, username: string): void {
    const tokenConfigured = token.trim().length > 0
    setAppStorageValue<boolean>(StorageKeys.AUTH_TOKEN_CONFIGURED, tokenConfigured)
    setAppStorageValue<string>(StorageKeys.AUTH_USERNAME, username)
    // Dual-write the V2 mirror (read by @ComponentV2 AccountPage) from this single chokepoint
    // (load / saveToken / clear all route through apply) so the two stores stay in lockstep.
    const identity = connectAuthIdentity()
    identity.tokenConfigured = tokenConfigured
    identity.username = username
  }
}
