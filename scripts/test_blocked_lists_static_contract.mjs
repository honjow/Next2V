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
    fail(`missing static contract in ${file}: ${needle}`)
  }
}

const parserPath = 'shared/src/main/ets/parser/V2exTabParser.ets'
const settingsPath = 'shared/src/main/ets/settings/BlockedListSettings.ets'
const apiPath = 'shared/src/main/ets/network/ApiService.ets'
const pagePath = 'entry/src/main/ets/pages/BlockedListsPage.ets'
const routePath = 'entry/src/main/ets/model/IndexRouteCoordinator.ets'
const settingsPagePath = 'feature/settings/src/main/ets/pages/SettingsPage.ets'
const accountPagePath = 'entry/src/main/ets/pages/AccountPage.ets'
const indexPath = 'entry/src/main/ets/pages/Index.ets'
const titleBarComponentsPath = 'entry/src/main/ets/components/IndexTitleBarComponents.ets'
const storageKeysPath = 'shared/src/main/ets/constants/StorageKeys.ets'
const appStringsPath = 'shared/src/main/ets/i18n/AppStrings.ets'
const accountSessionCoordinatorPath = 'shared/src/main/ets/settings/AccountSessionCoordinator.ets'

const parser = source(parserPath)
const settings = source(settingsPath)
const api = source(apiPath)
const page = source(pagePath)
const route = source(routePath)
const settingsPage = source(settingsPagePath)
const accountPage = source(accountPagePath)
const index = source(indexPath)
const titleBarComponents = source(titleBarComponentsPath)
const storageKeys = source(storageKeysPath)
const appStrings = source(appStringsPath)
const accountSessionCoordinator = source(accountSessionCoordinatorPath)

assertIncludes(parserPath, parser, 'export interface V2exBlockedIdLists')
assertIncludes(parserPath, parser, 'static extractBlockedIdLists(html: string): V2exBlockedIdLists')
assertIncludes(parserPath, parser, 'ignoredTopicsPresent: boolean')
assertIncludes(parserPath, parser, 'blockedMembersPresent: boolean')
assertIncludes(parserPath, parser, 'ignoredRawLength: number')
assertIncludes(parserPath, parser, 'blockedRawLength: number')
assertIncludes(parserPath, parser, "extractJsNumberArray(html || '', 'ignored_topics')")
assertIncludes(parserPath, parser, "extractJsNumberArray(html || '', 'blocked')")
assertIncludes(parserPath, parser, 'const pattern = new RegExp')
assertIncludes(parserPath, parser, 'seen: Set<number>')

