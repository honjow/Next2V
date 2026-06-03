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

const accountPageRel = 'entry/src/main/ets/pages/AccountPage.ets'
assert(fs.existsSync(path.join(repo, accountPageRel)), 'AccountPage.ets must exist')
const accountPage = read(accountPageRel)

// Me tab boundary: overview/content only, no multi-account management controls.
for (const token of [
  'AccountSessionCoordinator',
  'prepareAddAccount',
  'switchToAccount',
  'MultiAccountSection',
  'performRemoveAccount',
  'AccountPageCoordinator.SWITCH_LABEL',
  'AccountPageCoordinator.REMOVE_LABEL',
  'AccountPageCoordinator.ADD_ANOTHER_ACCOUNT_TITLE',
]) {
  assert(!accountPage.includes(token), `AccountPage.ets must not expose multi-account management token: ${token}`)
}

// Settings -> Account management owns add/switch/remove UI and state.
const managementPageRel = 'entry/src/main/ets/pages/AccountManagementPage.ets'
assert(fs.existsSync(path.join(repo, managementPageRel)), 'AccountManagementPage.ets must exist')
const managementPage = read(managementPageRel)
for (const token of [
  'AccountStore',
  'AccountSessionCoordinator',
  'AccountRecord',
  'loadAccounts()',
  'restoreActiveId(context)',
  'migrateFromSingletonIfNeeded',
  'getAll(context)',
  'getActiveId()',
  'prepareAddAccount',
  'switchToAccount',
  'performRemoveAccount',
  '@Local private accounts: AccountRecord[]',
  '@Local private activeAccountId: string',
  '@Local private isLoaded: boolean',
]) {
  assert(managementPage.includes(token), `AccountManagementPage.ets missing expected token: ${token}`)
}

