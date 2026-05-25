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

const seed = read('shared/src/main/ets/settings/AccountStoreQaSeed.ets')
const storage = read('feature/settings/src/main/ets/pages/StorageSettingsPage.ets')
const sharedIndex = read('shared/src/main/ets/Index.ets')
const appStrings = read('shared/src/main/ets/i18n/AppStrings.ets')
const accountStore = read('shared/src/main/ets/settings/AccountStore.ets')

// ── File existence ──────────────────────────────────────────────
assert(fs.existsSync(path.join(repo, 'shared/src/main/ets/settings/AccountStoreQaSeed.ets')), 'AccountStoreQaSeed.ets must exist')

// ── Import BuildProfile ─────────────────────────────────────────
assert(seed.includes("import BuildProfile from '../../../../BuildProfile'"), 'AccountStoreQaSeed must import shared BuildProfile')
assert(/static\s+isEnabled\s*\(\s*\)\s*:\s*boolean\s*{[\s\S]*return\s+BuildProfile\.DEBUG[\s\S]*}/.test(seed), 'AccountStoreQaSeed isEnabled must return BuildProfile.DEBUG')
assert(seed.includes('static assertEnabled(): void') && seed.includes('AccountStoreQaSeed.isEnabled()'), 'AccountStoreQaSeed must expose assertEnabled guard')

// ── All public methods call assertEnabled ───────────────────────
for (const method of ['seedFakeAccounts', 'resetSeededAccounts']) {
  const pattern = new RegExp(`static\\s+async\\s+${method}[\\s\\S]*?AccountStoreQaSeed\\.assertEnabled\\(\\)`)
  assert(pattern.test(seed), `${method} must call assertEnabled internally`)
}

// ── Synthetic username prefix ───────────────────────────────────
assert(seed.includes('qa_debug_user_'), 'seedFakeAccounts must use qa_debug_user_ prefix for synthetic usernames')
assert(seed.includes("SEED_USERNAME_PREFIX: string = 'qa_debug_user_'"), 'SEED_USERNAME_PREFIX must be qa_debug_user_')

// ── cookieSnapshot / tokenSnapshot empty ────────────────────────
assert(seed.includes("cookieSnapshot: ''"), 'seedFakeAccounts must set cookieSnapshot to empty string')
assert(seed.includes("tokenSnapshot: ''"), 'seedFakeAccounts must set tokenSnapshot to empty string')

// ── No network/cookie auth modules ──────────────────────────────
assert(!seed.includes('HttpClient') && !seed.includes('CookieJarSettings') && !seed.includes('V2exNativeAuthService'), 'AccountStoreQaSeed must not import network or cookie auth modules')

// ── Uses AccountStore for CRUD ──────────────────────────────────
assert(seed.includes("import { AccountStore } from './AccountStore'"), 'AccountStoreQaSeed must import AccountStore')
assert(seed.includes('AccountStore.add'), 'AccountStoreQaSeed must call AccountStore.add for seeding')
assert(seed.includes('AccountStore.getAll'), 'AccountStoreQaSeed must call AccountStore.getAll for reset')
assert(seed.includes('AccountStore.remove'), 'AccountStoreQaSeed must call AccountStore.remove for targeted reset')
assert(seed.includes('AccountStore.setActiveId'), 'AccountStoreQaSeed must set active ID after debug seeding when needed')
assert(seed.includes('AccountStore.restoreActiveId'), 'AccountStoreQaSeed must restore/check persisted active ID after seeding')
assert(seed.includes('AuthSessionSettings.save'), 'AccountStoreQaSeed must apply matching AuthSession snapshot for active seeded account')

// ── resetSeededAccounts targets seed prefix only ────────────────
const resetMethod = seed.slice(seed.indexOf('resetSeededAccounts'))
assert(resetMethod.includes('SEED_USERNAME_PREFIX'), 'resetSeededAccounts must filter by SEED_USERNAME_PREFIX')
assert(resetMethod.includes('.startsWith'), 'resetSeededAccounts must use startsWith to identify seed accounts')

