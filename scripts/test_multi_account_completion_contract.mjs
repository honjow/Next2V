#!/usr/bin/env node
/**
 * Multi-account completion contract — real method/wiring assertions.
 *
 * Verifies that login pages call AccountSessionCoordinator,
 * Settings Account uses an independent management page with real session/cookie switching,
 * SettingsBootstrap restores active account,
 * and login pages do NOT bypass the coordinator.
 *
 * Run: node scripts/test_multi_account_completion_contract.mjs
 */
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message)
  }
}

// ── AccountSessionCoordinator existence ──────────────────────────
const coordinatorRel = 'shared/src/main/ets/settings/AccountSessionCoordinator.ets'
assert(fs.existsSync(path.join(repo, coordinatorRel)), 'AccountSessionCoordinator.ets must exist')
const coordinator = read(coordinatorRel)

const requiredMethods = [
  'registerCurrentSession',
  'switchToAccount',
  'removeAccount',
  'prepareAddAccount',
  'restoreActiveAccount',
]
for (const method of requiredMethods) {
  assert(
    coordinator.includes(`static async ${method}`),
    `AccountSessionCoordinator must expose static async ${method}()`
  )
}

const cookieJar = read('shared/src/main/ets/settings/CookieJarSettings.ets')
assert(
  cookieJar.includes('clearWebCookiesForBaseUrl'),
  'CookieJarSettings must expose clearWebCookiesForBaseUrl() for isolated web login'
)

// ── Shared Index exports AccountSessionCoordinator ───────────────
const sharedIndex = read('shared/src/main/ets/Index.ets')
assert(
  sharedIndex.includes("export { AccountSessionCoordinator } from './settings/AccountSessionCoordinator'"),
  'shared/Index.ets must export AccountSessionCoordinator'
)

// ── V2exNativeLoginPage must call registerCurrentSession ─────────
const nativeLogin = read('entry/src/main/ets/pages/V2exNativeLoginPage.ets')
assert(
  nativeLogin.includes('AccountSessionCoordinator'),
  'V2exNativeLoginPage must import AccountSessionCoordinator'
)
assert(
  nativeLogin.includes('registerCurrentSession'),
  'V2exNativeLoginPage must call AccountSessionCoordinator.registerCurrentSession()'
)

// ── V2exWebLoginPage must call registerCurrentSession ────────────
const webLogin = read('entry/src/main/ets/pages/V2exWebLoginPage.ets')
assert(
  webLogin.includes('AccountSessionCoordinator'),
  'V2exWebLoginPage must import AccountSessionCoordinator'
)
assert(
  webLogin.includes('this.loginStartCookie = CookieJarSettings.getCurrentCookie()') &&
    webLogin.includes('CookieJarSettings.clearWebCookiesForBaseUrl(this.baseUrl)') &&
    webLogin.includes('sameCookieHeader(cleanCookie, this.loginStartCookie)'),
  'V2exWebLoginPage must isolate WebView login from the existing active account cookie and ignore unchanged startup cookies during auto-save'
)

