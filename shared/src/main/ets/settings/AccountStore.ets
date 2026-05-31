import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { HttpClient } from '../network/HttpClient'
import { StorageKeys } from '../constants/StorageKeys'
import { connectActiveAccount } from '../state/ActiveAccountState'
import { setAppStorageValue } from './SettingsStorage'
import { STORE_NAME_ACCOUNTS } from './SettingsStores'
import { AuthSessionSettings } from './AuthSessionSettings'
import { CookieJarSettings } from './CookieJarSettings'
import { AppStrings } from '../i18n/AppStrings'
import { TopicDetailActionOverlaySettings } from '../cache/TopicDetailActionOverlaySettings'

const STORE_NAME: string = STORE_NAME_ACCOUNTS
const KEY_RECORDS: string = 'records'
const KEY_SCHEMA_VERSION: string = 'schemaVersion'
const KEY_ACTIVE_ACCOUNT_ID: string = StorageKeys.ACTIVE_ACCOUNT_ID

export const CURRENT_SCHEMA_VERSION: number = 1

export interface AccountRecord {
  id: string
  username: string
  avatar: string
  loginMode: 'cookie' | 'pat'
  baseUrl: string
  cookieSnapshot: string
  tokenSnapshot: string
  validatedAt: number
  addedAt: number
  updatedAt: number
}

function generateId(): string {
  let template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  const hex = '0123456789abcdef'
  return template.replace(/[xy]/g, (c: string): string => {
    const r: number = Math.floor(Math.random() * 16)
    if (c === 'x') {
      return hex.charAt(r)
    }
    return hex.charAt((r & 0x3) | 0x8)
  })
}

export interface AccountRecordInput {
  username: string
  avatar: string
  loginMode: 'cookie' | 'pat'
  baseUrl: string
  cookieSnapshot: string
  tokenSnapshot: string
  validatedAt: number
}

export class AccountStore {
  private static activeAccountId: string = ''

