import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'

const repo = process.cwd()
const read = (file) => fs.readFileSync(path.join(repo, file), 'utf8')

const storageKeys = read('shared/src/main/ets/constants/StorageKeys.ets')
const settings = read('shared/src/main/ets/settings/HotReplySettings.ets')
const state = read('shared/src/main/ets/state/HotReplySettingsState.ets')
const bootstrap = read('shared/src/main/ets/settings/SettingsBootstrap.ets')
const settingsPage = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
const saveCoordinator = read('feature/settings/src/main/ets/model/SettingsSaveCoordinator.ets')
const detailPage = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
const viewModel = read('feature/detail/src/main/ets/viewmodel/DetailViewModel.ets')
const selector = read('feature/detail/src/main/ets/model/HotReplyCoordinator.ets')
const panel = read('feature/detail/src/main/ets/components/HotRepliesPanel.ets')

function mustInclude(source, needle, label) {
  assert.ok(source.includes(needle), label)
}

function mustAppearInOrder(source, needles, label) {
  let offset = -1
  for (const needle of needles) {
    const next = source.indexOf(needle, offset + 1)
    assert.ok(next > offset, label)
    offset = next
  }
}

for (const key of [
  'HOT_REPLIES_ENABLED',
  'HOT_REPLIES_MAX_COUNT',
  'HOT_REPLIES_MIN_THANKS',
]) {
  mustInclude(storageKeys, key, `StorageKeys must define ${key}`)
}

mustInclude(settings, 'static readonly DEFAULT_ENABLED: boolean = true', 'hot replies default must be enabled')
mustInclude(settings, 'static readonly DEFAULT_MAX_COUNT: number = 5', 'hot replies default count must stay bounded')
mustInclude(settings, 'static readonly DEFAULT_MIN_THANKS: number = 3', 'hot replies default threshold must be explicit')
mustInclude(state, '@Trace enabled: boolean = true', 'V2 mirror must default enabled')
mustInclude(bootstrap, 'restoreHotReplies', 'SettingsBootstrap must restore hot replies')

mustInclude(settingsPage, "$r('app.string.hot_replies')", 'SettingsPage must expose hot replies switch')
mustInclude(settingsPage, "$r('app.string.hot_replies_count')", 'SettingsPage must expose max count setting')
mustInclude(settingsPage, "$r('app.string.hot_replies_min_thanks')", 'SettingsPage must expose threshold setting')
mustInclude(saveCoordinator, 'static saveHotReplies(', 'SettingsSaveCoordinator must persist hot replies')

mustInclude(detailPage, '@Local private hotReplies: HotReplySettingsState = connectHotReplySettings();', 'TopicDetailPage must read V2 hot reply settings as a monitorable state source')
mustInclude(detailPage, 'this.HotRepliesPreview(this.hotReplyItems())', 'high replies must render on the detail page')
mustInclude(detailPage, 'HotRepliesPanel({', 'TopicDetailPage must use the hot replies panel')
mustAppearInOrder(
  detailPage,
  ['this.TopicCard()', 'this.HotRepliesPreview(this.hotReplyItems())', 'this.ReplyDivider()'],
  'high replies must render as an independent list item after the topic card and before the reply divider',
)
mustInclude(detailPage, 'onJumpClick: (reply: V2exReply) => {', 'hot reply jump must be separated from the reply action')
mustInclude(detailPage, 'this.jumpToLoadedReplyFloor(reply.floor || 0)', 'hot reply jump must reuse loaded floor navigation')
mustInclude(viewModel, 'triggerThreadPreloadIfNeeded(hotRepliesEnabled: boolean = false)', 'preload decision must include hot replies')
mustInclude(viewModel, '@Trace hotReplyCandidates: V2exReply[] = []', 'ViewModel must keep semantic high-reply candidates instead of a render counter')
mustInclude(viewModel, 'HotReplyCoordinator.select(', 'ViewModel must refresh high-reply candidates when replies publish')
mustInclude(viewModel, 'getHotReplies(enabled: boolean, maxCount: number, minThanks: number): V2exReply[]', 'ViewModel must expose selected hot replies')
mustInclude(viewModel, 'HotReplyCoordinator.filterCandidates(this.hotReplyCandidates, maxCount, minThanks)', 'ViewModel must filter existing candidates by settings')

mustInclude(selector, 'ReplyDisplaySettings.MODE_THREAD', 'selector must reuse threaded reply grouping')
mustInclude(selector, 'static filterCandidates(', 'selector must support settings-only filtering without rebuilding replies')
mustInclude(selector, 'Math.max(0, reply.thanks || 0) >= minThanks', 'selector must use thanks threshold')
mustInclude(selector, 'right.thanks', 'selector must sort by higher thanks first')
mustInclude(selector, 'result.length < normalizedMaxCount', 'selector must enforce max count')

mustInclude(panel, 'ReplyCard({', 'top hot replies must use the full shared ReplyCard')
mustInclude(panel, 'childReplies: []', 'top hot reply cards must not recursively render child replies')
mustInclude(panel, 'embedded: true', 'top hot reply content must render inside the panel-owned card so simplified nested replies stay in the same card')
mustAppearInOrder(
  panel,
  ['ReplyCard({', 'this.ChildReplyGroup(reply)', 'Text(this.jumpText(reply))'],
  'simplified nested replies and floor jump must stay inside the hot reply card frame',
)
mustInclude(panel, 'showUserMarks: false', 'nested hot replies must omit user marks to save space')
mustInclude(panel, 'reply.threadChildren || []', 'panel must render simplified nested replies')
mustInclude(panel, "$r('app.string.hot_replies_header_format')", 'panel title must use i18n resource')
mustInclude(panel, "$r('app.string.hot_replies_threshold_format')", 'panel threshold must use i18n resource')
mustInclude(panel, "$r('app.string.hot_replies_jump_format')", 'panel jump text must use i18n resource')

for (const locale of ['base', 'en_US', 'zh_CN', 'zh_TW', 'zh_HK', 'ja_JP', 'ko_KR']) {
  const strings = read(`entry/src/main/resources/${locale}/element/string.json`)
  for (const key of [
    'hot_replies',
    'hot_replies_count',
    'hot_replies_min_thanks',
    'hot_replies_count_format',
    'hot_replies_min_thanks_format',
    'hot_replies_header_format',
    'hot_replies_threshold_format',
    'hot_replies_jump_format',
  ]) {
    mustInclude(strings, `"name": "${key}"`, `${locale} must define ${key}`)
  }
}

console.log('PASS hot replies static contract')
