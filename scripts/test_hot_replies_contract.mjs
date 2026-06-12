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
const hotReplySettingsPage = read('feature/settings/src/main/ets/pages/HotReplySettingsPage.ets')
const settingsIndex = read('feature/settings/src/main/ets/Index.ets')
const entryIndex = read('entry/src/main/ets/pages/Index.ets')
const routeCoordinator = read('entry/src/main/ets/model/IndexRouteCoordinator.ets')
const saveCoordinator = read('feature/settings/src/main/ets/model/SettingsSaveCoordinator.ets')
const detailPage = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
const viewModel = read('feature/detail/src/main/ets/viewmodel/DetailViewModel.ets')
const selector = read('feature/detail/src/main/ets/model/HotReplyCoordinator.ets')
const childReplyExpandCache = read('feature/detail/src/main/ets/model/HotReplyChildRepliesExpandCache.ets')
const panel = read('feature/detail/src/main/ets/components/HotRepliesPanel.ets')
const replyCard = read('shared/src/main/ets/components/ReplyCard.ets')
const replyCardHeader = read('shared/src/main/ets/components/reply/ReplyCardHeader.ets')

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
  'HOT_REPLIES_CHILD_REPLIES_EXPANDED',
]) {
  mustInclude(storageKeys, key, `StorageKeys must define ${key}`)
}

mustInclude(settings, 'static readonly DEFAULT_ENABLED: boolean = true', 'hot replies default must be enabled')
mustInclude(settings, 'static readonly DEFAULT_MAX_COUNT: number = 5', 'hot replies default count must stay bounded')
mustInclude(settings, 'static readonly DEFAULT_MIN_THANKS: number = 3', 'hot replies default threshold must be explicit')
mustInclude(settings, 'static readonly DEFAULT_CHILD_REPLIES_EXPANDED: boolean = false', 'hot reply nested replies must default collapsed')
mustInclude(settings, 'store.putSync(KEY_CHILD_REPLIES_EXPANDED, normalized.childRepliesExpanded)', 'hot reply nested default must be persisted')
mustInclude(state, '@Trace enabled: boolean = true', 'V2 mirror must default enabled')
mustInclude(state, '@Trace childRepliesExpanded: boolean = false', 'V2 mirror must default hot reply nested replies collapsed')
mustInclude(bootstrap, 'restoreHotReplies', 'SettingsBootstrap must restore hot replies')

mustInclude(settingsPage, "$r('app.string.hot_replies')", 'SettingsPage must expose the hot replies entry row')
mustInclude(settingsPage, "this.stack.pushPathByName('HotReplySettings', null)", 'SettingsPage hot replies row must open the dedicated settings page')
mustInclude(settingsPage, "$r('app.string.common_open')", 'SettingsPage hot replies entry must summarize enabled state as open')
mustInclude(settingsPage, "$r('app.string.common_closed')", 'SettingsPage hot replies entry must summarize enabled state as closed')
assert.ok(!settingsPage.includes("$r('app.string.hot_replies_child_replies_expanded')"), 'SettingsPage must keep hot reply child expansion out of the main reading list')
assert.ok(!settingsPage.includes("$r('app.string.hot_replies_count')"), 'SettingsPage must keep hot reply count out of the main reading list')
assert.ok(!settingsPage.includes("$r('app.string.hot_replies_min_thanks')"), 'SettingsPage must keep hot reply threshold out of the main reading list')
mustInclude(hotReplySettingsPage, "$r('app.string.hot_replies')", 'HotReplySettingsPage must expose the hot replies switch')
mustInclude(hotReplySettingsPage, 'this.HotReplySwitchSection()', 'HotReplySettingsPage must keep the master switch in its own group')
mustInclude(hotReplySettingsPage, '@Local private hotRepliesEnabled: boolean = HotReplySettings.DEFAULT_ENABLED;', 'HotReplySettingsPage switch must use a local checked state')
mustInclude(hotReplySettingsPage, '@Local private hotReplyOptionsMounted: boolean = HotReplySettings.DEFAULT_ENABLED;', 'HotReplySettingsPage options visibility must be locally mounted')
mustInclude(hotReplySettingsPage, 'checked: this.hotRepliesEnabled', 'HotReplySettingsPage switch must not read the options visibility state')
mustInclude(hotReplySettingsPage, 'if (this.hotReplyOptionsMounted)', 'HotReplySettingsPage must hide detailed options through a separate mount state')
mustInclude(hotReplySettingsPage, '.transition(TransitionEffect.OPACITY)', 'HotReplySettingsPage options group must animate insertion and removal')
mustInclude(hotReplySettingsPage, 'private animateHotReplyOptions(mounted: boolean): void', 'HotReplySettingsPage must centralize option visibility animation')
mustInclude(hotReplySettingsPage, 'this.getUIContext().animateTo(', 'HotReplySettingsPage must animate detailed option visibility changes')
assert.ok(!hotReplySettingsPage.includes('if (this.hotReplies.enabled)'), 'HotReplySettingsPage must not couple the options group directly to the persisted hot reply state')
mustInclude(hotReplySettingsPage, 'this.HotReplyOptionsSection()', 'HotReplySettingsPage must render detailed options as a separate conditional group')
mustInclude(hotReplySettingsPage, "$r('app.string.hot_replies_child_replies_expanded')", 'HotReplySettingsPage must expose hot reply nested reply expansion switch')
mustInclude(hotReplySettingsPage, "$r('app.string.hot_replies_count')", 'HotReplySettingsPage must expose max count setting')
mustInclude(hotReplySettingsPage, "$r('app.string.hot_replies_min_thanks')", 'HotReplySettingsPage must expose threshold setting')
mustInclude(hotReplySettingsPage, 'this.updateHotReplyChildRepliesExpanded(value)', 'HotReplySettingsPage must route nested expansion toggles through the hot reply saver')
mustInclude(settingsIndex, "export { HotReplySettingsPage } from './pages/HotReplySettingsPage'", 'settings HAR must export HotReplySettingsPage')
mustInclude(routeCoordinator, "'HotReplySettings': 'hotReplySettings'", 'IndexRouteCoordinator must register the hot reply settings route')
mustInclude(routeCoordinator, "'hotReplySettings': $r('app.string.hot_replies')", 'hot reply settings route title must reuse the hot replies label')
mustInclude(entryIndex, 'HotReplySettingsPage,', 'Index must import HotReplySettingsPage')
mustInclude(entryIndex, "descriptor.family === 'hotReplySettings'", 'Index must render HotReplySettingsPage for its route family')
mustInclude(saveCoordinator, 'static saveHotReplies(', 'SettingsSaveCoordinator must persist hot replies')
mustInclude(saveCoordinator, 'childRepliesExpanded: boolean', 'SettingsSaveCoordinator must persist hot reply nested expansion')