  static async getAll(context: common.UIAbilityContext): Promise<AccountRecord[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_RECORDS, '[]') as string
      if (!raw || raw === '[]') {
        return []
      }
      const parsed: AccountRecord[] = JSON.parse(raw)
      return Array.isArray(parsed) ? parsed : []
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text(AppStrings.R_ACCOUNT_READ_LIST_FAILED, 'Failed to read account list'))
    }
  }

  static async getById(context: common.UIAbilityContext, id: string): Promise<AccountRecord | null> {
    const all = await AccountStore.getAll(context)
    return all.find(r => r.id === id) ?? null
  }

  static async add(context: common.UIAbilityContext, input: AccountRecordInput): Promise<AccountRecord> {
    const now = Date.now()
    const record: AccountRecord = {
      id: generateId(),
      username: input.username,
      avatar: input.avatar,
      loginMode: input.loginMode,
      baseUrl: input.baseUrl,
      cookieSnapshot: input.cookieSnapshot,
      tokenSnapshot: input.tokenSnapshot,
      validatedAt: input.validatedAt,
      addedAt: now,
      updatedAt: now,
    }
    const all = await AccountStore.getAll(context)
    all.push(record)
    await AccountStore.saveAllAndFlush(context, all)
    return record
  }

  static async update(context: common.UIAbilityContext, record: AccountRecord): Promise<AccountRecord> {
    const now = Date.now()
    record.updatedAt = now
    const all = await AccountStore.getAll(context)
    const index = all.findIndex(r => r.id === record.id)
    if (index < 0) {
      throw new Error(AppStrings.text(AppStrings.R_ACCOUNT_RECORD_NOT_FOUND, 'Account record not found'))
    }
    all[index] = record
    await AccountStore.saveAllAndFlush(context, all)
    return record
  }

  static async remove(context: common.UIAbilityContext, id: string): Promise<void> {
    let all = await AccountStore.getAll(context)
    const removed = all.find(r => r.id === id)
    if (!removed) {
      return
    }
    all = all.filter(r => r.id !== id)
    await TopicDetailActionOverlaySettings.clearByOwner(context, removed.baseUrl, removed.id)
    const store = await preferences.getPreferences(context, STORE_NAME)
    store.putSync(KEY_RECORDS, JSON.stringify(all))
    if (AccountStore.activeAccountId === id) {
      AccountStore.activeAccountId = ''
      store.deleteSync(KEY_ACTIVE_ACCOUNT_ID)
      AccountStore.applyActiveAccountId('')
    }
    store.flushSync()
  }

  static async setActiveId(context: common.UIAbilityContext, id: string): Promise<void> {
    AccountStore.activeAccountId = id
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_ACTIVE_ACCOUNT_ID, id)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text(AppStrings.R_ACCOUNT_ACTIVE_ID_SAVE_FAILED, 'Failed to save active account ID'))
    }
    AccountStore.applyActiveAccountId(id)
  }

  static getActiveId(): string {
    return AccountStore.activeAccountId
  }

  // Single chokepoint for the active-account-id AppStorage write: dual-write the V1 key (V1
  // @StorageLink readers) AND the V2 mirror (read/@Monitor by @ComponentV2 AccountPage /
  // AccountDetailPage) so they never diverge. This only reflects WHICH account is active; the
  // switch/remove/restore state machine above still owns the actual transition.
  private static applyActiveAccountId(id: string): void {
    setAppStorageValue<string>(StorageKeys.ACTIVE_ACCOUNT_ID, id)
    connectActiveAccount().id = id
  }

  /**
   * Read the persisted active account ID from preferences and restore to transient static field.
   * Must be called before getActiveId() to ensure active ID survives process restart.
   */
  static async restoreActiveId(context: common.UIAbilityContext): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const persisted = store.getSync(KEY_ACTIVE_ACCOUNT_ID, '') as string
      if (persisted) {
        AccountStore.activeAccountId = persisted
        AccountStore.applyActiveAccountId(persisted)
      }
    } catch {
      // Retain current transient value on read failure
    }
    return AccountStore.activeAccountId
  }

  static async clearAll(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_RECORDS)
      store.deleteSync(KEY_SCHEMA_VERSION)
      store.deleteSync(KEY_ACTIVE_ACCOUNT_ID)
      store.flushSync()
      AccountStore.activeAccountId = ''
      AccountStore.applyActiveAccountId('')
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text(AppStrings.R_ACCOUNT_CLEAR_DATA_FAILED, 'Failed to clear account data'))
    }
  }

  /**
   * Migrate from single account (CookieJarSettings + AuthSessionSettings) to AccountStore.
   * Read original store, write only AccountStore + ACTIVE_ACCOUNT_ID, do not modify original store.
   * Idempotent: skip if records exist or schemaVersion is already present.
   */
  static async migrateFromSingletonIfNeeded(context: common.UIAbilityContext): Promise<AccountRecord | null> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)

      const schemaVersion = store.getSync(KEY_SCHEMA_VERSION, 0) as number
      if (schemaVersion >= CURRENT_SCHEMA_VERSION) {
        return null
      }

      const existing = await AccountStore.getAll(context)
      if (existing.length > 0) {
        store.putSync(KEY_SCHEMA_VERSION, CURRENT_SCHEMA_VERSION)
        store.flushSync()
        return null
      }

      const sessionSnapshot = await AuthSessionSettings.load(context)
      if (!sessionSnapshot.username || sessionSnapshot.loginMode === 'none') {
        store.putSync(KEY_SCHEMA_VERSION, CURRENT_SCHEMA_VERSION)
        store.flushSync()
        return null
      }

      const currentCookie = CookieJarSettings.getCurrentCookie()
      if (!currentCookie) {
        store.putSync(KEY_SCHEMA_VERSION, CURRENT_SCHEMA_VERSION)
        store.flushSync()
        return null
      }

      const baseUrl = HttpClient.getInstance().getBaseUrl()
      const now = Date.now()
      const record: AccountRecord = {
        id: generateId(),
        username: sessionSnapshot.username,
        avatar: sessionSnapshot.avatar || '',
        loginMode: sessionSnapshot.loginMode as 'cookie' | 'pat',
        baseUrl: baseUrl,
        cookieSnapshot: currentCookie,
        tokenSnapshot: '',
        validatedAt: sessionSnapshot.validatedAt,
        addedAt: now,
        updatedAt: now,
      }

      await AccountStore.saveAllAndFlush(context, [record])
      store.putSync(KEY_SCHEMA_VERSION, CURRENT_SCHEMA_VERSION)
      store.flushSync()

      await AccountStore.setActiveId(context, record.id)

      return record
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text(AppStrings.R_ACCOUNT_DATA_MIGRATION_FAILED, 'Account data migration failed'))
    }
  }

  private static async saveAllAndFlush(context: common.UIAbilityContext, records: AccountRecord[]): Promise<void> {
    const store = await preferences.getPreferences(context, STORE_NAME)
    store.putSync(KEY_RECORDS, JSON.stringify(records))
    store.flushSync()
  }
}
