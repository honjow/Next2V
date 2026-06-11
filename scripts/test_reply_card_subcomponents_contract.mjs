#!/usr/bin/env node
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(path, 'utf8')

const replyCard = read('shared/src/main/ets/components/ReplyCard.ets')
const header = read('shared/src/main/ets/components/reply/ReplyCardHeader.ets')
const actions = read('shared/src/main/ets/components/reply/ReplyCardActions.ets')
const layout = read('shared/src/main/ets/components/reply/ReplyCardLayoutPolicy.ets')

assert.match(replyCard, /export\s+struct\s+ReplyCard\b/)

for (const name of [
  'reply',
  'floor',
  'isOp',
  'isThanked',
  'isThankPending',
  'threadLevel',
  'relationLabel',
  'displayContent',
  'isWrongReference',
  'isDuplicateThreadItem',
  'childReplies',
  'embedded',
  'opMemberId',
  'hideLeadingMention',
  'onUserClick',
  'onActionsClick',
  'onContextClick',
  'onMentionClick',
  'onReplyClick',
  'onThankClick',
  'onIgnoreClick',
  'onReportClick',
  'onCopyUserClick',
  'onCopyContentClick',
  'isReplyThanked',
  'isReplyThankPending',
  'onImageClick',
  'onLinkClick',
  'onMentionUserClick',
]) {
  assert.match(replyCard, new RegExp(`\\b${name}\\b`), `ReplyCard public field/callback missing: ${name}`)
}

const displayIndex = replyCard.indexOf('this.displayContent')
const renderedIndex = replyCard.indexOf('this.reply.content_rendered')
const contentIndex = replyCard.indexOf('return this.reply.content')
assert.ok(displayIndex >= 0 && renderedIndex > displayIndex, 'displayContent must be preferred first')
assert.ok(contentIndex > renderedIndex, 'content_rendered must be preferred before content fallback')

assert.match(replyCard, /hiddenLeadingMentionContent/)
assert.match(replyCard, /hiddenLeadingMentionRenderedContent/)
assert.match(replyCard, /return reply\.hiddenLeadingMentionRenderedContent \|\| ''/)
assert.match(replyCard, /replyUsers/)
assert.match(replyCard, /startsWithMention\(content,\s*first\)/)
assert.match(replyCard, /threadChildren\s*\|\|\s*\[\]/)
assert.match(replyCard, /embedded:\s*true/)
assert.match(replyCard, /Color\.Transparent/)
assert.match(replyCard, /opMemberId > 0 && child\.member\.id === this\.opMemberId/)
assert.match(replyCard, /isWrongReference:\s*!!child\.isWrongReference/)
assert.match(replyCard, /isDuplicateThreadItem:\s*!!child\.isDuplicateThreadItem/)

assert.match(replyCard, /replyCardStyle === 'compact'/)
assert.match(replyCard, /if \(!this\.isCompact\(\)\)/)
assert.match(header, /if \(this\.isCompact\)/)
assert.match(header, /TimeAgo\(\{ timestamp: this\.reply\.created \}\)/)
assert.match(header, /ReplyCardActions\(\{/)

for (const literal of [
  'PADDING_TOP: number = 12',
  'PADDING_BOTTOM: number = 12',
  'PADDING_LEFT: number = 16',
  'PADDING_RIGHT: number = 16',
  'PADDING_LEFT_EMBEDDED: number = 8',
  'PADDING_LEFT_DEEP: number = 8',
  'CONTENT_GAP: number = 8',
  'ACTIONS_GAP: number = 0',
  'CHILD_DIVIDER_MARGIN: number = 8',
  'COMPACT_CHILD_REPLY_GAP: number = 8',
]) {
  assert.ok(layout.includes(literal), `layout policy value changed/missing: ${literal}`)
}

assert.match(replyCard, /private childReplyBottomGap\(index: number\): number/)
assert.match(replyCard, /!this\.isCompact\(\) \|\| index >= this\.childReplies\.length - 1/)
assert.match(replyCard, /private childReplyListTopGap\(\): number/)
assert.match(replyCard, /!this\.isCompact\(\) \|\| this\.childReplies\.length === 0/)
assert.match(replyCard, /ReplyCardLayoutPolicy\.COMPACT_CHILD_REPLY_GAP/)
assert.match(replyCard, /Blank\(\)[\s\S]*\.height\(this\.childReplyBottomGap\(index\)\)/)
assert.match(replyCard, /\.margin\(\{ top: this\.childReplyListTopGap\(\) \}\)/)

// Menu labels are i18n resources (AppStrings.text fallbacks / $r keys), not hardcoded Chinese.
for (const label of [
  'View context',
  'app.string.common_copy_username',
  'Copy reply content',
  'Ignore reply',
  'Report reply',
]) {
  assert.ok(actions.includes(label), `context menu label missing: ${label}`)
}
for (const symbol of [
  'sys.symbol.ellipsis_bubble',
  'sys.symbol.person',
  'sys.symbol.doc_plaintext',
  'sys.symbol.xmark',
  'sys.symbol.exclamationmark_triangle',
  'sys.symbol.dot_grid_2x2',
  'sys.symbol.heart_fill',
  'sys.symbol.heart',
  'sys.symbol.arrowshape_turn_up_left',
]) {
  assert.ok(actions.includes(symbol), `reply action symbol missing: ${symbol}`)
}
assert.match(actions, /setTimeout\(\(\) => \{[\s\S]*action\(this\.reply\)[\s\S]*\},\s*80\)/)
assert.doesNotMatch(actions, /\.(?:enabled|opacity)\([^)]*isThankPending[^)]*\)/)
assert.match(actions, /this\.onThankClick && !this\.isThankPending/)
assert.match(actions, /if \(this\.menuHasItems\(\)\)/)
assert.match(actions, /else if \(this\.onActionsClick\)/)

