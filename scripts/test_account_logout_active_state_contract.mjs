#!/usr/bin/env node

import { readFileSync } from 'node:fs'

function source(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
}

function fail(message) {
  console.error(`FAIL: ${message}`)
  process.exit(1)
}

function assert(condition, message) {
  if (!condition) {
    fail(message)
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
  fail(`unterminated method body for: ${signature}`)
}

const detailPath = 'entry/src/main/ets/pages/AccountDetailPage.ets'
const detail = source(detailPath)
const accountPagePath = 'entry/src/main/ets/pages/AccountPage.ets'
const accountPage = source(accountPagePath)
const coordinatorPath = 'shared/src/main/ets/settings/AccountSessionCoordinator.ets'
const coordinator = source(coordinatorPath)

const performLogout = methodBody(detail, 'private performLogout')
assert(
  detail.includes('AccountSessionCoordinator'),
  'AccountDetailPage must import/use AccountSessionCoordinator for logout'
)
assert(
  /AccountSessionCoordinator\.(removeActiveAccount|logoutActiveAccount|removeAccount)\s*\(/.test(performLogout),
  'AccountDetailPage.performLogout must delegate to the central account-session coordinator'
)
assert(
  !performLogout.includes('CookieJarSettings.clearForBaseUrl') && !performLogout.includes('AuthSessionSettings.clear'),
  'AccountDetailPage.performLogout must not locally clear only cookie/session without AccountStore active-account handling'
)
assert(
  /this\.(storedUsername|sessionUsername|sessionAvatar)\s*=\s*''/.test(performLogout),
  'AccountDetailPage.performLogout must clear local identity state before/while popping'
)

assert(
  /static\s+async\s+(removeActiveAccount|logoutActiveAccount)\s*\(/.test(coordinator),
  'AccountSessionCoordinator must expose a central active-account logout/removal method'
)
const activeLogout = methodBody(
  coordinator,
  coordinator.includes('static async removeActiveAccount') ? 'static async removeActiveAccount' : 'static async logoutActiveAccount'
)
assert(
  activeLogout.includes('AccountStore.restoreActiveId') && activeLogout.includes('AccountStore.getActiveId'),
  'central active logout must restore/read active account id before removal'
)
assert(
  activeLogout.includes('AccountSessionCoordinator.removeAccount') || activeLogout.includes('removeAccount(context'),
  'central active logout must remove the active account through removeAccount fallback logic'
)
assert(
  coordinator.includes('remaining.length > 0') && coordinator.includes('switchToAccount(context, fallback)'),
  'AccountSessionCoordinator.removeAccount must switch to a remaining fallback account when active account is removed'
)
assert(
  coordinator.includes('CookieJarSettings.clear(context)') && coordinator.includes('AuthSessionSettings.clear(context)'),
  'AccountSessionCoordinator.removeAccount must clear runtime cookie/session when no accounts remain'
)
assert(
  coordinator.includes('AccountStore.setActiveId(context, \'\')') || coordinator.includes('AccountStore.clearActiveId'),
  'no-account logout path must centrally clear active account id'
)

assert(
  accountPage.includes('canOpenActiveAccountDetail') || accountPage.includes('hasActiveAccountIdentity'),
  'AccountPage account-card openDetail must use a named non-empty active identity guard'
)
const openDetailMatch = accountPage.match(/openDetail:\s*\(\)\s*=>\s*\{([\s\S]*?)\n\s*\}/)
assert(openDetailMatch, 'AccountPage must define AccountSignedInCard.openDetail handler')
assert(
  !/pushPathByName\('UserProfile'/.test(openDetailMatch[1]),
  'AccountPage account-card openDetail must not push UserProfile'
)
assert(
  /if\s*\(this\.(canOpenActiveAccountDetail|hasActiveAccountIdentity)\(\)\)/.test(openDetailMatch[1]),
  'AccountPage openDetail must guard AccountDetail navigation with real active identity state'
)

assert(!detail.includes("Text('›')"), 'AccountDetailPage must not reintroduce handwritten chevron rows')
assert(/showChevron:\s*false/.test(detail), 'LogoutRow must keep showChevron: false')

console.log('PASS: account logout active-state contract')
