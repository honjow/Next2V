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

assertIncludes(parserPath, parser, 'export interface V2exBlockedIdLists')
assertIncludes(parserPath, parser, 'static extractBlockedIdLists(html: string): V2exBlockedIdLists')
assertIncludes(parserPath, parser, "extractJsNumberArray(html || '', 'ignored_topics')")
assertIncludes(parserPath, parser, "extractJsNumberArray(html || '', 'blocked')")
assertIncludes(parserPath, parser, 'const pattern = new RegExp')
assertIncludes(parserPath, parser, 'seen: Set<number>')

assertIncludes(settingsPath, settings, 'const KEY_PREFIX: string = \'blockedListState:\'')
assertIncludes(settingsPath, settings, 'static activeOwnerKey(): string')
assertIncludes(settingsPath, settings, 'StorageKeys.ACTIVE_ACCOUNT_ID')
assertIncludes(settingsPath, settings, 'static updateFromTopicListHtml(html: string): void')
assertIncludes(settingsPath, settings, 'BlockedListSettings.saveActive(lists)')
assertIncludes(settingsPath, settings, "DiagnosticLogger.exception('storage'")

assertIncludes(apiPath, api, 'captureBlockedListsFromHtml(html)')
assertIncludes(apiPath, api, 'async getMemberById(memberId: number)')
assertIncludes(apiPath, api, 'ApiConstants.API_MEMBER_SHOW')

assertIncludes(pagePath, page, 'export struct BlockedListsPage')
assertIncludes(pagePath, page, 'StorageKeys.BLOCKED_LIST_SELECTED_TAB')
assertIncludes(pagePath, page, 'BlockedListSettings.loadActive')
assertIncludes(pagePath, page, 'AppStrings.R_LOGIN_TO_VIEW_BLOCKED')
assertIncludes(pagePath, page, 'AppStrings.R_COMMON_LOADING')
assertIncludes(pagePath, page, 'AppStrings.R_COMMON_LOAD_FAILED')
assertIncludes(pagePath, page, 'DiagnosticLogger.exception')
assertIncludes(pagePath, page, 'this.api.getTopicsByIds(topicIds)')
assertIncludes(pagePath, page, 'this.api.getMemberById(id)')
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

console.log('PASS: blocked lists static contract')