// Adaptive compact header: the header stacks the timestamp under the username and collapses the three
// inline action buttons into a single overflow menu (thank + reply prepended so nothing is lost) ONLY
// when the measured header cannot fit the fixed chrome plus a usable meta column. Username/mark content
// is handled by flex wrap/shrink, not by an over-conservative text-width gate.
assert.doesNotMatch(layout, /COMPACT_HEADER_STACK_WIDTH/, 'must NOT use a fixed screen-width threshold')
assert.match(layout, /static estTextWidth\(text: string, fontSizeVp: number\): number/, 'layout must estimate text width for the fit check')
assert.match(layout, /static compactHeaderStacked\(/, 'layout must expose compactHeaderStacked()')
assert.match(layout, /availableWidth: number,/, 'fit check takes the available width')
assert.match(layout, /floor: number,/, 'fit check accounts for floor label width')
assert.match(layout, /showAvatar: boolean,/, 'fit check accounts for avatar presence')
assert.match(layout, /thanks: number,/, 'fit check accounts for thank-count width')
assert.match(layout, /HEADER_MIN_META_VP/, 'fit check must preserve a usable compact meta column')
assert.match(layout, /thankButtonExtraWidth\(thanks: number\)/, 'fit check must estimate extra thank-count width')
assert.doesNotMatch(layout, /HEADER_INLINE_FIXED_VP/, 'fit check must not use the old over-conservative fixed budget')
assert.doesNotMatch(layout, /HEADER_USERNAME_FONT_VP/, 'fit check must not force collapse from username length')
assert.match(replyCard, /private isHeaderNarrow\(\): boolean/, 'ReplyCard must compute isHeaderNarrow()')
assert.match(replyCard, /private headerAvailableWidth\(\): number/, 'ReplyCard must compute the header available width')
assert.match(
  replyCard,
  /compactHeaderStacked\(\s*this\.headerAvailableWidth\(\),\s*this\.floor,\s*this\.showAvatar,\s*this\.reply\.thanks \|\| 0,/,
  'isHeaderNarrow must pass measured width plus real fixed chrome inputs into the fit check',
)
assert.match(replyCard, /isNarrow:\s*this\.isHeaderNarrow\(\)/, 'ReplyCard must pass isNarrow into the header')
assert.match(header, /@Param isNarrow: boolean/, 'header must accept isNarrow')
// The compact header stacks the timestamp under the username by wrapping the meta row (FlexWrap.Wrap
// in CompactMeta) instead of a fixed isNarrow width-threshold branch; narrowness now only collapses
// the action cluster (collapsed: this.isNarrow below).
assert.match(header, /CompactMeta\(\)\s*\{\s*Flex\(\{[\s\S]*wrap: FlexWrap\.Wrap[\s\S]*TimeAgo\(\{ timestamp: this\.reply\.created \}\)/, 'compact header must stack the timestamp via a wrapping meta row')
assert.match(header, /if \(this\.isCompact\) \{\s*Column\(\)\s*\{\s*this\.CompactMeta\(\)/, 'compact header renders the wrapping CompactMeta')
assert.match(header, /collapsed:\s*this\.isNarrow/, 'header must collapse actions when narrow')
assert.match(actions, /@Param collapsed: boolean/, 'actions must accept collapsed')
assert.match(actions, /private menuHasItems\(\): boolean/, 'actions must define menuHasItems()')
assert.match(actions, /if \(this\.collapsed\)/, 'collapsed actions render only the overflow menu')
assert.match(actions, /this\.collapsed && this\.onThankClick/, 'collapsed menu must include thank')
assert.match(actions, /this\.collapsed && this\.onReplyClick/, 'collapsed menu must include reply')

const changed = execFileSync('git', ['diff', '--name-only'], { encoding: 'utf8' })
  .split('\n')
  .filter(Boolean)
assert.ok(
  changed.every((file) => !file.startsWith('shared/src/main/ets/settings/')),
  'settings files must not be edited',
)
assert.ok(
  changed.every((file) => file !== 'shared/src/main/ets/constants/StorageKeys.ets'),
  'StorageKeys.REPLY_CARD_STYLE must not be edited',
)

console.log('PASS reply card subcomponents static contract')
