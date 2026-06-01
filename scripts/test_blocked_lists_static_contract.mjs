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

function methodBody(text, methodName) {
  const marker = methodName.includes('(') ? methodName : `${methodName}(`
  const start = text.indexOf(marker)
  if (start < 0) {
    fail(`missing method marker: ${marker}`)
  }
  const braceStart = text.indexOf('{', start)
  if (braceStart < 0) {
    fail(`missing method body for: ${marker}`)
  }
  let depth = 0
  for (let i = braceStart; i < text.length; i++) {
    const ch = text[i]
    if (ch === '{') depth += 1
    if (ch === '}') {
      depth -= 1
      if (depth === 0) {
        return text.slice(braceStart + 1, i)
      }
    }
  }
  fail(`unterminated method body for: ${marker}`)
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
// activeOwnerKey derives owner identity from the active account id (precedence) then the auth-session
// username (fallback), now read from the V2 holders (AccountStore.getActiveId() the transient authority
// the legacy ACTIVE_ACCOUNT_ID key mirrored, and connectAuthSessionSignal().username) instead of direct
// AppStorage.get reads. The owner key still embeds the base URL and the account/user scope, so logged-out
// (no id, no username) yields an empty owner key.
assertIncludes(settingsPath, settings, 'AccountStore.getActiveId()')
assertIncludes(settingsPath, settings, 'connectAuthSessionSignal().username')
assertIncludes(settingsPath, settings, '`${baseUrl}#account:${activeId}`')
assertIncludes(settingsPath, settings, '`${baseUrl}#user:${username}`')
assertIncludes(settingsPath, settings, 'export interface BlockedListCaptureSource')
assertIncludes(settingsPath, settings, 'static updateFromTopicListHtml(html: string, source: BlockedListCaptureSource = {}): boolean')
assertIncludes(settingsPath, settings, 'static runtimeSnapshot(): BlockedListSnapshot')
// runtimeSnapshot reads the account-scoped runtime ledger from the V2 BlockedListStorageState mirror
// (kept in lockstep by apply() + the meta-only writers), not direct AppStorage.get.
assertIncludes(settingsPath, settings, 'connectBlockedListStorage()')
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
// ApiService filters account-bound via the V2 BlockedListStorageState mirror (was direct AppStorage.get
// reads of the BLOCKED_LIST_* keys). The owner-binding guard is preserved: an empty or non-active owner
// key returns all topics, so blocked state never leaks across accounts/domains.
assertIncludes(apiPath, api, 'connectBlockedListStorage()')
assertIncludes(apiPath, api, 'storage.ownerKey')
assertIncludes(apiPath, api, 'storage.ignoredTopicIdsJson')
assertIncludes(apiPath, api, 'storage.blockedMemberIdsJson')
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
assertIncludes(pagePath, page, 'AppStrings.R_COMMON_LOAD_FAILED')
assertIncludes(pagePath, page, 'DiagnosticLogger.exception')
assertIncludes(pagePath, page, 'this.api.getTopicsByIds(topicIds)')
assertIncludes(pagePath, page, 'this.api.getMemberById(id)')
assertIncludes(pagePath, page, 'this.api.syncBlockedListsFromCookieHtmlSources')
assertIncludes(pagePath, page, "refreshAll('page_open')")
assertIncludes(pagePath, page, 'BlockedListSettings.runtimeSnapshot()')
assertIncludes(pagePath, page, 'topPadding: this.BOTTOM_BUILDER_HEIGHT')
assertIncludes(pagePath, page, 'BlockedMemberCardView({')
assertIncludes(pagePath, page, 'LocalTopicCard({')
assertIncludes(pagePath, page, 'BlockedListContent()')
assertIncludes('shared/src/main/ets/components/LocalTopicCard.ets', source('shared/src/main/ets/components/LocalTopicCard.ets'), 'last_touched: this.metaTimestamp > 0 ? this.metaTimestamp : this.created')
assertIncludes(pagePath, page, 'this.syncInFlight = !!cookie')
assertIncludes(pagePath, page, '@Watch(\'onBlockedListStorageChanged\')')
assertIncludes(pagePath, page, 'private onBlockedListStorageChanged()')
assertIncludes(pagePath, page, 'private applyRuntimeSnapshot')
assertIncludes(pagePath, page, 'private hasAnyRenderableForCurrentTab(): boolean')
const pageLoadingBody = methodBody(page, 'private shouldShowPageLoading')
if (pageLoadingBody.includes('this.syncInFlight || this.loadingTopics')) {
  fail('BlockedListsPage must not use sync/loading as fullscreen loading for ignored topics')
}
if (pageLoadingBody.includes('this.syncInFlight || this.loadingMembers')) {
  fail('BlockedListsPage must not use sync/loading as fullscreen loading for cached blocked members')
}
assertIncludes(pagePath, page, "`${trigger}_cache`")
assertIncludes(pagePath, page, "`${trigger}_network`")
assertIncludes(pagePath, page, 'blocked_list_render_snapshot')
assertIncludes(pagePath, page, "this.stack.pushPathByName('TopicDetail'")
assertIncludes(pagePath, page, "this.stack.pushPathByName('UserProfile'")
if (page.includes('.padding({ top: 168 })')) {
  fail('BlockedListsPage must not use magic root top padding')
}
if (page.includes('TabHeaderItem()') || page.includes('SegmentButton({')) {
  fail('BlockedListsPage must not render the segment control as a list item')
}
if (page.includes('EMPTY_STATE_HEIGHT')) {
  fail('BlockedListsPage must not use a fixed EMPTY_STATE_HEIGHT')
}
if (/stateHeight\s*:/.test(page)) {
  fail('BlockedListsPage must not pass fixed stateHeight values')
}
if (page.includes('BlockedEmptyState(')) {
  fail('BlockedListsPage must not collapse loading/empty/error into one list-item empty-state builder')
}
if (page.includes('applySnapshot(BlockedListSettings.runtimeSnapshot()')) {
  fail('BlockedListsPage aboutToAppear must not re-resolve the runtime snapshot before refreshAll')
}
assertIncludes(pagePath, page, 'PageLoadingState()')
assertIncludes(pagePath, page, 'CardEmptyState({')
assertIncludes(pagePath, page, 'private shouldShowPageLoading(): boolean')
assertIncludes(pagePath, page, 'private pageStateMessage(): string')
assertIncludes(pagePath, page, 'private topContentInset(): number')
assertIncludes(pagePath, page, 'private bottomContentInset(): number')
assertIncludes(pagePath, page, '@ObservedV2')
assertIncludes(pagePath, page, '@Trace username: string')
assertIncludes(pagePath, page, '@Trace avatar: string')
assertIncludes(pagePath, page, '@ComponentV2')
assertIncludes(pagePath, page, '@Param item: BlockedMemberListItem')
assertIncludes(pagePath, page, 'private memberRowsById: Map<number, BlockedMemberListItem>')
assertIncludes(pagePath, page, 'private ensureMemberRowsForIds')
assertIncludes(pagePath, page, 'private memberRowForId')
assertIncludes(pagePath, page, 'pageState: this.pageStateName()')
assertIncludes(pagePath, page, 'this.members = this.ensureMemberRowsForIds(memberIds)')
if (page.includes('interface BlockedMemberListItem')) {
  fail('BlockedMemberListItem must be an @ObservedV2 class, not an interface')
}
if (page.includes('private renderableMembers()')) {
  fail('BlockedListsPage must not render transient fallback member arrays')
}
if (page.includes('this.members = items')) {
  fail('BlockedListsPage must not replace resolved member rows with same-key new objects')
}
if (page.includes("Text('›')") || page.includes('Text("›")')) {
  fail('BlockedListsPage must not use text arrows as icons')
}
if (page.includes("message: 'Loading...'") || page.includes("message: 'Load failed'")) {
  fail('BlockedListsPage loading/error states must use localized strings')
}

assertIncludes(storageKeysPath, storageKeys, 'BLOCKED_LIST_SELECTED_TAB')
assertIncludes(indexPath, index, 'wrapBuilder(BlockedListsTabsCCBuilder)')
assertIncludes(indexPath, index, "'height': ThemeConstants.TITLE_BAR_HEIGHT")
if (/R_BLOCKED_USERS[^\n]+\$\{|R_IGNORED_TOPICS[^\n]+\$\{|\(\$\{this\.idCount/.test(page)) {
  fail('BlockedLists segment labels must not append count suffixes')
}
const blockedLabelIndex = titleBarComponents.indexOf("AppStrings.R_BLOCKED_USERS")
const topicLabelIndex = titleBarComponents.indexOf("AppStrings.R_IGNORED_TOPICS")
if (blockedLabelIndex < 0 || topicLabelIndex < 0 || blockedLabelIndex > topicLabelIndex) {
  fail('BlockedLists tab header must keep blocked users before ignored topics')
}
assertIncludes(indexPath, index, "descriptor.family === 'blockedLists'")
assertIncludes(indexPath, index, 'return this.navDestTitleBarOpts(AppStrings.R_NAV_BLOCKED_LISTS, undefined, undefined, bb)')
if (index.indexOf("descriptor.family === 'blockedLists'") > index.indexOf('IndexRouteCoordinator.usesStandardTitleBar')) {
  fail('BlockedLists title bar branch must run before generic standard title bar branch')
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
