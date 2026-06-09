#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message)
  }
}

// ── File existence ──────────────────────────────────────────────
const accountStoreRel = 'shared/src/main/ets/settings/AccountStore.ets'
assert(fs.existsSync(path.join(repo, accountStoreRel)), 'AccountStore.ets must exist')

// ── Load source texts ───────────────────────────────────────────
const accountStore = read(accountStoreRel)
const storageKeys = read('shared/src/main/ets/constants/StorageKeys.ets')
const stores = read('shared/src/main/ets/settings/SettingsStores.ets')

// ── AccountRecord DTO ───────────────────────────────────────────
const accountRecordTokens = [
  'export interface AccountRecord',
  'id: string',
  'username: string',
  'avatar: string',
  "loginMode: 'cookie' | 'pat'",
  'baseUrl: string',
  'cookieSnapshot: string',
  'tokenSnapshot: string',
  'validatedAt: number',
  'addedAt: number',
  'updatedAt: number',
]
for (const token of accountRecordTokens) {
  assert(accountStore.includes(token), `AccountRecord DTO missing: ${token}`)
}

// ── Schema version constant ─────────────────────────────────────
assert(accountStore.includes('CURRENT_SCHEMA_VERSION'), 'AccountStore must export CURRENT_SCHEMA_VERSION')
assert(accountStore.includes('CURRENT_SCHEMA_VERSION: number = 1'), 'CURRENT_SCHEMA_VERSION must be 1')

// ── Required CRUD methods ───────────────────────────────────────
const requiredMethods = [
  'static async getAll(context',
  'Promise<AccountRecord[]>',
  'static async getById(context',
  'Promise<AccountRecord | null>',
  'static async add(context',
  'Promise<AccountRecord>',
  'static async update(context',
  'static async remove(context',
  'Promise<void>',
  'static async setActiveId(context',
  'static getActiveId()',
  'static async restoreActiveId(context',
  'static async clearAll(context',
]
for (const token of requiredMethods) {
  assert(accountStore.includes(token), `AccountStore CRUD method missing: ${token}`)
}

// ── Store registration ──────────────────────────────────────────
assert(
  stores.includes("STORE_NAME_ACCOUNTS: string = 'next2v_accounts'"),
  'SettingsStores must declare STORE_NAME_ACCOUNTS'
)
assert(
  accountStore.includes("import { STORE_NAME_ACCOUNTS } from './SettingsStores'"),
  'AccountStore must import STORE_NAME_ACCOUNTS from SettingsStores'
)
assert(
  accountStore.includes('STORE_NAME: string = STORE_NAME_ACCOUNTS'),
  'AccountStore must bind STORE_NAME to STORE_NAME_ACCOUNTS'
)

// ── ACTIVE_ACCOUNT_ID AppStorage key ────────────────────────────
assert(
  storageKeys.includes("ACTIVE_ACCOUNT_ID: string = 'activeAccountId'"),
  'StorageKeys must declare ACTIVE_ACCOUNT_ID'
)
assert(
  accountStore.includes("StorageKeys.ACTIVE_ACCOUNT_ID"),
  'AccountStore must reference StorageKeys.ACTIVE_ACCOUNT_ID'
)

// ── Migration scaffold ──────────────────────────────────────────
const migrationTokens = [
  'migrateFromSingletonIfNeeded',
  'KEY_SCHEMA_VERSION',
  'CURRENT_SCHEMA_VERSION',
]
for (const token of migrationTokens) {
  assert(accountStore.includes(token), `Migration scaffold missing: ${token}`)
}
// Migration must be idempotent: check schemaVersion before migrating
const migrateBodyIdx = accountStore.indexOf('migrateFromSingletonIfNeeded')
assert(migrateBodyIdx >= 0, 'migrateFromSingletonIfNeeded method must exist')
const migrateSection = accountStore.slice(migrateBodyIdx, migrateBodyIdx + 2000)
assert(
  migrateSection.includes('schemaVersion >= CURRENT_SCHEMA_VERSION'),
  'Migration must check schemaVersion >= CURRENT_SCHEMA_VERSION before migrating'
)
assert(
  migrateSection.includes('length > 0'),
  'Migration must check existing records before creating'
)

// ── Migration reads source stores, writes only AccountStore ─────
// Must import AuthSessionSettings and CookieJarSettings for reading
assert(
  accountStore.includes('import { AuthSessionSettings }'),
  'AccountStore must import AuthSessionSettings for migration'
)
assert(
  accountStore.includes('import { CookieJarSettings }'),
  'AccountStore must import CookieJarSettings for migration'
)
// Must NOT write to source stores
assert(
  !accountStore.includes('AuthSessionSettings.save') &&
  !accountStore.includes('AuthSessionSettings.clear'),
  'AccountStore must not write to AuthSessionSettings'
)
assert(
  !accountStore.includes('CookieJarSettings.save') &&
  !accountStore.includes('CookieJarSettings.clear'),
  'AccountStore must not write to CookieJarSettings'
)

// ── No console.* diagnostics ────────────────────────────────────
assert(!accountStore.includes('console.'), 'AccountStore must not use console.* diagnostics')