// Account route must not reuse the Me/dashboard detail variant.
const indexPage = read('entry/src/main/ets/pages/Index.ets')
assert(
  indexPage.includes("import { AccountManagementPage } from './AccountManagementPage'"),
  'Index.ets must import AccountManagementPage'
)
assert(
  /descriptor\.family\s*===\s*'account'[\s\S]{0,120}AccountManagementPage\(\)/.test(indexPage),
  'Index.ets account destination must render AccountManagementPage'
)
assert(
  !/descriptor\.family\s*===\s*'account'[\s\S]{0,160}AccountDashboardPage\s*\(\s*\{\s*showDetail\s*:\s*true\s*\}/.test(indexPage),
  'Index.ets account destination must not render AccountDashboardPage({ showDetail: true })'
)

// Login pages must use AccountSessionCoordinator, not AccountStore directly.
for (const rel of [
  'entry/src/main/ets/pages/V2exNativeLoginPage.ets',
  'entry/src/main/ets/pages/V2exWebLoginPage.ets',
]) {
  const text = read(rel)
  assert(
    !text.includes('AccountStore'),
    `${rel} must not reference AccountStore - use AccountSessionCoordinator instead`
  )
  assert(text.includes('AccountSessionCoordinator'), `${rel} must import AccountSessionCoordinator`)
  assert(text.includes('registerCurrentSession'), `${rel} must call AccountSessionCoordinator.registerCurrentSession()`)
}

// Resource key completeness
const requiredKeys = ['account_list_header', 'account_active_label']
const locales = ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']
for (const locale of locales) {
  const stringsPath = `entry/src/main/resources/${locale}/element/string.json`
  if (!fs.existsSync(path.join(repo, stringsPath))) {
    continue
  }
  const text = read(stringsPath)
  for (const key of requiredKeys) {
    assert(text.includes(`"name": "${key}"`), `Missing resource key "${key}" in ${locale}/string.json`)
  }
}

const appStrings = read('shared/src/main/ets/i18n/AppStrings.ets')
for (const key of ['R_ACCOUNT_LIST_HEADER', 'R_ACCOUNT_ACTIVE_LABEL']) {
  assert(appStrings.includes(key), `AppStrings.ets missing key: ${key}`)
}

const coordinator = read('entry/src/main/ets/model/AccountPageCoordinator.ets')
for (const token of ['ACCOUNT_LIST_HEADER', 'ACCOUNT_ACTIVE_LABEL']) {
  assert(coordinator.includes(token), `AccountPageCoordinator.ets missing token: ${token}`)
}

const sharedIndex = read('shared/src/main/ets/Index.ets')
assert(
  sharedIndex.includes("export { AccountStore } from './settings/AccountStore'"),
  'shared/Index.ets must export AccountStore'
)
assert(
  sharedIndex.includes('AccountRecord') && sharedIndex.includes("'./settings/AccountStore'"),
  'shared/Index.ets must export AccountRecord type'
)
assert(
  sharedIndex.includes("export { AccountSessionCoordinator } from './settings/AccountSessionCoordinator'"),
  'shared/Index.ets must export AccountSessionCoordinator'
)

const enStrings = read('entry/src/main/resources/en_US/element/string.json')
for (const key of requiredKeys) {
  const match = enStrings.match(new RegExp(`"name": "${key}"[^}]*"value": "([^"]*)"`))
  if (match) {
    const hasCJK = /[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]/.test(match[1])
    assert(!hasCJK, `en_US fallback for "${key}" must not contain CJK characters: "${match[1]}"`)
  }
}

assert(
  managementPage.includes('AccountPageCoordinator.ACCOUNT_LIST_HEADER'),
  'AccountManagementPage must use ACCOUNT_LIST_HEADER for multi-account section'
)
assert(
  managementPage.includes('isLoaded && this.accounts.length > 0'),
  'AccountManagementPage must gate multi-account section on isLoaded and accounts.length'
)
assert(
  managementPage.includes('(record: AccountRecord'),
  'AccountManagementPage must use AccountRecord type in ForEach'
)

const loadIdx = managementPage.indexOf('private loadAccounts()')
assert(loadIdx >= 0, 'AccountManagementPage must define private loadAccounts()')
const loadMethod = managementPage.slice(loadIdx, loadIdx + 800)
const restorePos = loadMethod.indexOf('restoreActiveId')
const getActivePos = loadMethod.indexOf('getActiveId')
assert(
  restorePos >= 0 && getActivePos >= 0 && restorePos < getActivePos,
  'AccountManagementPage.loadAccounts must call restoreActiveId before getActiveId to restore persisted active state'
)

// Logged-out honesty: a lone stale cookie must not produce fake/generic signed-in UI.
assert(
  coordinator.includes('accountsCount') && coordinator.includes('sessionUsername'),
  'AccountPageCoordinator.hasAnyAccount must accept accountsCount and sessionUsername params'
)
assert(/accountsCount\s*>\s*0/.test(coordinator), 'AccountPageCoordinator.hasAnyAccount must check accountsCount > 0 first')
assert(
  /authCookieConfigured[\s\S]{0,200}sessionUsername/.test(coordinator),
  'AccountPageCoordinator.hasAnyAccount must not return true on authCookieConfigured alone'
)
assert(
  /hasAnyAccount\([\s\S]*?this\.accountsCount/.test(accountPage),
  'AccountPage.hasAnyAccount must pass account count from AccountStore'
)
assert(
  /hasAnyAccount\([\s\S]*?this\.session\.username/.test(accountPage),
  'AccountPage.hasAnyAccount must pass the session username'
)
assert(
  accountPage.includes('@Local private activeAccountUsername') &&
    accountPage.includes('@Local private activeAccountAvatar') &&
    accountPage.includes('AccountStore.getById(context, activeId)'),
  'AccountPage must load active AccountStore identity fallback for Me signed-in card'
)
assert(
  /identity\([\s\S]*?this\.activeAccountUsername[\s\S]*?this\.activeAccountAvatar/.test(accountPage),
  'AccountPage current identity must pass active AccountStore username/avatar fallback'
)
// V2 @Monitor handler (no _propName param); the refresh now coalesces through requestDashboardRefresh,
// which in turn reloads AccountStore state (loadAccounts) via refreshDashboardSnapshot.
const refreshKeyHandlerMatch = accountPage.match(/onRefreshKeyChanged\(\): void \{([\s\S]*?)\n  \}/)
assert(refreshKeyHandlerMatch, 'AccountPage must define onRefreshKeyChanged handler')
assert(
  refreshKeyHandlerMatch[1].includes('this.requestDashboardRefresh('),
  'AccountPage.onRefreshKeyChanged must refresh the dashboard (AccountStore state) for mounted Me tab'
)
const visibleAreaHandlerMatch = accountPage.match(/\.onVisibleAreaChange\(\[0\.0, 1\.0\],\s*\(isVisible: boolean, _currentRatio: number\) => \{([\s\S]*?)\n\s*\}\)/)
assert(visibleAreaHandlerMatch, 'AccountPage must define visible-area refresh handler')
assert(
  /if\s*\(isVisible\)\s*\{[\s\S]*?this\.requestDashboardRefresh\(/.test(visibleAreaHandlerMatch[1]),
  'AccountPage visible refresh path must refresh the dashboard when Me becomes visible'
)
// The coalesced refresh must actually reload AccountStore state.
const refreshSnapshotMatch = accountPage.match(/private refreshDashboardSnapshot\([\s\S]*?\n  \}/)
assert(
  refreshSnapshotMatch && refreshSnapshotMatch[0].includes('this.loadAccounts()'),
  'AccountPage.refreshDashboardSnapshot must reload AccountStore state (loadAccounts)'
)
assert(
  accountPage.includes('!this.hasAnyAccount()'),
  'AccountPage must have logged-out branch for !hasAnyAccount()'
)
// Honest logged-out state: the account list is gated on actually having accounts, so nothing renders
// when logged out (no fake/generic signed-in detail), rather than a fabricated card.
assert(
  managementPage.includes('this.isLoaded && this.accounts.length > 0'),
  'AccountManagementPage must gate the account list on having accounts (renders nothing when logged out)'
)
assert(
  !managementPage.includes('AccountDetailHeaderCard') && !managementPage.includes('R_ACCOUNT_V2EX_USER'),
  'AccountManagementPage must not render fake/generic signed-in account detail'
)

console.log('multi-account ui contract ok')