mustInclude(detailPage, '@Local private hotReplies: HotReplySettingsState = connectHotReplySettings();', 'TopicDetailPage must read V2 hot reply settings as a monitorable state source')
mustInclude(detailPage, '@Local private hotReplyChildRepliesExpandedByKey: Record<string, boolean> = {};', 'TopicDetailPage must own hot-reply child expand cache state')
mustInclude(detailPage, 'HotReplyChildRepliesExpandCache.loadPanelExpanded(this.topicId)', 'TopicDetailPage must restore cached hot-reply panel expand state on entry')
mustInclude(detailPage, 'HotReplyChildRepliesExpandCache.setPanelExpanded(', 'TopicDetailPage must write hot-reply panel expand state back to cache')
mustInclude(detailPage, 'HotReplyChildRepliesExpandCache.load(this.topicId)', 'TopicDetailPage must restore cached hot-reply child expand state on entry')
mustInclude(detailPage, 'HotReplyChildRepliesExpandCache.setReplyExpanded(', 'TopicDetailPage must write hot-reply child expand state back to cache')
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
mustInclude(viewModel, 'const sourceReplies = this.publishedReplies.length > 0 ? this.publishedReplies : this.replies', 'ViewModel must hydrate hot replies from the same published snapshot as the normal list')
mustInclude(viewModel, 'HotReplyCoordinator.filterCandidatesFromReplies(', 'ViewModel must hydrate existing candidates from current threaded replies before rendering')
mustInclude(viewModel, 'private refreshHotReplyCandidates(): void', 'ViewModel must expose one hot-reply candidate refresh chokepoint')
mustInclude(viewModel, 'private syncHotReplyCandidateFromLoadedReply(replyId: number): void', 'ViewModel must sync hot-reply clones when a held publish cannot rebuild the full list')
mustAppearInOrder(
  viewModel,
  ['const visibleReplies = this.getVisibleReplies()', 'this.refreshHotReplyCandidates()', 'this.replyDataSource.setData(visibleReplies)'],
  'publishing replies must refresh hot reply candidates before notifying the normal reply data source',
)
mustInclude(detailPage, 'return this.reloadTopicWithThreadPreload()', 'reply submit must keep the success chain open until the post-reply reload/preload completes')