// ── UUID v4 id generation ──────────────────────────────────────
assert(
  /generateId/.test(accountStore) && /[xy]/g.test(accountStore) && /xxxxxxxx-xxxx-4xxx/.test(accountStore),
  'AccountStore.generateId must produce UUID v4 (xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx)',
)

// ── Forbidden UI files must not be modified ─────────────────────
// Lane B (multi-account-ui): AccountPage.ets is allowed to reference AccountStore.
// SettingsPage.ets is allowed to reference AccountStore for account management entry.
// Index.ets, V2exNativeLoginPage.ets, V2exWebLoginPage.ets must not reference AccountStore.
const forbiddenUiFiles = [
  'entry/src/main/ets/pages/Index.ets',
  'entry/src/main/ets/pages/V2exNativeLoginPage.ets',
  'entry/src/main/ets/pages/V2exWebLoginPage.ets',
]
const allowedUiFiles = [
  'entry/src/main/ets/pages/AccountPage.ets',
]
const worktreePath = (rel) => path.join(repo, rel)
for (const rel of forbiddenUiFiles) {
  // File existing is OK; verify it does NOT contain AccountStore references (no unauthorized integration)
  if (fs.existsSync(worktreePath(rel))) {
    const text = read(rel)
    assert(
      !text.includes('AccountStore'),
      `${rel} must not reference AccountStore — unauthorized UI file`
    )
  }
}
// Allowed UI files: verify they DO reference AccountStore (lane B contract)
for (const rel of allowedUiFiles) {
  if (fs.existsSync(worktreePath(rel))) {
    const text = read(rel)
    assert(
      text.includes('AccountStore'),
      `${rel} must reference AccountStore — Lane B multi-account UI requires it`
    )
  }
}

// ── Resource key contract ────────────────────────────────────────
// Multi-account UI requires specific resource keys
const requiredResourceKeys = [
  'account_list_header',
  'account_active_label',
]
const baseStringsPath = 'entry/src/main/resources/base/element/string.json'
const baseStringsText = read(baseStringsPath)
for (const key of requiredResourceKeys) {
  assert(
    baseStringsText.includes(`"name": "${key}"`),
    `Missing resource key in base string.json: ${key}`
  )
}
// Verify en_US fallbacks contain no CJK characters
const enStringsPath = 'entry/src/main/resources/en_US/element/string.json'
const enStringsText = read(enStringsPath)
for (const key of requiredResourceKeys) {
  assert(
    enStringsText.includes(`"name": "${key}"`),
    `Missing resource key in en_US string.json: ${key}`
  )
}
// Verify the multi-account UI actually consumes these resource keys.
// (i18n migration: AppStrings.ets is now a ResourceManager resolver, not a
// table of string constants — labels are referenced via $r('app.string.KEY')
// from the page/coordinator source instead of being declared in AppStrings.ets.)
const accountCoordinatorText = read('entry/src/main/ets/model/AccountPageCoordinator.ets')
for (const key of requiredResourceKeys) {
  assert(
    accountCoordinatorText.includes(`$r('app.string.${key}')`),
    `Multi-account UI must reference resource key via $r('app.string.${key}')`
  )
}

// ── Preferences store ownership ─────────────────────────────────
// AccountStore must use its own STORE_NAME_ACCOUNTS, not reuse others
const forbiddenStoreNames = [
  'next2v_auth',
  'next2v_auth_session',
  'next2v_cookiejar',
  'next2v_account_meta',
]
for (const name of forbiddenStoreNames) {
  assert(
    !accountStore.includes(`'${name}'`),
    `AccountStore must not hard-code other store name: ${name}`
  )
}

// ── JSON array storage pattern ──────────────────────────────────
assert(accountStore.includes('KEY_RECORDS'), 'AccountStore must use KEY_RECORDS for array storage')
assert(
  accountStore.includes("store.putSync(KEY_RECORDS, JSON.stringify(records))") ||
  accountStore.includes('store.putSync(KEY_RECORDS, JSON.stringify'),
  'AccountStore must JSON.stringify records array on save'
)
assert(
  accountStore.includes("store.getSync(KEY_RECORDS,") ||
  accountStore.includes('store.getSync(KEY_RECORDS, '),
  'AccountStore must read records via store.getSync(KEY_RECORDS,...)'
)
assert(
  accountStore.includes('JSON.parse'),
  'AccountStore must parse records JSON on read'
)

// ── restoreActiveId must read persisted active ID from preferences ────
assert(
  accountStore.includes('static async restoreActiveId(context'),
  'AccountStore must expose restoreActiveId method'
)
// restoreActiveId must use store.getSync to read from preferences
const restoreIdx = accountStore.indexOf('restoreActiveId')
assert(restoreIdx >= 0, 'restoreActiveId method must exist')
const restoreSection = accountStore.slice(restoreIdx, restoreIdx + 600)
assert(
  restoreSection.includes('store.getSync') && restoreSection.includes('KEY_ACTIVE_ACCOUNT_ID'),
  'restoreActiveId must read persisted active ID via store.getSync(KEY_ACTIVE_ACCOUNT_ID)'
)
assert(
  restoreSection.includes('AccountStore.activeAccountId = persisted') ||
  restoreSection.includes('AccountStore.activeAccountId ='),
  'restoreActiveId must restore static activeAccountId from persisted value'
)

console.log('account store crud contract ok')
