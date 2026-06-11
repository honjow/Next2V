#!/usr/bin/env node
// Contract for the notification anchor self-check + content re-location.
// V2EX stamps thanks/mention notifications with a #reply{N} anchor that is sometimes wrong
// (two notifications for the SAME reply can carry different floors). The detail page trusts
// the anchor only when the reply sitting there matches the notification's reply text, and
// otherwise re-locates by content. This test ports ReplyFingerprint + verifiedFloor and runs
// them on the REAL data from topic 1219329 (cocong anchor=#reply32 wrong, lvcp anchor=#reply26
// right, both thanking the same reply at floor 26), then asserts the production wiring exists.

import { readFileSync } from 'node:fs'

// --- ports of the production logic ----------------------------------------
function decodeHtmlEntities(value) {
  if (!value) return ''
  let s = value
  for (let i = 0; i < 2; i++) {
    const next = s
      .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&apos;/g, "'")
      .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&nbsp;/g, ' ').replace(/&#160;/g, ' ').replace(/&amp;/g, '&')
    if (next === s) break
    s = next
  }
  return s
}

const MIN_FP = 4
function normalize(value) {
  let s = value || ''
  s = s.replace(/<[^>]+>/g, ' ')
  s = decodeHtmlEntities(s)
  s = s.replace(/^\s*@\s*[0-9A-Za-z_]+\s*#\s*\d+\s*/i, ' ')
  s = s.replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
  s = s.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
  s = s.replace(/https?:\/\/[^\s)]+/gi, ' ')
  s = s.replace(/\s+/g, '')
  return s.toLowerCase()
}
function matches(a, b) {
  const na = normalize(a), nb = normalize(b)
  if (!na || !nb) return false
  if (na.length < MIN_FP || nb.length < MIN_FP) return na === nb
  return na.indexOf(nb) >= 0 || nb.indexOf(na) >= 0
}
function verifiedFloor(targetFloor, verifyReplyText, replies) {
  const verify = (verifyReplyText || '').trim()
  if (!verify || !replies || replies.length === 0) return targetFloor
  if (targetFloor > 0) {
    for (const row of replies) {
      if (row && (row.floor || 0) === targetFloor) {
        if (matches(row.content || row.content_rendered || '', verify)) return targetFloor
        break
      }
    }
  }
  for (const row of replies) {
    if (row && matches(row.content || row.content_rendered || '', verify)) {
      const f = row.floor || 0
      if (f > 0) return f
    }
  }
  return targetFloor
}

// --- real-data scenario ---------------------------------------------------
// My reply is floor 26; floor 32 is an unrelated reply. Notification reply text is the
// compactText form V2EX hands us (mention rendered as "@ Justin13", trailing image -> "图片").
const MY_REPLY_MD = '@Justin13 #3 AI 用久了把 ai 当成自己的能力了 ![](https://i.imgur.com/x.png)'
const NOTIF_REPLY_TEXT = '@ Justin13 #3 AI 用久了把 ai 当成自己的能力了 图片'
const USER_REPLY_PREVIEW_TEXT = '@pz886 #9 换个说法，就是谷歌的那个验证码 '
const replies = [
  { floor: 3, content: '上面的两个人答非所问啊\n别人问难不难？' },
  { floor: 26, content: MY_REPLY_MD },
  { floor: 27, content: 'AI 会了，等于他会了，招笑来的' },
  { floor: 29, content: '只能说现在的应试教育是折磨人' },
  { floor: 32, content: '试卷：小学毕业就可以了，送快递有导航' },
]

const cases = [
  { name: 'lvcp: correct anchor 26 is honored', target: 26, verify: NOTIF_REPLY_TEXT, expect: 26 },
  { name: 'cocong: wrong anchor 32 is repaired to 26 by content', target: 32, verify: NOTIF_REPLY_TEXT, expect: 26 },
  { name: 'no verify text -> anchor untouched', target: 32, verify: '', expect: 32 },
  { name: 'unmatched text -> falls back to anchor', target: 9, verify: '完全不相关的别的回复内容xyz', expect: 9 },
  { name: 'anchor floor not loaded but content present -> relocates', target: 99, verify: NOTIF_REPLY_TEXT, expect: 26 },
  { name: 'no anchor but content present -> locates by text', target: 0, verify: NOTIF_REPLY_TEXT, expect: 26 },
  { name: 'user reply preview prefix is ignored when locating own reply', target: 9, verify: USER_REPLY_PREVIEW_TEXT, expect: 47 },
]
replies.push({ floor: 47, content: '换个说法，就是谷歌的那个验证码' })
for (const c of cases) {
  const got = verifiedFloor(c.target, c.verify, replies)
  if (got !== c.expect) {
    console.error(`FAIL: ${c.name}\n  expected floor ${c.expect}, got ${got}`)
    process.exit(1)
  }
}

// fingerprint must equate the notification text and the markdown reply despite @-spacing + image
if (!matches(MY_REPLY_MD, NOTIF_REPLY_TEXT)) {
  console.error('FAIL: fingerprint should match notification text to the markdown reply')
  process.exit(1)
}
// and must NOT match an unrelated reply
if (matches(replies[4].content, NOTIF_REPLY_TEXT)) {
  console.error('FAIL: fingerprint must not match the unrelated floor-32 reply')
  process.exit(1)
}

// --- production wiring coverage -------------------------------------------
function assertContains(file, needle, label) {
  const src = readFileSync(new URL(`../${file}`, import.meta.url), 'utf8')
  if (!src.includes(needle)) {
    console.error(`FAIL: wiring missing: ${label}\n  expected: ${needle}\n  file: ${file}`)
    process.exit(1)
  }
}
assertContains('shared/src/main/ets/model/RouteParams.ets', 'verifyReplyText?: string', 'TopicDetailParams.verifyReplyText')
assertContains('entry/src/main/ets/model/NotificationPageCoordinator.ets', 'verifyReplyText: verify', 'notification routeParams carries verifyReplyText')
assertContains('entry/src/main/ets/model/IndexRouteCoordinator.ets', "stringParam(param, 'verifyReplyText')", 'descriptor rebuild keeps verifyReplyText')
assertContains('entry/src/main/ets/model/IndexRouteCoordinator.ets', 'if (verifyReplyText.trim().length > 0)', 'descriptor rebuild keeps text-only reply targets')
assertContains('entry/src/main/ets/pages/Index.ets', 'verifyReplyText: descriptor.topicDetailParams.verifyReplyText', 'TopicDetailPage receives verifyReplyText')
assertContains('feature/detail/src/main/ets/model/TopicDetailScrollCoordinator.ets', 'static verifiedFloor(', 'verifiedFloor exists')
assertContains('feature/detail/src/main/ets/pages/TopicDetailPage.ets', 'TopicDetailScrollCoordinator.verifiedFloor(', 'jumpToTargetFloor uses verifiedFloor')
assertContains('feature/detail/src/main/ets/pages/TopicDetailPage.ets', 'private jumpToTargetReplyText()', 'text-only reply targets are located by content')
assertContains('shared/src/main/ets/utils/ReplyFingerprint.ets', "replace(/^\\s*@\\s*[0-9A-Za-z_]+\\s*#\\s*\\d+\\s*/i", 'reply fingerprint strips leading user-reply reference prefixes')

console.log(`PASS: ${cases.length} verifiedFloor cases + fingerprint match/anti-match + 9 production wiring assertions`)