assertIncludes(settingsPath, settings, 'const KEY_PREFIX: string = \'blockedListState:\'')
assertIncludes(settingsPath, settings, 'static activeOwnerKey(): string')
assertIncludes(settingsPath, settings, 'StorageKeys.ACTIVE_ACCOUNT_ID')
assertIncludes(settingsPath, settings, 'export interface BlockedListCaptureSource')
assertIncludes(settingsPath, settings, 'static updateFromTopicListHtml(html: string, source: BlockedListCaptureSource = {}): boolean')
assertIncludes(settingsPath, settings, 'static runtimeSnapshot(): BlockedListSnapshot')
assertIncludes(settingsPath, settings, 'StorageKeys.BLOCKED_LIST_OWNER_KEY')
assertIncludes(settingsPath, settings, 'parseRuntimeIds')
assertIncludes(settingsPath, settings, 'blocked_list_extract_result')
assertIncludes(settingsPath, settings, 'blocked_list_skip_missing_variables')
assertIncludes(settingsPath, settings, 'blocked_list_save_start')
assertIncludes(settingsPath, settings, 'blocked_list_save_success')
assertIncludes(settingsPath, settings, 'blocked_list_load_cache_result')
assertIncludes(settingsPath, settings, 'ownerKeyPresent')
assertIncludes(settingsPath, settings, 'ownerKeyHash')
assertIncludes(settingsPath, settings, 'BlockedListSettings.saveActive(lists, undefined, sourceContext)')
assertIncludes(settingsPath, settings, "DiagnosticLogger.exception('storage'")
if (/DiagnosticLogger\.[^(]+\([^\n]+ownerKey:\s*ownerKey/.test(settings)) {
  fail('blocked list diagnostics must not log raw ownerKey')
}

assertIncludes(apiPath, api, 'captureBlockedListsFromHtml(html,')
assertIncludes(apiPath, api, 'blocked_list_sync_start')
assertIncludes(apiPath, api, 'blocked_list_html_received')
assertIncludes(apiPath, api, 'locationType')
assertIncludes(apiPath, api, 'BLOCKED_LIST_SYNC_ENDPOINTS')
assertIncludes(apiPath, api, "'/?tab=all'")
assertIncludes(apiPath, api, 'syncBlockedListsFromCookieHtmlSources')
assertIncludes(apiPath, api, 'for (const endpoint of ApiService.BLOCKED_LIST_SYNC_ENDPOINTS)')
assertIncludes(apiPath, api, 'if (captured)')
assertIncludes(apiPath, api, 'return')
assertIncludes(apiPath, api, 'async getMemberById(memberId: number)')
assertIncludes(apiPath, api, 'ApiConstants.API_MEMBER_SHOW')
assertIncludes(apiPath, api, 'normalizeVisibleTopics')
assertIncludes(apiPath, api, 'applyActiveBlockedTopicFilter')
assertIncludes(apiPath, api, 'StorageKeys.BLOCKED_LIST_OWNER_KEY')
assertIncludes(apiPath, api, 'StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_IDS')
assertIncludes(apiPath, api, 'StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_IDS')
assertIncludes(apiPath, api, 'ownerKey !== BlockedListSettings.activeOwnerKey()')
const syncAllIndex = api.indexOf("'/?tab=all'")
const syncRecentIndex = api.indexOf("'/recent?p=1'")
if (syncAllIndex < 0) {
  fail('blocked list sync source must use /?tab=all')
}
if (syncRecentIndex >= 0) {
  fail('blocked list refresh sync must not use /recent?p=1')
}
const syncMethodStart = api.indexOf('async syncBlockedListsFromCookieHtmlSources')
const nextMethodStart = api.indexOf('\n  private async getCookieHtml', syncMethodStart)
const syncMethod = syncMethodStart >= 0 && nextMethodStart > syncMethodStart ? api.slice(syncMethodStart, nextMethodStart) : ''
if (syncMethod.includes('/settings/reset/') || syncMethod.includes('once=')) {
  fail('blocked list sync source method must not include destructive reset/action endpoints')
}
if (api.includes('syncBlockedListsFromCookieRecent')) {
  fail('blocked list sync API name must not be recent-specific')
}

assertIncludes(pagePath, page, 'export struct BlockedListsPage')
assertIncludes(pagePath, page, 'StorageKeys.BLOCKED_LIST_SELECTED_TAB')
assertIncludes(pagePath, page, 'BlockedListSettings.loadActive')
assertIncludes(pagePath, page, 'AppStrings.R_LOGIN_TO_VIEW_BLOCKED')
assertIncludes(pagePath, page, 'AppStrings.R_COMMON_LOADING')
assertIncludes(pagePath, page, 'AppStrings.R_COMMON_LOAD_FAILED')
assertIncludes(pagePath, page, 'DiagnosticLogger.exception')
assertIncludes(pagePath, page, 'this.api.getTopicsByIds(topicIds)')
assertIncludes(pagePath, page, 'this.api.getMemberById(id)')
assertIncludes(pagePath, page, 'this.api.syncBlockedListsFromCookieHtmlSources')
assertIncludes(pagePath, page, "refreshAll('page_open')")
assertIncludes(pagePath, page, 'BlockedListSettings.runtimeSnapshot()')
assertIncludes(pagePath, page, 'topPadding: 68')
assertIncludes(pagePath, page, 'this.syncInFlight = !!cookie')
assertIncludes(pagePath, page, 'this.syncInFlight || this.loadingTopics')
assertIncludes(pagePath, page, 'this.syncInFlight || this.loadingMembers')
assertIncludes(pagePath, page, "`${trigger}_cache`")
assertIncludes(pagePath, page, "`${trigger}_network`")
assertIncludes(pagePath, page, 'blocked_list_render_snapshot')
assertIncludes(pagePath, page, "this.stack.pushPathByName('TopicDetail'")
assertIncludes(pagePath, page, "this.stack.pushPathByName('UserProfile'")
if (page.includes('.padding({ top: 168 })')) {
  fail('BlockedListsPage must not use magic root top padding')
}
if (page.includes('SegmentButton') || page.includes('SegmentButtonOptions.tab') || page.includes('TabsHeader')) {
  fail('BlockedListsPage must not render the segmented control in the page body')
}
if (page.includes("message: 'Loading...'") || page.includes("message: 'Load failed'")) {
  fail('BlockedListsPage loading/error states must use localized strings')
}
assertIncludes(storageKeysPath, storageKeys, 'BLOCKED_LIST_SELECTED_TAB')
assertIncludes(titleBarComponentsPath, titleBarComponents, 'export function BlockedListsTabsCCBuilder()')
assertIncludes(titleBarComponentsPath, titleBarComponents, 'SegmentButtonOptions.tab')
assertIncludes(titleBarComponentsPath, titleBarComponents, 'StorageKeys.BLOCKED_LIST_SELECTED_TAB')
assertIncludes(titleBarComponentsPath, titleBarComponents, '.constraintSize({ maxWidth: 448 })')
assertIncludes(titleBarComponentsPath, titleBarComponents, '.padding(ThemeConstants.SPACE_SM)')
if (/R_BLOCKED_USERS[^\n]+\$\{|R_IGNORED_TOPICS[^\n]+\$\{|\(\$\{this\.idCount/.test(titleBarComponents)) {
  fail('BlockedLists bottomBuilder segment labels must not append count suffixes')
}
const blockedLabelIndex = titleBarComponents.indexOf("AppStrings.R_BLOCKED_USERS")
const topicLabelIndex = titleBarComponents.indexOf("AppStrings.R_IGNORED_TOPICS")
if (blockedLabelIndex < 0 || topicLabelIndex < 0 || blockedLabelIndex > topicLabelIndex) {
  fail('BlockedLists bottomBuilder segment default/order must be blocked users before blocked topics')
}
assertIncludes(indexPath, index, "descriptor.family === 'blockedLists'")
assertIncludes(indexPath, index, 'wrapBuilder(BlockedListsTabsCCBuilder)')
assertIncludes(indexPath, index, "'showType': BottomBuilderShowType.DIRECTLY_SHOW")
assertIncludes(indexPath, index, "return this.navDestTitleBarOpts(AppStrings.R_NAV_BLOCKED_LISTS, undefined, undefined, bb)")
if (index.indexOf("descriptor.family === 'blockedLists'") > index.indexOf('IndexRouteCoordinator.usesStandardTitleBar')) {
  fail('BlockedLists bottomBuilder branch must run before generic standard title bar branch')
}

assertIncludes(routePath, route, "'BlockedLists': 'blockedLists'")
assertIncludes(routePath, route, "'blockedLists': AppStrings.R_NAV_BLOCKED_LISTS")
if (settingsPage.includes("pushPathByName('BlockedLists'")) {
  fail('SettingsPage must not expose BlockedLists navigation')
}
assertIncludes(accountPagePath, accountPage, "this.ns.pushPathByName('BlockedLists', null)")
assertIncludes(accountPagePath, accountPage, 'AppStrings.R_NAV_BLOCKED_LISTS')
assertIncludes(appStringsPath, appStrings, 'R_NAV_BLOCKED_LISTS')
assertIncludes(accountSessionCoordinatorPath, accountSessionCoordinator, "import { BlockedListSettings } from './BlockedListSettings'")
assertIncludes(accountSessionCoordinatorPath, accountSessionCoordinator, 'restoreBlockedListSnapshot')
assertIncludes(accountSessionCoordinatorPath, accountSessionCoordinator, 'BlockedListSettings.loadActive')
assertIncludes(accountSessionCoordinatorPath, accountSessionCoordinator, 'BlockedListSettings.apply(snapshot)')
assertIncludes(accountSessionCoordinatorPath, accountSessionCoordinator, "BlockedListSettings.apply(BlockedListSettings.empty(''))")

function extractWithPresence(sample, variableName) {
  const pattern = new RegExp('(?:^|[^0-9A-Za-z_])' + variableName + '\\s*=\\s*\\[([^\\]]*)\\]', 'm')
  const match = sample.match(pattern)
  return {
    present: !!(match && match.length >= 2),
    rawLength: match && match.length >= 2 ? (match[1] || '').length : 0,
    ids: extractFrom(sample, variableName),
  }
}

function extractFrom(sample, variableName) {
  const pattern = new RegExp('(?:^|[^0-9A-Za-z_])' + variableName + '\\s*=\\s*\\[([^\\]]*)\\]', 'm')
  const match = sample.match(pattern)
  if (!match || match.length < 2) {
    return []
  }
  const ids = []
  const seen = new Set()
  const valueRegex = /(?:^|[^\d-])(\d+)/g
  let valueMatch = null
  const raw = match[1] || ''
  while ((valueMatch = valueRegex.exec(raw)) !== null) {
    const id = parseInt(valueMatch[1], 10)
    if (id > 0 && !seen.has(id)) {
      ids.push(id)
      seen.add(id)
    }
  }
  return ids
}

const sample = `
<script>
var ignored_topics = [101, 102, 101, 0, -7, 103];
var blocked = [55, 56, 55, 0];
var not_ignored_topics = [999];
</script>`
const ignored = extractFrom(sample, 'ignored_topics').join(',')
const blocked = extractFrom(sample, 'blocked').join(',')
if (ignored !== '101,102,103') {
  fail(`parser regex parity for ignored_topics changed unexpectedly: ${ignored}`)
}
if (blocked !== '55,56') {
  fail(`parser regex parity for blocked changed unexpectedly: ${blocked}`)
}

const whitespace = '<script>\n ignored_topics   =   [  1 ,\n 2, 3 ] ;\n blocked\t=\t[ 4 , 5 ]\n</script>'
if (extractFrom(whitespace, 'ignored_topics').join(',') !== '1,2,3') {
  fail('parser regex parity failed whitespace ignored_topics sample')
}
if (extractFrom(whitespace, 'blocked').join(',') !== '4,5') {
  fail('parser regex parity failed whitespace blocked sample')
}
if (extractFrom('<script>ignored_topics = []; blocked = [];</script>', 'ignored_topics').length !== 0) {
  fail('parser regex parity failed empty arrays sample')
}
const presentEmpty = extractWithPresence('<script>ignored_topics = []; blocked = [];</script>', 'ignored_topics')
if (!presentEmpty.present || presentEmpty.rawLength !== 0 || presentEmpty.ids.length !== 0) {
  fail('parser presence parity failed present-empty [] sample')
}
if (extractFrom('<div class="from_123">not a blocked list</div>', 'blocked').length !== 0) {
  fail('parser regex parity must not treat from_{memberId} CSS classes as blocked list source')
}
const noGreedy = '<script>ignored_topics = [7]; const x = [999]; blocked = [8];</script>'
if (extractFrom(noGreedy, 'ignored_topics').join(',') !== '7') {
  fail('parser regex parity greedily over-captured past ignored_topics array')
}
if (extractFrom('<script>const other = [1];</script>', 'ignored_topics').length !== 0) {
  fail('parser regex parity failed missing variable sample')
}
const missingIgnored = extractWithPresence('<script>const other = [1];</script>', 'ignored_topics')
if (missingIgnored.present || missingIgnored.rawLength !== 0 || missingIgnored.ids.length !== 0) {
  fail('parser presence parity failed missing variable sample')
}
;[
  'endpoint',
  'source',
  'trigger',
  'ignored_topics_present',
  'blocked_present',
  'ignored_count',
  'blocked_count',
].forEach((key) => assertIncludes(settingsPath, settings, key))
;[
  'blocked_list_sync_start',
  'blocked_list_html_received',
  'blocked_list_extract_result',
  'blocked_list_skip_missing_variables',
  'blocked_list_save_start',
  'blocked_list_save_success',
  'blocked_list_save_exception',
  'blocked_list_load_cache_result',
  'blocked_list_render_snapshot',
].forEach((eventName) => {
  if (!`${settings}\n${api}\n${page}`.includes(eventName)) {
    fail(`missing blocked list diagnostic event: ${eventName}`)
  }
})
if (`${settings}\n${api}\n${page}`.includes('rawHtml') || `${settings}\n${api}\n${page}`.includes('rawHTML')) {
  fail('blocked list diagnostics must not log raw HTML')
}

function sourceHasBlockedVariables(html) {
  const ignoredPresence = extractWithPresence(html, 'ignored_topics')
  const blockedPresence = extractWithPresence(html, 'blocked')
  return ignoredPresence.present && blockedPresence.present
}

const sourceFixtures = {
  '/?tab=all': '<script>ignored_topics = [201, 202]; blocked = [301, 302];</script>',
}
const selectedEndpoint = ['/?tab=all'].find((endpoint) => sourceHasBlockedVariables(sourceFixtures[endpoint]))
if (selectedEndpoint !== '/?tab=all') {
  fail(`blocked list source fixture should save from deterministic /?tab=all source, got ${selectedEndpoint}`)
}
if (extractFrom(sourceFixtures[selectedEndpoint], 'ignored_topics').length === 0 || extractFrom(sourceFixtures[selectedEndpoint], 'blocked').length === 0) {
  fail('blocked list source fixture selected source must save nonzero arrays from the good source')
}
const missingAllSelectedEndpoint = ['/?tab=all'].find((endpoint) => sourceHasBlockedVariables({
  '/?tab=all': '<script>const allMissing = true;</script>',
}[endpoint]))
if (missingAllSelectedEndpoint !== undefined) {
  fail(`blocked list source must not fall back to recent/other pages when /?tab=all variables are missing, got ${missingAllSelectedEndpoint}`)
}

console.log('PASS: blocked lists static contract')
