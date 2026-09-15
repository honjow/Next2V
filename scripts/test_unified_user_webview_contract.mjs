#!/usr/bin/env node
import fs from 'node:fs'

function read(path) {
  return fs.readFileSync(path, 'utf8')
}

function assert(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`)
    process.exit(1)
  }
}

function assertIncludes(name, text, needle) {
  assert(text.includes(needle), `${name} must include ${needle}`)
}

function assertNotIncludes(name, text, needle) {
  assert(!text.includes(needle), `${name} must not include ${needle}`)
}

const webView = read('shared/src/main/ets/components/V2exWebView.ets')
const sharedIndex = read('shared/src/main/ets/Index.ets')
const entryAbility = read('entry/src/main/ets/entryability/EntryAbility.ets')
const webLogin = read('entry/src/main/ets/pages/V2exWebLoginPage.ets')
const accountWebView = read('entry/src/main/ets/pages/AccountWebViewPage.ets')
const cookieJar = read('shared/src/main/ets/settings/CookieJarSettings.ets')
const dailyCheckinRunner = read('entry/src/main/ets/components/DailyCheckinWebRunner.ets')

assertIncludes('shared V2exWebView', webView, "Web({ src: '', controller: this.controller })")
for (const commonConfig of [
  '.darkMode(WebDarkMode.Off)',
  '.backgroundColor(Color.White)',
  '.javaScriptAccess(true)',
  '.domStorageAccess(true)',
  '.onlineImageAccess(true)',
  ".width('100%')",
  ".height('100%')",
  '.onControllerAttached(',
  '.onPageBegin(',
  '.onPageEnd(',
  '.onLoadFinished(',
  '.onErrorReceive(',
  ".height('100%')",
  '.clip(false)'
]) {
  assertIncludes('shared V2exWebView common config', webView, commonConfig)
}
assertIncludes('shared barrel export', sharedIndex, "export { V2exWebView } from './components/V2exWebView'")
assertIncludes('EntryAbility WebCookieManager policy', entryAbility, 'webview.WebCookieManager.putAcceptCookieEnabled(true)')
assertIncludes('EntryAbility third-party WebCookieManager policy', entryAbility, 'webview.WebCookieManager.putAcceptThirdPartyCookieEnabled(true)')

for (const [name, text] of [
  ['V2exWebLoginPage', webLogin],
  ['AccountWebViewPage', accountWebView]
]) {
  assertIncludes(name, text, 'V2exWebView,')
  assertIncludes(name, text, 'V2exWebView({')
  assertNotIncludes(name, text, "Web({ src: '', controller: this.controller })")
  assertNotIncludes(name, text, '.darkMode(WebDarkMode.Off)')
  assertNotIncludes(name, text, '.javaScriptAccess(true)')
}

assertIncludes('V2exWebLoginPage scaffold', webLogin, 'V2exWebViewScaffold({')
assertIncludes('V2exWebLoginPage status max lines', webLogin, 'statusMaxLines: 1')
assertIncludes('V2exWebLoginPage cookie clear', webLogin, 'CookieJarSettings.clearWebCookiesForBaseUrl(this.baseUrl)')
assertIncludes('V2exWebLoginPage cookie isolation begin', webLogin, 'CookieJarSettings.beginWebLoginCookieIsolation()')
assertIncludes('V2exWebLoginPage cookie isolation end', webLogin, 'CookieJarSettings.endWebLoginCookieIsolation()')
assertIncludes('V2exWebLoginPage auto-save begin', webLogin, 'this.scheduleAutoSave()')
assertIncludes('V2exWebLoginPage auto-save transition guard', webLogin, 'this.isLoginTransitionUrl()')
assertIncludes('V2exWebLoginPage sign-in transition guard', webLogin, "path === '/signin'")
assertIncludes('V2exWebLoginPage 2FA transition guard', webLogin, "path === '/2fa'")
assertNotIncludes('V2exWebLoginPage PB3 auth cookie heuristic', webLogin, "names.indexOf('PB3_SESSION') >= 0")
assertIncludes('V2exWebLoginPage lastUrl tracking', webLogin, 'this.lastUrl = event.url')
assertIncludes('V2exWebLoginPage load finished callback', webLogin, 'onLoadFinished: (event?: PageEndEvent)')
assertIncludes('CookieJarSettings web login isolation state', cookieJar, 'webLoginCookieIsolationActive')
assertIncludes('CookieJarSettings isolation restore guard', cookieJar, 'if (CookieJarSettings.webLoginCookieIsolationActive)')
assertIncludes('DailyCheckinWebRunner isolation start guard', dailyCheckinRunner, 'CookieJarSettings.isWebLoginCookieIsolationActive()')

assertIncludes('AccountWebViewPage scaffold', accountWebView, 'V2exWebViewScaffold({')
assertIncludes('AccountWebViewPage status max lines', accountWebView, 'statusMaxLines: 2')
assertNotIncludes('AccountWebViewPage old local status builder', accountWebView, 'StatusBar()')
assertNotIncludes('AccountWebViewPage obsolete scaffold import', accountWebView, 'SecondaryListScaffold')
assertNotIncludes('AccountWebViewPage obsolete theme import', accountWebView, 'ThemeConstants')
assertIncludes('AccountWebViewPage current cookie required', accountWebView, 'CookieJarSettings.getCurrentCookie()')
// AccountWebViewPage is the generalized in-app WebView (account pages, topic "open in app",
// node-description links) and intentionally accepts any http(s) URL, first-party OR external.
// The session-cookie-leak guard is the real first-party invariant: the V2EX cookie is fetched
// ONLY for the selected V2EX origin and is the empty string for external sites.
assertIncludes('AccountWebViewPage first-party cookie guard', accountWebView, 'const isV2exOrigin = origin.length > 0 && target.startsWith(origin)')
assertIncludes('AccountWebViewPage external sites get no cookie', accountWebView, "const cookie = isV2exOrigin ? CookieJarSettings.getCurrentCookie() : ''")
assertIncludes('AccountWebViewPage resolved target load', accountWebView, 'this.controller.loadUrl(url)')
assertIncludes('AccountWebViewPage reload action', accountWebView, 'this.controller.refresh()')

console.log('PASS: unified user/account WebView contract')
