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

function methodBody(sourceText, signature) {
  const start = sourceText.indexOf(signature)
  assert(start >= 0, `missing method: ${signature}`)
  const brace = sourceText.indexOf('{', start)
  assert(brace >= 0, `missing method body for: ${signature}`)
  let depth = 0
  for (let i = brace; i < sourceText.length; i += 1) {
    const ch = sourceText[i]
    if (ch === '{') {
      depth += 1
    } else if (ch === '}') {
      depth -= 1
      if (depth === 0) {
        return sourceText.slice(start, i + 1)
      }
    }
  }
  throw new Error(`unterminated method body for: ${signature}`)
}

const accountPage = read('entry/src/main/ets/pages/AccountPage.ets')
const canOpen = methodBody(accountPage, 'private canOpenActiveAccountDetail')
assert(
  canOpen.includes('this.hasRestoredActiveAccountIdentity()'),
  'AccountPage canOpenActiveAccountDetail must accept durable restored account/session identity, not only transient activeAccountUsername'
)
assert(
  accountPage.includes('private hasRestoredActiveAccountIdentity(): boolean'),
  'AccountPage must centralize restored active account guard'
)
const restoredGuard = methodBody(accountPage, 'private hasRestoredActiveAccountIdentity')
// Migration complete: guard uses V2 mirror tokens only.
//   this.session.username  (connectAuthSessionSignal())
//   this.activeAccount.id  (connectActiveAccount())
const guardSessionUsername = restoredGuard.includes('this.session.username')
const guardActiveAccountId = restoredGuard.includes('this.activeAccount.id')
assert(
  restoredGuard.includes('this.activeAccountUsername') && guardSessionUsername,
  'restored account guard must accept active account record username or restored AuthSession username'
)
assert(
  guardActiveAccountId && restoredGuard.includes('this.hasCookieAccount()'),
  'restored account guard must still require active account id and configured cookie session'
)
assert(
  !/return\s+!!this\.(activeAccountId|activeAccount\.id)\s*&&\s*!!this\.activeAccountUsername\s*&&\s*this\.hasCookieAccount\(\)/.test(canOpen),
  'AccountPage account-detail guard must not require transient activeAccountUsername alone after restart'
)
assert(
  accountPage.includes('AccountStore.restoreActiveId(context)') && accountPage.includes('AccountStore.getById(context, activeId)'),
  'AccountPage loadAccounts must restore the active AccountStore id and load its record for identity fallback after cold start'
)

const accountStore = read('shared/src/main/ets/settings/AccountStore.ets')
const restoreActiveId = methodBody(accountStore, 'static async restoreActiveId')
// Migration complete: restoreActiveId routes through the single AccountStore.applyActiveAccountId
// chokepoint (republishes to AppStorage AND dual-writes the ActiveAccountState mirror).
const applyActiveId = methodBody(accountStore, 'private static applyActiveAccountId')
assert(
  restoreActiveId.includes('AccountStore.applyActiveAccountId(persisted)'),
  'AccountStore.restoreActiveId must republish persisted active id via applyActiveAccountId so Me page guards are live after relaunch'
)
assert(
  applyActiveId.includes('setAppStorageValue<string>(StorageKeys.ACTIVE_ACCOUNT_ID'),
  'AccountStore.applyActiveAccountId chokepoint must republish the active id to AppStorage'
)

// Migration complete: Index is @ComponentV2 and uses the AuthSessionSignalState mirror path.
const index = read('entry/src/main/ets/pages/Index.ets')
assert(
  index.includes('connectAuthSessionSignal()') && index.includes("@Monitor('authSession.updatedAt')"),
  'Index must watch authSession.updatedAt via @Monitor so login success can refresh visible tab children'
)
// Migration complete: refresh keys use monotonic counter (++), not Date.now() key-churn.
const indexAuthHandler = methodBody(index, 'onAuthSessionUpdated(): void')
assert(
  indexAuthHandler.includes('this.notificationRefreshKey++') &&
    indexAuthHandler.includes('this.accountRefreshKey++'),
  'Index auth-session watcher must refresh notification/account child props after normal login success'
)
assert(
  indexAuthHandler.includes('this.refreshNotificationBadge()'),
  'Index auth-session watcher must refresh notification badge after login success'
)

const nativeLogin = read('entry/src/main/ets/pages/V2exNativeLoginPage.ets')
assert(
  nativeLogin.indexOf('await AuthSessionSettings.save') >= 0 &&
    nativeLogin.indexOf('await AuthSessionSettings.save') < nativeLogin.indexOf('await AccountSessionCoordinator.registerCurrentSession'),
  'native login must publish AuthSessionSettings before registering active AccountStore session'
)
assert(
  nativeLogin.includes('await AccountSessionCoordinator.registerCurrentSession'),
  'native login success must register/switch active AccountStore record'
)

const webLogin = read('entry/src/main/ets/pages/V2exWebLoginPage.ets')
assert(
  webLogin.indexOf('await AuthSessionSettings.save') >= 0 &&
    webLogin.indexOf('await AuthSessionSettings.save') < webLogin.indexOf('await AccountSessionCoordinator.registerCurrentSession'),
  'web login must publish AuthSessionSettings before registering active AccountStore session'
)
assert(
  webLogin.includes('await AccountSessionCoordinator.registerCurrentSession'),
  'web login success must register/switch active AccountStore record'
)

const twoFactor = read('entry/src/main/ets/components/V2exTwoFactorPrompt.ets')
assert(
  twoFactor.includes('AccountSessionCoordinator'),
  'global 2FA login completion must import/use AccountSessionCoordinator'
)
assert(
  twoFactor.indexOf('await AuthSessionSettings.save') >= 0 &&
    twoFactor.indexOf('await AuthSessionSettings.save') < twoFactor.indexOf('await AccountSessionCoordinator.registerCurrentSession'),
  'global 2FA login completion must publish AuthSessionSettings before registering active AccountStore session'
)
assert(
  twoFactor.includes('await AccountSessionCoordinator.registerCurrentSession'),
  'global 2FA login completion must register/switch active AccountStore record'
)

const notificationPage = read('entry/src/main/ets/pages/NotificationPage.ets')
const notificationAuthContext = methodBody(notificationPage, 'private notificationAuthContext')
// Migration complete: NotificationPage uses the V2 authCookie mirror (connectAuthCookie(),
// dual-written at CookieJarSettings.refreshConfiguredState).
assert(
  notificationAuthContext.includes('cookieConfigured: this.authCookie.configured || cookie.length > 0'),
  'NotificationPage auth context must include the reactive authCookie.configured source so login-required UI leaves logged-out state after login'
)
assert(
  !notificationPage.includes('NotificationSummaryCard({'),
  'NotificationPage must not reintroduce notification summary UI while fixing refresh behavior'
)

console.log('auth restore notification refresh contract ok')