mustInclude(selector, 'ReplyDisplaySettings.MODE_THREAD', 'selector must reuse threaded reply grouping')
mustInclude(selector, 'static filterCandidates(', 'selector must support settings-only filtering without rebuilding replies')
mustInclude(selector, 'static filterCandidatesFromReplies(', 'selector must hydrate hot reply candidates from latest threaded replies')
mustInclude(selector, 'HotReplyCoordinator.collectById(latestThreaded, latestById)', 'selector must index the latest threaded reply tree by reply id')
mustInclude(selector, 'const reply = HotReplyCoordinator.cloneReply(source)', 'selector must clone hydrated hot replies before mutating render fields')
mustInclude(selector, 'Math.max(0, reply.thanks || 0) >= minThanks', 'selector must use thanks threshold')
mustInclude(selector, 'right.thanks', 'selector must sort by higher thanks first')
mustInclude(selector, 'result.length < normalizedMaxCount', 'selector must enforce max count')

mustInclude(panel, 'ReplyCard({', 'top hot replies must use the full shared ReplyCard')
mustInclude(panel, 'childReplies: reply.threadChildren || []', 'top hot reply cards must reuse the shared ReplyCard thread renderer')
mustInclude(panel, 'embedded: true', 'top hot reply content must render inside the panel-owned card so simplified nested replies stay in the same card')
mustInclude(panel, 'childAvatarVisible: false', 'hot reply nested replies must use ReplyCard simplification instead of a custom renderer')
mustInclude(panel, 'childRepliesExpandable: true', 'top hot reply cards must allow collapsing their nested replies')
mustInclude(panel, '@Param childRepliesDefaultExpanded: boolean = false;', 'hot reply child replies must default collapsed when no per-topic cache exists')
mustInclude(panel, '@Param childRepliesExpandedByKey: Record<string, boolean> = {};', 'hot reply child-reply collapse state must be provided by the page cache')
mustInclude(panel, '@Event onChildRepliesExpandedChange?: (reply: V2exReply, expanded: boolean) => void;', 'hot reply panel must report child expand changes to the page cache owner')
mustInclude(panel, 'private childRepliesStateKey(reply: V2exReply): string', 'hot reply child expand state must use a stable reply id key')
mustInclude(panel, 'childRepliesExpanded: this.isChildRepliesExpanded(reply)', 'top hot reply cards must receive cached child-reply expanded state')
mustAppearInOrder(
  panel,
  ['if (cached === true || cached === false)', 'return this.childRepliesDefaultExpanded'],
  'hot reply child-reply cache must override the global default',
)
mustInclude(panel, 'onChildRepliesExpandedChange: (target: V2exReply, expanded: boolean) => {', 'top hot reply cards must report child-reply expand changes')
mustInclude(panel, 'this.setChildRepliesExpanded(target, expanded)', 'hot reply panel must update the cached child-reply expand state')
mustInclude(childReplyExpandCache, 'MAX_TOPICS: number = 40', 'hot reply child expand cache must stay bounded')
mustInclude(childReplyExpandCache, 'static loadPanelExpanded(topicId: number): boolean', 'hot reply panel expand cache must restore by topic')
mustInclude(childReplyExpandCache, 'static setPanelExpanded(topicId: number, expanded: boolean): boolean', 'hot reply panel expand cache must write by topic')
mustInclude(childReplyExpandCache, 'static load(topicId: number): Record<string, boolean>', 'hot reply child expand cache must restore by topic')
mustInclude(childReplyExpandCache, 'static setReplyExpanded(', 'hot reply child expand cache must write by topic and reply')
mustInclude(childReplyExpandCache, 'reply.id.toString()', 'hot reply child expand cache must key by stable reply id when available')
mustInclude(panel, 'this.getUIContext().animateTo(', 'hot replies section expand/collapse must animate the state change')
mustInclude(panel, '.transition(TransitionEffect.OPACITY)', 'hot replies section body must fade during expand/collapse')
mustInclude(panel, 'onFloorClick: (target: V2exReply) => {', 'top hot replies must reuse the floor label for jump')
mustInclude(panel, 'this.jumpToReply(target)', 'top hot reply floor label must jump to the original reply')
assert.ok(!panel.includes('jumpText'), 'panel must not keep a separate floor jump text row')
assert.ok(!panel.includes('hot_replies_jump_format'), 'panel must not keep a separate jump label resource')
mustInclude(panel, 'Column({ space: ThemeConstants.SPACE_SM - 2 })', 'hot reply cards must use the same vertical gap as the normal reply list')
mustAppearInOrder(
  panel,
  ['ReplyCard({', 'childReplies: reply.threadChildren || []', 'onFloorClick: (target: V2exReply) => {'],
  'top floor jump and simplified nested replies must stay inside the hot reply card frame',
)
mustInclude(panel, 'reply.threadChildren || []', 'panel must pass nested replies to the shared ReplyCard renderer')
assert.ok(!panel.includes('@Builder\n  private ChildReply'), 'panel must not define a custom nested reply renderer')
assert.ok(!panel.includes('showUserMarks: false'), 'panel must not fork UserName rendering for nested hot replies')
assert.ok(!panel.includes('MarkdownContent({'), 'panel must not fork Markdown rendering for nested hot replies')
assert.ok(!panel.includes('@Local private childGuideHeights'), 'nested hot reply guides must not store measured heights')
assert.ok(!panel.includes('childGuideHeight('), 'nested hot reply guides must not feed measured heights back into layout')
assert.ok(!panel.includes('updateChildGuideHeight'), 'nested hot reply guides must not use onAreaChange height feedback')
assert.ok(!panel.includes('.height(ThemeConstants.SPACE_XL)'), 'nested hot reply guide lines must not use a fixed short height')
mustInclude(panel, "$r('app.string.hot_replies_header_format')", 'panel title must use i18n resource')
assert.ok(!panel.includes('thresholdText'), 'panel header must not show the high-reply threshold')
assert.ok(!panel.includes('hot_replies_threshold_format'), 'panel must not keep a threshold label resource')

