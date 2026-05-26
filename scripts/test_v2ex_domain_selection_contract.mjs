#!/usr/bin/env node
/**
 * V2EX domain selection contract.
 *
 * Verifies that V2EX site configuration is string/baseUrl based, preserves
 * cookie ownership per exact baseUrl, exposes preset/custom settings UI, and
 * keeps proxy tests using the selected base URL.
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
const sharedIndex = read('shared/src/main/ets/Index.ets')
const settingsIndex = read('feature/settings/src/main/ets/Index.ets')
const entryIndex = read('entry/src/main/ets/pages/Index.ets')
const routeCoordinator = read('entry/src/main/ets/model/IndexRouteCoordinator.ets')
const stringMap = read('shared/src/main/ets/i18n/StringMap.ets')
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
assert(cookieJar.includes('not shared across domains'), 'CookieJarSettings must document no silent cookie sharing')
assert(cookieJar.includes('JSON.parse') && cookieJar.includes('JSON.stringify'), 'CookieJarSettings must serialize cookie map')
assert(cookieJar.includes('migrated[ApiConstants.BASE_URL_CO] = coCookie'), 'CookieJarSettings must preserve legacy coCookie ownership during migration')
assert(cookieJar.includes('didMigrateFromLegacyCoDomain()') && cookieJar.includes('migrated[ApiConstants.BASE_URL_COM] = coCookie'), 'CookieJarSettings must keep active co-domain users logged in after fallback to www')
assert(!/baseUrl\s*===\s*ApiConstants\.BASE_URL_CO\s*\?/.test(cookieJar), 'CookieJarSettings must not branch binary com/co for lookup')

assert(httpClient.includes('Base URL changes do NOT automatically preserve or migrate cookies'), 'HttpClient.setBaseUrl must document cookie namespace invariant')
assert(settingsSave.includes('applyApiDomainSideEffects') && !settingsSave.includes('useCoDomain: boolean'), 'SettingsSaveCoordinator must accept baseUrl side effects, not boolean')
assert(settingsSave.includes('restoreCurrentToWebCookieManager'), 'Domain side-effects must restore WebCookieManager for selected baseUrl')

assert(exists('feature/settings/src/main/ets/model/DomainSettingsCoordinator.ets'), 'DomainSettingsCoordinator.ets must exist')
assert(exists('feature/settings/src/main/ets/pages/DomainSettingsPage.ets'), 'DomainSettingsPage.ets must exist')
const domainCoordinator = read('feature/settings/src/main/ets/model/DomainSettingsCoordinator.ets')
const domainPage = read('feature/settings/src/main/ets/pages/DomainSettingsPage.ets')
assert(domainCoordinator.includes('validateCustomDomain'), 'DomainSettingsCoordinator must validate custom domains')
assert(domainCoordinator.includes('/api/site/info.json'), 'Custom validation must probe /api/site/info.json')
assert(domainCoordinator.includes('https') && domainCoordinator.includes('v2ex.com'), 'Custom validation must require HTTPS and V2EX identity')
assert(domainPage.includes('Custom site domain') || domainPage.includes('自定义站点域名'), 'DomainSettingsPage must expose custom site domain UI')
assert(domainPage.includes('Radio'), 'DomainSettingsPage must expose radio selection for presets')
assert(domainPage.includes('validateCustomDomain'), 'DomainSettingsPage must wire validation action')
assert(settingsPage.includes("pushPathByName('DomainSettings'"), 'SettingsPage site domain row must navigate to DomainSettings')
assert(!settingsPage.includes('apiDomainMenuShown'), 'SettingsPage must remove old boolean site domain dropdown menu')

assert(sharedIndex.includes('ApiDomainOption') && sharedIndex.includes('DomainValidationResult'), 'shared Index must export domain selection types')
assert(settingsIndex.includes('DomainSettingsPage'), 'settings Index must export DomainSettingsPage')
assert(entryIndex.includes('DomainSettingsPage'), 'entry Index must import/render DomainSettingsPage')
assert(routeCoordinator.includes("'DomainSettings': 'domainSettings'"), 'IndexRouteCoordinator must register DomainSettings route')
assert(routeCoordinator.includes('R_API_DOMAIN'), 'DomainSettings route title must use site domain title resource')

for (const [name, content] of [
  ['DomainSettingsPage', domainPage],
  ['StringMap', stringMap],
  ['resource strings', resourceStrings],
]) {
  assert(!/API\s+domain|API\s+域名|API\s+網域/i.test(content), `${name} must not expose API-only domain wording`)
}

assert(networkProxyPage.includes('NetworkProxyRequest.testConnection(HttpClient.getInstance().getBaseUrl())'), 'Proxy connection test must use selected HttpClient baseUrl')
assert(accountSession.includes('HttpClient.getInstance().setBaseUrl(record.baseUrl)'), 'AccountSessionCoordinator.switch/restore must apply account baseUrl before cookie save')
assert(imageUtils.includes('HttpClient.getInstance().getBaseUrl()'), 'ImageUtils fallback must use current baseUrl')

console.log('V2EX domain selection contract PASS')
