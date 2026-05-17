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
  'PADDING_LEFT_EMBEDDED: number = 12',
  'PADDING_LEFT_DEEP: number = 16',
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

for (const label of ['查看上下文', '复制用户名', '复制回复内容', '忽略回复', '举报回复']) {
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
assert.match(actions, /opacity\(this\.isThankPending \? 0\.45 : 1\)/)
assert.match(actions, /enabled\(!this\.isThankPending\)/)
assert.match(actions, /this\.onThankClick && !this\.isThankPending/)
assert.match(actions, /if \(this\.hasContextMenuActions\(\)\)/)
assert.match(actions, /else if \(this\.onActionsClick\)/)

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
