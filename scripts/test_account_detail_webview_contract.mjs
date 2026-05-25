#!/usr/bin/env node

import { readFileSync } from 'node:fs'

function source(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
}

function fail(message) {
  console.error(`FAIL: ${message}`)
  process.exit(1)
}

function assertIncludes(file, text, needle) {
  if (!text.includes(needle)) {
    fail(`missing contract requirement in ${file}: ${needle}`)
  }
}

function assertNotIncludes(file, text, forbidden) {
  if (text.includes(forbidden)) {
    fail(`forbidden pattern found in ${file}: ${forbidden}`)
  }
}

// Contract 1: AccountSignedInCard.openDetail must NOT push UserProfile directly
const accountPagePath = 'entry/src/main/ets/pages/AccountPage.ets'
const accountPage = source(accountPagePath)

// openDetail must push AccountDetail, not UserProfile
assertIncludes(accountPagePath, accountPage, "pushPathByName('AccountDetail'")
assertNotIncludes(accountPagePath, accountPage, "pushPathByName('UserProfile'")

console.log('PASS: AccountSignedInCard.openDetail routes to AccountDetail, not UserProfile')

// Contract 2: Settings -> Account management route still resolves to AccountManagementPage
const indexPath = 'entry/src/main/ets/pages/Index.ets'
const index = source(indexPath)

// Account family maps to AccountManagementPage
assertIncludes(indexPath, index, "AccountManagementPage()")
assertIncludes(indexPath, index, "AccountDetailPage()")
assertIncludes(indexPath, index, "AccountWebViewPage()")

console.log('PASS: AccountManagementPage preserved, AccountDetailPage and AccountWebViewPage registered')

// Contract 3: AccountWebView uses CookieJarSettings.getCurrentCookie() for cookie injection
const accountWebViewPath = 'entry/src/main/ets/pages/AccountWebViewPage.ets'
const accountWebView = source(accountWebViewPath)
assertIncludes(accountWebViewPath, accountWebView, "CookieJarSettings.getCurrentCookie()")
assertIncludes(accountWebViewPath, accountWebView, "webview.WebCookieManager.configCookie")

console.log('PASS: AccountWebView uses current cookie injection via WebCookieManager')

// Contract 4: No startAbility/external browser for account web actions in AccountDetail
const accountDetailPath = 'entry/src/main/ets/pages/AccountDetailPage.ets'
const accountDetail = source(accountDetailPath)
assertNotIncludes(accountDetailPath, accountDetail, 'startAbility')
assertNotIncludes(accountDetailPath, accountDetail, 'action: viewData')
assertIncludes(accountDetailPath, accountDetail, "pushPathByName('AccountWebView'")

console.log('PASS: AccountDetail uses AccountWebView route, not external browser')

// Contract 5: Coordinator has the required families
const coordinatorPath = 'entry/src/main/ets/model/IndexRouteCoordinator.ets'
const coordinator = source(coordinatorPath)
assertIncludes(coordinatorPath, coordinator, "'AccountDetail': 'accountDetail'")
assertIncludes(coordinatorPath, coordinator, "'AccountWebView': 'accountWebView'")

console.log('PASS: IndexRouteCoordinator registers accountDetail and accountWebView families')

console.log('PASS: all account detail + webview session contracts')
