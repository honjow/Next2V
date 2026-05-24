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

// ── Target page must reference AccountStore ──────────────────────
const accountPageRel = 'entry/src/main/ets/pages/AccountPage.ets'
assert(fs.existsSync(path.join(repo, accountPageRel)), 'AccountPage.ets must exist')
const accountPage = read(accountPageRel)
const expectedTokens = [
  'import {',
  'AccountStore',
  'AccountRecord',
  "from 'shared'",
  'loadAccounts()',
  'restoreActiveId(context)',
  'migrateFromSingletonIfNeeded',
  'getAll(context)',
  'getActiveId()',
  'setActiveId',
  'MultiAccountSection()',
  '@State private accounts: AccountRecord[]',
  '@State private activeAccountId: string',
  '@State private isAccountsLoaded: boolean',
]
for (const token of expectedTokens) {
  assert(accountPage.includes(token), `AccountPage.ets missing expected token: ${token}`)
}

// ── Non-target pages must not reference AccountStore ─────────────
const forbiddenUiFiles = [
  'entry/src/main/ets/pages/Index.ets',
  'entry/src/main/ets/pages/V2exNativeLoginPage.ets',
  'entry/src/main/ets/pages/V2exWebLoginPage.ets',
]
for (const rel of forbiddenUiFiles) {
  if (fs.existsSync(path.join(repo, rel))) {
    const text = read(rel)
    assert(
      !text.includes('AccountStore'),
      `${rel} must not reference AccountStore`
    )
  }
}

// ── Resource key completeness ────────────────────────────────────
const requiredKeys = ['account_list_header', 'account_active_label']
const locales = ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']
for (const locale of locales) {
  const stringsPath = `entry/src/main/resources/${locale}/element/string.json`
  if (!fs.existsSync(path.join(repo, stringsPath))) {
    continue
  }
  const text = read(stringsPath)
  for (const key of requiredKeys) {
    assert(
      text.includes(`"name": "${key}"`),
      `Missing resource key "${key}" in ${locale}/string.json`
    )
  }
}

// ── AppStrings.ets must register new keys ────────────────────────
const appStrings = read('shared/src/main/ets/i18n/AppStrings.ets')
const appStringsKeys = ['R_ACCOUNT_LIST_HEADER', 'R_ACCOUNT_ACTIVE_LABEL']
for (const key of appStringsKeys) {
  assert(
    appStrings.includes(key),
    `AppStrings.ets missing key: ${key}`
  )
}

// ── AccountPageCoordinator must expose constants ─────────────────
const coordinator = read('entry/src/main/ets/model/AccountPageCoordinator.ets')
const coordinatorTokens = ['ACCOUNT_LIST_HEADER', 'ACCOUNT_ACTIVE_LABEL']
for (const token of coordinatorTokens) {
  assert(
    coordinator.includes(token),
    `AccountPageCoordinator.ets missing token: ${token}`
  )
}

// ── Shared Index.ets must export AccountStore ────────────────────
const sharedIndex = read('shared/src/main/ets/Index.ets')
assert(
  sharedIndex.includes("export { AccountStore } from './settings/AccountStore'"),
  'shared/Index.ets must export AccountStore'
)
assert(
  sharedIndex.includes('AccountRecord') && sharedIndex.includes("'./settings/AccountStore'"),
  'shared/Index.ets must export AccountRecord type'
)

// ── en_US fallbacks must not contain CJK ─────────────────────────
const enStrings = read('entry/src/main/resources/en_US/element/string.json')
for (const key of requiredKeys) {
  // Extract the value for this key from en_US strings
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

// ── AccountPage multi-account section must use SectionHeader ─────
// Verify the MultiAccountSection renders accounts with section header
assert(
  accountPage.includes('AccountPageCoordinator.ACCOUNT_LIST_HEADER'),
  'AccountPage must use ACCOUNT_LIST_HEADER for multi-account section'
)

// ── AccountPage must conditionally render on isAccountsLoaded ────
assert(
  accountPage.includes('isAccountsLoaded && this.accounts.length > 0'),
  'AccountPage must gate multi-account section on isAccountsLoaded and accounts.length'
)

// ── AccountRecord DTO used in ForEach ─────────────────────────────
assert(
  accountPage.includes('(record: AccountRecord)'),
  'AccountPage must use AccountRecord type in ForEach key generator'
)

// ── AccountPage load path must restore active ID before reading ──────
// Verify loadAccounts method calls restoreActiveId before getActiveId
const loadIdx = accountPage.indexOf('private loadAccounts()')
assert(loadIdx >= 0, 'AccountPage must define private loadAccounts()')
const loadMethod = accountPage.slice(loadIdx, loadIdx + 800)
// restoreActiveId must appear before getActiveId in loadAccounts
const restorePos = loadMethod.indexOf('restoreActiveId')
const getActivePos = loadMethod.indexOf('getActiveId')
assert(
  restorePos >= 0 && getActivePos >= 0 && restorePos < getActivePos,
  'AccountPage.loadAccounts must call restoreActiveId before getActiveId to restore persisted active state'
)

console.log('multi-account ui contract ok')
