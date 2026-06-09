#!/usr/bin/env node
/**
 * V2EX domain selection contract.
 *
 * Verifies that V2EX site configuration is string/baseUrl based, shares auth
 * across V2EX-owned mirrors only, exposes preset/custom settings UI, and keeps
 * proxy tests using the selected base URL.
 */
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const read = (rel) => fs.readFileSync(path.join(repo, rel), 'utf8')
const exists = (rel) => fs.existsSync(path.join(repo, rel))
const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}

const apiConstants = read('shared/src/main/ets/constants/ApiConstants.ets')
const apiDomain = read('shared/src/main/ets/settings/ApiDomainSettings.ets')
const cookieJar = read('shared/src/main/ets/settings/CookieJarSettings.ets')
const storageKeys = read('shared/src/main/ets/constants/StorageKeys.ets')
const httpClient = read('shared/src/main/ets/network/HttpClient.ets')
const settingsPage = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
const settingsSave = read('feature/settings/src/main/ets/model/SettingsSaveCoordinator.ets')
const networkProxyPage = read('feature/settings/src/main/ets/pages/NetworkProxySettingsPage.ets')
const accountSession = read('shared/src/main/ets/settings/AccountSessionCoordinator.ets')
const imageUtils = read('shared/src/main/ets/utils/ImageUtils.ets')
const apiService = read('shared/src/main/ets/network/ApiService.ets')
const apiV2Service = read('shared/src/main/ets/network/ApiV2Service.ets')
const v2exUrlRouter = read('shared/src/main/ets/utils/V2exUrlRouter.ets')
const topicDetailPage = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
const webLoginPage = read('entry/src/main/ets/pages/V2exWebLoginPage.ets')
const accountDetailPage = read('entry/src/main/ets/pages/AccountDetailPage.ets')
const accountWebViewPage = read('entry/src/main/ets/pages/AccountWebViewPage.ets')
const sharedIndex = read('shared/src/main/ets/Index.ets')
const settingsIndex = read('feature/settings/src/main/ets/Index.ets')
const entryIndex = read('entry/src/main/ets/pages/Index.ets')
const routeCoordinator = read('entry/src/main/ets/model/IndexRouteCoordinator.ets')
const resourceStrings = [
  'entry/src/main/resources/base/element/string.json',
  'entry/src/main/resources/en_US/element/string.json',
  'entry/src/main/resources/zh_CN/element/string.json',
  'entry/src/main/resources/zh_HK/element/string.json',
  'entry/src/main/resources/zh_TW/element/string.json',
].map(read).join('\n')

assert(apiConstants.includes('PRESET_DOMAINS'), 'ApiConstants must define PRESET_DOMAINS')
for (const host of ['www', 'edge', 'global', 'fast', 'cn', 'us', 'jp', 'hk']) {
  assert(apiConstants.includes(`https://${host}.v2ex.com`), `PRESET_DOMAINS must include ${host}.v2ex.com`)
}
assert(!/PRESET_DOMAINS[\s\S]*https:\/\/origin\.v2ex\.com/.test(apiConstants), 'origin.v2ex.com must not be a preset')
assert(!/PRESET_DOMAINS[\s\S]*https:\/\/s\.v2ex\.com/.test(apiConstants), 's.v2ex.com must not be a preset')