// ── Settings Account route must use independent management page ───
const indexPage = read('entry/src/main/ets/pages/Index.ets')
assert(
  indexPage.includes("import { AccountManagementPage } from './AccountManagementPage'"),
  'Index.ets must import AccountManagementPage for Settings -> Account management'
)
assert(
  /descriptor\.family\s*===\s*'account'[\s\S]{0,120}AccountManagementPage\(\)/.test(indexPage),
  'Index.ets account route must render AccountManagementPage()'
)
assert(
  !/descriptor\.family\s*===\s*'account'[\s\S]{0,160}AccountDashboardPage\s*\(\s*\{\s*showDetail\s*:\s*true\s*\}/.test(indexPage),
  'Index.ets account route must not reuse AccountDashboardPage({ showDetail: true })'
)

// ── Me page must not expose multi-account management actions ─────
const accountPage = read('entry/src/main/ets/pages/AccountPage.ets')
const forbiddenMeTokens = [
  'prepareAddAccount',
  'switchToAccount',
  'MultiAccountSection',
  'performRemoveAccount',
  'AccountPageCoordinator.SWITCH_LABEL',
  'AccountPageCoordinator.REMOVE_LABEL',
  'AccountPageCoordinator.ADD_ANOTHER_ACCOUNT_TITLE',
]
for (const token of forbiddenMeTokens) {
  assert(!accountPage.includes(token), `AccountPage.ets must not contain Me-tab management token: ${token}`)
}
// Migration complete: durable identity fallback fields use @Local (V2).
assert(
  accountPage.includes('@Local private activeAccountUsername') &&
  accountPage.includes('@Local private activeAccountAvatar'),
  'AccountPage must keep active AccountStore identity fallback state'
)
assert(
  accountPage.includes('AccountStore.restoreActiveId(context)') && accountPage.includes('AccountStore.getById(context, activeId)'),
  'AccountPage must restore active AccountStore ID and load the active record for identity fallback'
)
assert(
  accountPage.includes('this.activeAccountUsername') && accountPage.includes('this.activeAccountAvatar'),
  'AccountPage current identity must pass active AccountStore username/avatar fallback'
)
// Migration complete: handler uses @Monitor('refreshKey') with no _propName arg (V2 form).
const refreshKeyHandlerMatch = accountPage.match(/onRefreshKeyChanged\(\): void \{([\s\S]*?)\n  \}/)
assert(refreshKeyHandlerMatch, 'AccountPage must define onRefreshKeyChanged handler')
assert(
  refreshKeyHandlerMatch[1].includes('this.requestDashboardRefresh('),
  'AccountPage.onRefreshKeyChanged must trigger a dashboard refresh (which calls loadAccounts)'
)
const visibleAreaHandlerMatch = accountPage.match(/\.onVisibleAreaChange\(\[0\.0, 1\.0\],\s*\(isVisible: boolean, _currentRatio: number\) => \{([\s\S]*?)\n\s*\}\)/)
assert(visibleAreaHandlerMatch, 'AccountPage must define visible-area refresh handler')
assert(
  /if\s*\(isVisible\)\s*\{[\s\S]*?this\.requestDashboardRefresh\('visible'\)/.test(visibleAreaHandlerMatch[1]),
  'AccountPage visible refresh path must trigger dashboard refresh when Me becomes visible'
)
const requestDashboardRefreshMatch = accountPage.match(/requestDashboardRefresh\(reason: string\): void \{([\s\S]*?)\n  \}/)
assert(requestDashboardRefreshMatch, 'AccountPage must define requestDashboardRefresh coalescing helper')
assert(
  requestDashboardRefreshMatch[1].includes('this.refreshDashboardSnapshot(reason)'),
  'AccountPage.requestDashboardRefresh must call refreshDashboardSnapshot'
)
const refreshDashboardSnapshotMatch = accountPage.match(/refreshDashboardSnapshot\(reason: string\): void \{([\s\S]*?)\n  \}/)
assert(refreshDashboardSnapshotMatch, 'AccountPage must define refreshDashboardSnapshot')
assert(
  refreshDashboardSnapshotMatch[1].includes('this.loadAccounts()'),
  'AccountPage.refreshDashboardSnapshot must load AccountStore state'
)

const managementPageRel = 'entry/src/main/ets/pages/AccountManagementPage.ets'
assert(fs.existsSync(path.join(repo, managementPageRel)), 'AccountManagementPage.ets must exist')
const managementPage = read(managementPageRel)
assert(
  managementPage.includes('AccountSessionCoordinator.switchToAccount'),
  'AccountManagementPage must call AccountSessionCoordinator.switchToAccount() for account switching'
)
assert(
  managementPage.includes('AccountSessionCoordinator.removeAccount'),
  'AccountManagementPage must call AccountSessionCoordinator.removeAccount() for per-account removal'
)
assert(
  managementPage.includes('AccountSessionCoordinator.prepareAddAccount'),
  'AccountManagementPage must call AccountSessionCoordinator.prepareAddAccount() before adding account'
)
assert(
  /AccountPageCoordinator\.SWITCH_LABEL[\s\S]{0,260}\.onClick\(\(\) => \{[\s\S]{0,120}this\.switchAccount\(record\)/.test(managementPage),
  'AccountManagementPage switch action must be attached to an explicit switch control'
)
assert(
  /AccountPageCoordinator\.REMOVE_LABEL[\s\S]{0,260}\.onClick\(\(\) => \{[\s\S]{0,120}this\.confirmRemoveAccount\(record\)/.test(managementPage),
  'AccountManagementPage remove action must be attached to an explicit remove control'
)
assert(
  !/Row\(\)\s*\{[\s\S]*?AccountPageCoordinator\.REMOVE_LABEL[\s\S]*?this\.confirmRemoveAccount\(record\)[\s\S]*?\n\s*\}\s*\n\s*\.width\('100%'\)[\s\S]*?\.onClick\(\(\) => \{[\s\S]*?this\.switchAccount\(record\)/.test(managementPage),
  'AccountManagementPage must not wrap REMOVE_LABEL/confirmRemoveAccount in a row-level switchAccount click target'
)

// ── AccountManagementPage must have per-account remove method ─────
assert(
  managementPage.includes('confirmRemoveAccount'),
  'AccountManagementPage must define confirmRemoveAccount for per-account removal'
)
assert(
  managementPage.includes('performRemoveAccount'),
  'AccountManagementPage must define performRemoveAccount for post-confirmation removal'
)

// ── SettingsBootstrap must restore multi-account ─────────────────
const bootstrap = read('shared/src/main/ets/settings/SettingsBootstrap.ets')
assert(
  bootstrap.includes('AccountSessionCoordinator'),
  'SettingsBootstrap must import AccountSessionCoordinator'
)
assert(
  bootstrap.includes('restoreMultiAccount'),
  'SettingsBootstrap must have restoreMultiAccount method'
)
assert(
  bootstrap.includes('AccountSessionCoordinator.restoreActiveAccount'),
  'SettingsBootstrap must call AccountSessionCoordinator.restoreActiveAccount()'
)
assert(
  bootstrap.includes('AccountStore.migrateFromSingletonIfNeeded'),
  'SettingsBootstrap must call AccountStore.migrateFromSingletonIfNeeded() before restore'
)

// ── Coordinator must call CookieJarSettings for switch ────────────
assert(
  coordinator.includes('CookieJarSettings.saveForBaseUrl'),
  'AccountSessionCoordinator must call CookieJarSettings.saveForBaseUrl() in switchToAccount'
)
assert(
  coordinator.includes('AuthSessionSettings.save'),
  'AccountSessionCoordinator must call AuthSessionSettings.save() in switchToAccount'
)
assert(
  coordinator.includes('CookieJarSettings.restoreCurrentToWebCookieManager'),
  'AccountSessionCoordinator must call CookieJarSettings.restoreCurrentToWebCookieManager() in switchToAccount'
)

// ── Coordinator switchToAccount must set active ID ────────────────
assert(
  coordinator.includes('AccountStore.setActiveId'),
  'AccountSessionCoordinator.switchToAccount must call AccountStore.setActiveId()'
)

// ── Coordinator registerCurrentSession must use CookieJarSettings ─
assert(
  coordinator.includes('CookieJarSettings.getCurrentCookie()'),
  'AccountSessionCoordinator.registerCurrentSession must read cookie via CookieJarSettings.getCurrentCookie()'
)
assert(
  coordinator.includes('CookieJarSettings.credentialScopeKey(baseUrl)') &&
    coordinator.includes('CookieJarSettings.credentialScopeKey(r.baseUrl) === credentialScope'),
  'registerCurrentSession must reuse the same account record across V2EX mirrors by credential scope'
)
assert(
  coordinator.includes('restoreBaseUrlForRecord') &&
    coordinator.includes('selectedScope === recordScope ? selectedBaseUrl : record.baseUrl'),
  'switch/restore must preserve selected V2EX mirror while keeping custom-host accounts exact-scoped'
)
assert(
  !/r\.baseUrl\s*===\s*baseUrl/.test(coordinator),
  'AccountSessionCoordinator must not split the same account by raw V2EX mirror baseUrl'
)

const prepareMatch = coordinator.match(/static\s+async\s+prepareAddAccount[\s\S]*?\n  \}/)
assert(prepareMatch, 'AccountSessionCoordinator.prepareAddAccount body must be present')
assert(
  !prepareMatch[0].includes('CookieJarSettings.clear') && !prepareMatch[0].includes('AuthSessionSettings.clear'),
  'prepareAddAccount must be pending/non-destructive and must not clear cookie/session'
)
assert(
  prepareMatch[0].includes('pending') || prepareMatch[0].includes('preservedActiveId'),
  'prepareAddAccount must document/log pending add-account semantics'
)

// ── No AccountStore references in login pages ────────────────────
// Login pages must go through coordinator, not directly
for (const [label, file] of [
  ['V2exNativeLoginPage', nativeLogin],
  ['V2exWebLoginPage', webLogin],
]) {
  assert(
    !file.includes('AccountStore.add') &&
    !file.includes('AccountStore.setActiveId') &&
    !file.includes('AccountStore.getAll') &&
    !file.includes('AccountStore.remove'),
    `${label} must not call AccountStore directly — use AccountSessionCoordinator`
  )
}

// ── CookieJar + AuthSession must be called AFTER save, not before ─
// Verify that in login pages, registerCurrentSession is called AFTER
// CookieJarSettings.save and AuthSessionSettings.save
for (const [label, file] of [
  ['V2exNativeLoginPage', nativeLogin],
  ['V2exWebLoginPage', webLogin],
]) {
  const cookieSaveIdx = file.indexOf('CookieJarSettings.save')
  const sessionSaveIdx = file.indexOf('AuthSessionSettings.save')
  const registerIdx = file.indexOf('registerCurrentSession')
  assert(
    cookieSaveIdx >= 0 && sessionSaveIdx >= 0 && registerIdx >= 0,
    `${label} must have CookieJarSettings.save, AuthSessionSettings.save, and registerCurrentSession`
  )
  assert(
    cookieSaveIdx < registerIdx,
    `${label}: CookieJarSettings.save must appear before registerCurrentSession`
  )
  assert(
    sessionSaveIdx < registerIdx,
    `${label}: AuthSessionSettings.save must appear before registerCurrentSession`
  )
}

// ── Static analysis: no cookie/token value logging in coordinator ─
assert(
  !/console\..*(cookieSnapshot|tokenSnapshot|cookie\s*=|token\s*=)/i.test(coordinator),
  'AccountSessionCoordinator must not log cookie/token values'
)
assert(
  !/console\..*(CookieJarSettings\.getCurrentCookie|record\.cookieSnapshot)/i.test(coordinator),
  'AccountSessionCoordinator must not log raw cookie snapshots'
)

// ── Account-management strings must be wired to localized resources ──
// The ResourceManager migration retired the AppStrings.R_* string constants; these strings
// are now $r('app.string.account_*')/common_remove resources, consumed via AccountPageCoordinator
// getters and AccountManagementPage. Same intent: the management UI must use localized
// resources (not hardcoded literals). Resource-key existence across all 5 locales is also
// asserted below.
const accCoordinatorStrings = read('entry/src/main/ets/model/AccountPageCoordinator.ets')
const managementPageStrings = read('entry/src/main/ets/pages/AccountManagementPage.ets')
const requiredResourceWirings = [
  ["$r('app.string.account_remove_title')", accCoordinatorStrings, 'AccountPageCoordinator.REMOVE_ACCOUNT_TITLE'],
  ["$r('app.string.account_remove_message_arg')", accCoordinatorStrings, 'AccountPageCoordinator.removeAccountMessage'],
  ["$r('app.string.account_switch_label')", accCoordinatorStrings, 'AccountPageCoordinator.SWITCH_LABEL'],
  ["$r('app.string.account_remove_label')", accCoordinatorStrings, 'AccountPageCoordinator.REMOVE_LABEL'],
  ["$r('app.string.common_remove')", managementPageStrings, 'AccountManagementPage remove confirm'],
]
for (const [resourceRef, source, where] of requiredResourceWirings) {
  assert(
    source.includes(resourceRef),
    `${where} must use localized resource ${resourceRef}`
  )
}

// ── AccountPageCoordinator must expose new constants ─────────────
const accCoordinator = read('entry/src/main/ets/model/AccountPageCoordinator.ets')
const coordinatorTokens = [
  'REMOVE_ACCOUNT_TITLE',
  'removeAccountMessage',
  'SWITCH_LABEL',
  'REMOVE_LABEL',
]
for (const token of coordinatorTokens) {
  assert(
    accCoordinator.includes(token),
    `AccountPageCoordinator missing token: ${token}`
  )
}
assert(
  accCoordinator.includes('activeAccountUsername') && accCoordinator.includes('activeAccountAvatar'),
  'AccountPageCoordinator.identity must accept active AccountStore identity fallback'
)
assert(
  accCoordinator.includes('storedUsername || activeAccountUsername'),
  'AccountPageCoordinator.identity must use active account username after session/profile/stored username'
)
assert(
  accCoordinator.includes('activeAccountAvatar'),
  'AccountPageCoordinator.identity must use active account avatar fallback'
)

// ── All 5 locale files must have new resource keys ───────────────
const newResourceKeys = [
  'account_remove_title',
  'account_remove_message_arg',
  'account_switch_label',
  'account_remove_label',
  'common_remove',
]
const locales = ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW']
for (const locale of locales) {
  const stringsPath = `entry/src/main/resources/${locale}/element/string.json`
  assert(fs.existsSync(path.join(repo, stringsPath)), `Missing resource dir: ${locale}`)
  const text = read(stringsPath)
  for (const key of newResourceKeys) {
    assert(
      text.includes(`"name": "${key}"`),
      `Missing resource key "${key}" in ${locale}/string.json`
    )
  }
  const resourceJson = JSON.parse(text)
  const removeMessage = (resourceJson.string || []).find((item) => item.name === 'account_remove_message_arg')
  assert(removeMessage, `Missing account_remove_message_arg value in ${locale}/string.json`)
  assert(
    String(removeMessage.value).includes('{0}') && !String(removeMessage.value).includes('%s'),
    `account_remove_message_arg in ${locale}/string.json must use {0}, not %s`
  )
}

// ── Debug QA seed must set active account and runtime session ────
const qaSeed = read('shared/src/main/ets/settings/AccountStoreQaSeed.ets')
assert(
  qaSeed.includes('AccountStore.setActiveId') && qaSeed.includes('AuthSessionSettings.save'),
  'AccountStoreQaSeed.seedFakeAccounts must set active ID and save matching AuthSession snapshot'
)
assert(
  qaSeed.includes('restoreActiveId(context)') && qaSeed.includes('records.find'),
  'AccountStoreQaSeed must verify persisted active ID still points at an existing record'
)
assert(
  qaSeed.includes('BuildProfile.DEBUG'),
  'AccountStoreQaSeed must remain debug-only'
)

// ── en_US fallbacks must not contain CJK ─────────────────────────
const enStrings = read('entry/src/main/resources/en_US/element/string.json')
for (const key of newResourceKeys) {
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

console.log('multi-account completion contract ok')
