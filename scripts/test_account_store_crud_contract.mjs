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
const forbiddenUiFiles = [
  'entry/src/main/ets/pages/AccountPage.ets',
  'entry/src/main/ets/pages/Index.ets',
  'feature/settings/src/main/ets/pages/SettingsPage.ets',
  'entry/src/main/ets/pages/V2exNativeLoginPage.ets',
  'entry/src/main/ets/pages/V2exWebLoginPage.ets',
]
const worktreePath = (rel) => path.join(repo, rel)
for (const rel of forbiddenUiFiles) {
  // File existing is OK; verify it does NOT contain AccountStore references (no unauthorized integration)
  if (fs.existsSync(worktreePath(rel))) {
    const text = read(rel)
    assert(
      !text.includes('AccountStore'),
      `${rel} must not reference AccountStore — Lane A is data layer only`
    )
  }
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

console.log('account store crud contract ok')