assert(storageKeys.includes('SELECTED_BASE_URL'), 'StorageKeys must include SELECTED_BASE_URL')
assert(apiDomain.includes('SELECTED_BASE_URL'), 'ApiDomainSettings must persist selected baseUrl')
assert(apiDomain.includes('normalizeBaseUrl'), 'ApiDomainSettings must expose normalizeBaseUrl')
assert(apiDomain.includes('migrateFromUseCoDomain'), 'ApiDomainSettings must migrate old useCoDomain')
assert(apiDomain.includes('v2ex.co has been DNS-dead'), 'ApiDomainSettings must document v2ex.co migration rationale')
assert(!/static\s+apply\s*\(\s*useCoDomain:\s*boolean/.test(apiDomain), 'ApiDomainSettings.apply must no longer be boolean-only')
assert(apiDomain.includes('ApiConstants.BASE_URL_COM'), 'ApiDomainSettings must fallback to www.v2ex.com')

assert(cookieJar.includes('cookiesByBaseUrl'), 'CookieJarSettings must persist cookiesByBaseUrl map')
assert(cookieJar.includes('Record<string, string>') || cookieJar.includes('Map<string, string>'), 'CookieJarSettings must represent cookies by baseUrl')
assert(cookieJar.includes('credentialScopeKey'), 'CookieJarSettings must derive a durable credential scope key')
assert(cookieJar.includes('isV2exOwnedHost'), 'CookieJarSettings must identify V2EX-owned hosts for shared auth scope')
assert(cookieJar.includes("return 'v2ex.com'"), 'V2EX-owned domains must share the v2ex.com credential scope')
assert(cookieJar.includes('custom/non-V2EX hosts stay exact-baseUrl scoped'), 'CookieJarSettings must document the custom-host safety boundary')
assert(!cookieJar.includes('not shared across domains'), 'CookieJarSettings must remove the stale exact-domain-only rationale')
assert(/getCookieForBaseUrl[\s\S]*credentialScopeKey\(baseUrl\)[\s\S]*cookiesByBaseUrl\[scopeKey\]/.test(cookieJar), 'getCookieForBaseUrl must look up by credential scope, not raw baseUrl only')
assert(cookieJar.includes('findCompatibleCookieForScope') && cookieJar.includes('cookie_scope_compat_lookup'), 'CookieJarSettings must bridge stale exact-domain runtime cookies into the shared V2EX scope with diagnostics')
assert(/findCompatibleCookieForScope[\s\S]*credentialScopeKey\(key\)[\s\S]*normalized\s*===\s*normalizedScope/.test(cookieJar), 'CookieJarSettings compatible lookup must compare normalized credential scopes for runtime split regression')
assert(/saveForBaseUrl[\s\S]*credentialScopeKey\(baseUrl\)[\s\S]*cookiesByBaseUrl\[scopeKey\]/.test(cookieJar), 'saveForBaseUrl must store V2EX cookies under the shared credential scope')
assert(/host\s*===\s*'v2ex\.com'\s*\|\|\s*host\.endsWith\('\.v2ex\.com'\)/.test(cookieJar), 'V2EX-owned scope must be limited to v2ex.com and subdomains')
assert(!cookieJar.includes("return 'v2ex.com'") || cookieJar.includes('return normalized'), 'Non-V2EX custom hosts must keep an exact normalized scope')
assert(cookieJar.includes('JSON.parse') && cookieJar.includes('JSON.stringify'), 'CookieJarSettings must serialize cookie map')
assert(cookieJar.includes('credentialScopeKey(ApiConstants.BASE_URL_CO)') && cookieJar.includes('= coCookie'), 'CookieJarSettings must preserve legacy coCookie ownership during migration')
assert(cookieJar.includes('didMigrateFromLegacyCoDomain()') && cookieJar.includes('credentialScopeKey(ApiConstants.BASE_URL_COM)') && cookieJar.includes('= coCookie'), 'CookieJarSettings must keep active co-domain users logged in after fallback to www')
assert(!/baseUrl\s*===\s*ApiConstants\.BASE_URL_CO\s*\?/.test(cookieJar), 'CookieJarSettings must not branch binary com/co for lookup')

assert(httpClient.includes('Base URL is a request/web origin preference') && httpClient.includes('shared V2EX first-party scope'), 'HttpClient.setBaseUrl must document selected origin vs credential scope')
assert(settingsSave.includes('applyApiDomainSideEffects') && !settingsSave.includes('useCoDomain: boolean'), 'SettingsSaveCoordinator must accept baseUrl side effects, not boolean')
assert(settingsSave.includes('restoreCurrentToWebCookieManager'), 'Domain side-effects must restore WebCookieManager for selected baseUrl')

assert(exists('feature/settings/src/main/ets/model/DomainSettingsCoordinator.ets'), 'DomainSettingsCoordinator.ets must exist')
assert(exists('feature/settings/src/main/ets/pages/DomainSettingsPage.ets'), 'DomainSettingsPage.ets must exist')
const domainCoordinator = read('feature/settings/src/main/ets/model/DomainSettingsCoordinator.ets')
const domainPage = read('feature/settings/src/main/ets/pages/DomainSettingsPage.ets')
assert(domainCoordinator.includes('validateCustomDomain'), 'DomainSettingsCoordinator must validate custom domains')
assert(domainCoordinator.includes('/api/site/info.json'), 'Custom validation must probe /api/site/info.json')
assert(domainCoordinator.includes('https') && domainCoordinator.includes('v2ex.com'), 'Custom validation must require HTTPS and V2EX identity')
assert(domainPage.includes("$r('app.string.custom_domain')"), 'DomainSettingsPage must expose custom site domain UI')
assert(domainPage.includes('Radio'), 'DomainSettingsPage must expose radio selection for presets')
assert(domainPage.includes('validateCustomDomain'), 'DomainSettingsPage must wire validation action')
assert(domainPage.includes("$r('app.string.domain_session_hint')") && resourceStrings.includes('domain_session_hint'), 'DomainSettingsPage must explain shared first-party auth and exact custom-host sessions')
assert(!domainPage.includes('需要重新登录') && !domainPage.includes('按需重新登录'), 'DomainSettingsPage must not warn that V2EX mirror switching requires relogin')
assert(settingsPage.includes("pushPathByName('DomainSettings'"), 'SettingsPage site domain row must navigate to DomainSettings')
assert(!settingsPage.includes('apiDomainMenuShown'), 'SettingsPage must remove old boolean site domain dropdown menu')

assert(sharedIndex.includes('ApiDomainOption') && sharedIndex.includes('DomainValidationResult'), 'shared Index must export domain selection types')
assert(settingsIndex.includes('DomainSettingsPage'), 'settings Index must export DomainSettingsPage')
assert(entryIndex.includes('DomainSettingsPage'), 'entry Index must import/render DomainSettingsPage')
assert(routeCoordinator.includes("'DomainSettings': 'domainSettings'"), 'IndexRouteCoordinator must register DomainSettings route')
assert(routeCoordinator.includes("'domainSettings': $r('app.string.api_domain')"), 'DomainSettings route title must use site domain title resource')

for (const [name, content] of [
  ['DomainSettingsPage', domainPage],
  ['resource strings', resourceStrings],
]) {
  assert(!/API\s+domain|API\s+域名|API\s+網域/i.test(content), `${name} must not expose API-only domain wording`)
}

assert(networkProxyPage.includes('NetworkProxyRequest.testConnection(HttpClient.getInstance().getBaseUrl())'), 'Proxy connection test must use selected HttpClient baseUrl')
assert(accountSession.includes('restoreBaseUrlForRecord'), 'AccountSessionCoordinator must preserve selected V2EX mirror when restoring same-scope accounts')
assert(accountSession.includes('CookieJarSettings.credentialScopeKey(r.baseUrl) === credentialScope'), 'AccountSessionCoordinator.registerCurrentSession must match accounts by shared credential scope')
assert(!/r\.baseUrl\s*===\s*baseUrl/.test(accountSession), 'AccountSessionCoordinator must not split V2EX account identity by raw mirror baseUrl')
assert(!accountSession.includes('HttpClient.getInstance().setBaseUrl(record.baseUrl)'), 'AccountSessionCoordinator must not always force selected V2EX site back to login-time baseUrl')
assert(imageUtils.includes('HttpClient.getInstance().getBaseUrl()'), 'ImageUtils fallback must use current baseUrl')

assert(v2exUrlRouter.includes('withSelectedBaseUrl'), 'V2exUrlRouter must expose selected-baseUrl URL rewriting')
assert(v2exUrlRouter.includes('isFirstPartySiteUrl'), 'V2exUrlRouter must identify first-party V2EX site URLs')
assert(v2exUrlRouter.includes('normalizeFirstPartyPath'), 'V2exUrlRouter must keep site-path rewriting away from image/CDN URLs')
for (const [name, content] of [
  ['ApiService', apiService],
  ['ApiV2Service', apiV2Service],
]) {
  assert(content.includes('V2exUrlRouter.withSelectedBaseUrl'), `${name} must rewrite API topic/node URLs to selected baseUrl`)
  assert(/topic\.url\s*=\s*V2exUrlRouter\.withSelectedBaseUrl/.test(content), `${name} must normalize topic.url instead of preserving canonical www payload URLs`)
  assert(/topic\.node\.url\s*=\s*V2exUrlRouter\.withSelectedBaseUrl/.test(content) || /node\.url\s*=\s*V2exUrlRouter\.withSelectedBaseUrl/.test(content), `${name} must normalize node.url instead of preserving canonical www payload URLs`)
}
assert(topicDetailPage.includes('V2exUrlRouter.withSelectedBaseUrl'), 'TopicDetailPage share/open URL must resolve model URLs through selected baseUrl')
assert(!/return\s+raw\s*\n/.test(topicDetailPage), 'TopicDetailPage must not return absolute API payload topic.url unchanged')
assert(webLoginPage.includes('HttpClient.getInstance().getBaseUrl()') || webLoginPage.includes('this.http.getBaseUrl()'), 'V2exWebLoginPage must start from selected baseUrl')
assert(accountDetailPage.includes("this.webBaseUrl() + '/balance'") && accountDetailPage.includes("this.webBaseUrl() + '/settings'"), 'Account detail first-party web entries must use selected baseUrl')
assert(accountWebViewPage.includes('normalizeFirstPartyTargetUrl'), 'AccountWebViewPage must normalize stored first-party targets to selected baseUrl')
assert(accountWebViewPage.includes('V2exUrlRouter.isFirstPartySiteUrl'), 'AccountWebViewPage must allow first-party V2EX URLs via shared resolver, not a hardcoded www-only list')
assert(accountWebViewPage.includes('this.injectCookie(cookie, this.webBaseUrl())'), 'AccountWebViewPage must inject selected-baseUrl cookies, not cookies scoped to stale target URL')

const firstPartySourceRoots = [
  'shared/src/main/ets',
  'entry/src/main/ets',
  'feature/settings/src/main/ets',
  'feature/detail/src/main/ets',
]
const hardcodedSiteUrlAllowList = new Set([
  'shared/src/main/ets/constants/ApiConstants.ets',
  'shared/src/main/ets/settings/ApiDomainSettings.ets',
  'shared/src/main/ets/backup/BackupPreferencesAdapter.ets',
  'shared/src/main/ets/settings/CacheDeviceQaSeed.ets',
  'shared/src/main/ets/settings/AccountStoreQaSeed.ets',
  'shared/src/main/ets/settings/SettingsBootstrap.ets',
  'shared/src/main/ets/settings/CookieJarSettings.ets',
  'shared/src/main/ets/utils/MediaUrlUtils.ets',
  'shared/src/main/ets/utils/V2exUrlRouter.ets',
  'entry/src/main/ets/model/SearchPageStateCoordinator.ets',
  'feature/settings/src/main/ets/pages/DomainSettingsPage.ets',
])
const walk = (relDir) => {
  const abs = path.join(repo, relDir)
  const out = []
  for (const entry of fs.readdirSync(abs, { withFileTypes: true })) {
    const rel = path.join(relDir, entry.name)
    if (entry.isDirectory()) out.push(...walk(rel))
    if (entry.isFile() && entry.name.endsWith('.ets')) out.push(rel)
  }
  return out
}
for (const rel of firstPartySourceRoots.flatMap(walk)) {
  if (hardcodedSiteUrlAllowList.has(rel)) continue
  const content = read(rel)
  assert(!/https:\/\/(?:www\.)?v2ex\.(?:com|co)(?:[/'"`]|$)/.test(content), `${rel} must not hardcode first-party V2EX site URLs; use HttpClient.getInstance().getBaseUrl() or V2exUrlRouter`)
}

console.log('V2EX domain selection contract PASS')
