import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { setAppStorageValue } from './SettingsStorage'
import { STORE_NAME_AUTH_SESSION } from './SettingsStores'
import { connectAuthSessionSignal } from '../state/AuthSessionSignalState'

const STORE_NAME: string = STORE_NAME_AUTH_SESSION
const KEY_LOGIN_MODE: string = 'loginMode'
const KEY_USERNAME: string = 'username'
const KEY_AVATAR: string = 'avatar'
const KEY_VALIDATED_AT: string = 'validatedAt'

export type AuthLoginMode = 'none' | 'cookie' | 'pat'

export interface AuthSessionSnapshot {
  loginMode: AuthLoginMode
  username: string
  avatar: string
  validatedAt: number
}

const DEFAULT_SNAPSHOT: AuthSessionSnapshot = {
  loginMode: 'none',
  username: '',
  avatar: '',
  validatedAt: 0
}

export class AuthSessionSettings {
  static async load(context: common.UIAbilityContext): Promise<AuthSessionSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const loginMode = store.getSync(KEY_LOGIN_MODE, 'none') as AuthLoginMode
      const username = store.getSync(KEY_USERNAME, '') as string
      const avatar = store.getSync(KEY_AVATAR, '') as string
      const validatedAt = store.getSync(KEY_VALIDATED_AT, 0) as number
      const snapshot: AuthSessionSnapshot = {
        loginMode: loginMode || 'none',
        username: username || '',
        avatar: avatar || '',
        validatedAt: validatedAt || 0
      }
      AuthSessionSettings.apply(snapshot)
      return snapshot
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read session settings')
    }
  }

  static async save(context: common.UIAbilityContext, snapshot: AuthSessionSnapshot): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_LOGIN_MODE, snapshot.loginMode)
      store.putSync(KEY_USERNAME, snapshot.username || '')
      store.putSync(KEY_AVATAR, snapshot.avatar || '')
      store.putSync(KEY_VALIDATED_AT, snapshot.validatedAt || 0)
      store.flushSync()
      AuthSessionSettings.apply(snapshot)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save session settings')
    }
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_LOGIN_MODE)
      store.deleteSync(KEY_USERNAME)
      store.deleteSync(KEY_AVATAR)
      store.deleteSync(KEY_VALIDATED_AT)
      store.flushSync()
      AuthSessionSettings.apply(DEFAULT_SNAPSHOT)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to clear session settings')
    }
  }

  static apply(snapshot: AuthSessionSnapshot): void {
    setAppStorageValue<string>(StorageKeys.AUTH_LOGIN_MODE, snapshot.loginMode || 'none')
    setAppStorageValue<string>(StorageKeys.AUTH_SESSION_USERNAME, snapshot.username || '')
    setAppStorageValue<string>(StorageKeys.AUTH_SESSION_AVATAR, snapshot.avatar || '')
    setAppStorageValue<number>(StorageKeys.AUTH_SESSION_VALIDATED_AT, snapshot.validatedAt || 0)
    // Dual-write the V1 AppStorage signal (V1 @StorageLink readers) AND the V2 mirror
    // (@ComponentV2 readers) from this single chokepoint so the two stores stay in lockstep.
    const updatedAt = Date.now()
    setAppStorageValue<number>(StorageKeys.AUTH_SESSION_UPDATED_AT, updatedAt)
    connectAuthSessionSignal().updatedAt = updatedAt
  }
}