// ── Shared Index export ─────────────────────────────────────────
assert(sharedIndex.includes("export { AccountStoreQaSeed } from './settings/AccountStoreQaSeed'"), 'shared Index must export AccountStoreQaSeed')
assert(sharedIndex.includes("AccountStoreQaSeedResult") && sharedIndex.includes("'./settings/AccountStoreQaSeed'"), 'shared Index must export AccountStoreQaSeedResult type')

// ── StorageSettingsPage guards ──────────────────────────────────
assert(storage.includes("import BuildProfile from '../../../../BuildProfile'"), 'StorageSettingsPage must import feature BuildProfile')
assert(/if\s*\(\s*BuildProfile\.DEBUG\s*&&\s*AccountStoreQaSeed\.isEnabled\s*\(\s*\)\s*\)/.test(storage), 'StorageSettingsPage Account seed section must be BuildProfile.DEBUG guarded')
assert(storage.includes('AccountStoreQaSeed'), 'StorageSettingsPage must import AccountStoreQaSeed')
assert(storage.includes('AccountQaSeedSection'), 'StorageSettingsPage must define AccountQaSeedSection')
assert(/!BuildProfile\.DEBUG\s*\|\|\s*!AccountStoreQaSeed\.isEnabled\s*\(\s*\)/.test(storage), 'StorageSettingsPage account seed actions must runtime-check debug guard')

// ── Resource keys completeness (5 locales) ──────────────────────
const requiredKeys = ['account_qa_seed', 'seed_account_records', 'reset_seeded_accounts']
const locales = ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']
for (const locale of locales) {
  const stringsPath = `entry/src/main/resources/${locale}/element/string.json`
  assert(fs.existsSync(path.join(repo, stringsPath)), `Missing resource dir: ${locale}`)
  const text = read(stringsPath)
  for (const key of requiredKeys) {
    assert(
      text.includes(`"name": "${key}"`),
      `Missing resource key "${key}" in ${locale}/string.json`
    )
  }
}

// ── AppStrings.ets must register new keys ────────────────────────
const appStringsKeys = ['R_ACCOUNT_QA_SEED', 'R_SEED_ACCOUNT_RECORDS', 'R_RESET_SEEDED_ACCOUNTS']
for (const key of appStringsKeys) {
  assert(
    appStrings.includes(key),
    `AppStrings.ets missing key: ${key}`
  )
}

// ── en_US fallbacks must not contain CJK ─────────────────────────
const enStrings = read('entry/src/main/resources/en_US/element/string.json')
for (const key of requiredKeys) {
  const match = enStrings.match(new RegExp(`"name": "${key}"[^}]*"value": "([^"]*)"`))
  if (match) {
    const value = match[1]
    const hasCJK = /[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]/.test(value)
    assert(
      !hasCJK,
      `en_US fallback for "${key}" must not contain CJK characters: "${value}"`
    )
  }
}

// ── Release/normal pages must not reference AccountStoreQaSeed ──
const forbiddenUiFiles = [
  'entry/src/main/ets/pages/Index.ets',
  'entry/src/main/ets/pages/AccountPage.ets',
  'entry/src/main/ets/pages/V2exNativeLoginPage.ets',
  'entry/src/main/ets/pages/V2exWebLoginPage.ets',
]
for (const rel of forbiddenUiFiles) {
  if (fs.existsSync(path.join(repo, rel))) {
    const text = read(rel)
    assert(
      !text.includes('AccountStoreQaSeed'),
      `${rel} must not reference AccountStoreQaSeed — release page must not expose seed tool`
    )
  }
}

// ── AccountStoreQaSeed must import AccountStore, not duplicate store ──
assert(seed.includes("import { AccountStore } from './AccountStore'"), 'AccountStoreQaSeed must reuse AccountStore')
assert(seed.includes("import type { AccountRecord, AccountRecordInput } from './AccountStore'"), 'AccountStoreQaSeed must import types from AccountStore')

// ── loginMode must be legal value ────────────────────────────────
assert(seed.includes("loginMode: 'cookie'"), 'seedFakeAccounts must use legal loginMode cookie')

console.log('account store QA seed static contract OK')