mustInclude(replyCard, '@Event onFloorClick?: (reply: V2exReply) => void;', 'ReplyCard must expose an optional floor click event')
mustInclude(replyCard, 'onFloorClick: this.onFloorClick', 'ReplyCard must pass floor clicks to its header')
mustInclude(replyCard, '@Param childAvatarVisible: boolean = true;', 'ReplyCard must own child avatar simplification as a reusable thread option')
mustInclude(replyCard, 'showAvatar: this.childAvatarVisible', 'ReplyCard must apply child avatar visibility to nested reply headers')
mustInclude(replyCard, '@Param childRepliesExpandable: boolean = false;', 'ReplyCard must expose optional child-reply collapse controls without changing normal replies')
mustInclude(replyCard, '@Param childRepliesExpanded: boolean = true;', 'ReplyCard must accept externally cached child-reply expanded state')
mustInclude(replyCard, '@Local private childRepliesExpandedState: boolean = true;', 'ReplyCard must mirror child-reply expanded state locally for animation')
mustInclude(replyCard, "@Monitor('childRepliesExpanded')", 'ReplyCard must react when cached child-reply expanded state changes')
mustInclude(replyCard, '@Event onChildRepliesExpandedChange?: (reply: V2exReply, expanded: boolean) => void;', 'ReplyCard must expose child-reply expanded changes to its owner')
mustInclude(replyCard, 'private toggleChildReplies(): void', 'ReplyCard must own child-reply collapse state')
mustInclude(replyCard, '@Builder\n  private ChildRepliesToggle()', 'ReplyCard must render child-reply collapse through a reusable builder')
mustAppearInOrder(
  replyCard,
  ['TimeAgo({ timestamp: this.reply.created })', 'this.ChildRepliesToggle()', 'Blank()'],
  'non-compact child-reply toggle must sit on the action row after the timestamp',
)
mustInclude(replyCard, 'if (this.childRepliesExpandable && this.isCompact())', 'compact child-reply toggle may stay on its own row')
mustInclude(replyCard, 'childRepliesExpandable: false', 'nested ReplyCards must not show their own child-reply collapse controls')
mustInclude(replyCard, "$r('app.string.topic_replies_count')", 'child-reply toggle must reuse existing i18n reply-count text')
mustInclude(replyCardHeader, '@Event onFloorClick?: (reply: V2exReply) => void;', 'ReplyCardHeader must expose an optional floor click event')
mustInclude(replyCardHeader, 'this.onFloorClick(this.reply)', 'ReplyCardHeader floor text must call the optional floor click event')
mustInclude(replyCardHeader, '@Param showAvatar: boolean = true;', 'ReplyCardHeader must support hiding avatars without custom header forks')
mustInclude(replyCardHeader, 'if (this.showAvatar) {', 'ReplyCardHeader must guard only the avatar region')

for (const locale of ['base', 'en_US', 'zh_CN', 'zh_TW', 'zh_HK', 'ja_JP', 'ko_KR']) {
  const strings = read(`entry/src/main/resources/${locale}/element/string.json`)
  for (const key of [
    'hot_replies',
    'hot_replies_child_replies_expanded',
    'hot_replies_count',
    'hot_replies_min_thanks',
    'hot_replies_count_format',
    'hot_replies_min_thanks_format',
    'hot_replies_header_format',
  ]) {
    mustInclude(strings, `"name": "${key}"`, `${locale} must define ${key}`)
  }
}

console.log('PASS hot replies static contract')
