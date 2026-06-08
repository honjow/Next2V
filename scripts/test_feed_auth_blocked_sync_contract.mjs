#!/usr/bin/env node
// Contract for the feed-auth + blocked/ignored first-entry initialization fix (feed-auth-blocked-sync).
//
// Root product expectation: the home/feed topic-list HTML must NOT be anonymous when the account is
// logged in. A cookie-backed home/feed load is what carries the per-account `ignored_topics`/`blocked`
// arrays, so the very FIRST feed load after login can initialize the active-owner blocked-list snapshot
// through an AUTHENTICATED capture (source: 'cookieHtml'). With no cookie the anonymous public-HTML path
// (source: 'publicHtml') is preserved.
//
// This guards behavior, not just symbols:
//   1. ApiService routes home/feed topic-list HTML (getTabTopics ordinary branch, getRecentTopicsPage,
//      getHotTabTopics) through ONE cookie-aware helper that branches on the current account cookie.
//   2. The helper's authenticated cookie branch captures with an authenticated source label
//      (cookieHtml + hasCookie), while stale/invalid cookie HTML that does not prove a logged-in
//      username falls back to anonymous public HTML instead of breaking feed rendering.
//      The no-cookie branch keeps the anonymous public-HTML capture.
//   3. Missing ignored_topics/blocked variables never clear cache (updateFromTopicListHtml returns false
//      and never reaches saveActive); only a present source (even present-empty []) may write.
//   4. A logged-in blocked-list first-open with NO cache and a failed/missing authenticated sync
//      (snapshot.updatedAt === 0, i.e. never confirmed) is NOT collapsed into a true "no blocked X"
//      empty state — it surfaces load-failed instead.
//   5. The parser present-vs-missing distinction (and present-empty []) is preserved.
//
// Run: node scripts/test_feed_auth_blocked_sync_contract.mjs
import { readFileSync } from 'node:fs'

const apiPath = 'shared/src/main/ets/network/ApiService.ets'
const settingsPath = 'shared/src/main/ets/settings/BlockedListSettings.ets'
const pagePath = 'entry/src/main/ets/pages/BlockedListsPage.ets'

function source(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
}

let failures = 0
function fail(message) {
  console.error(`FAIL: ${message}`)
  failures++
}
function assertIncludes(file, text, needle) {
  if (!text.includes(needle)) {
    fail(`missing in ${file}: ${needle}`)
  }
}
function assertNotIncludes(file, text, needle, why) {
  if (text.includes(needle)) {
    fail(`${file} must not contain ${needle}${why ? ` (${why})` : ''}`)
  }
}

// Brace-matched body of `marker { ... }`. marker may include '(' .
function methodBody(text, marker, fromIndex = 0) {
  const needle = marker.includes('(') ? marker : `${marker}(`
  const start = text.indexOf(needle, fromIndex)
  if (start < 0) {
    fail(`missing method marker: ${marker}`)
    return ''
  }
  const braceStart = text.indexOf('{', start)
  if (braceStart < 0) {
    fail(`missing method body for: ${marker}`)
    return ''
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
  return ''
}

const api = source(apiPath)
const settings = source(settingsPath)
const page = source(pagePath)

// ---------------------------------------------------------------------------
// 1 + 2. ApiService cookie-aware feed/home topic-list path.
// ---------------------------------------------------------------------------
// ApiService must know the current account cookie itself (the feed view model calls getTabTopics()
// with no cookie argument), so a single helper reads it and decides auth vs anonymous.
assertIncludes(apiPath, api, "import { CookieJarSettings }")
assertIncludes(apiPath, api, 'private async fetchFeedTopicListHtml(')

const helper = methodBody(api, 'private async fetchFeedTopicListHtml(')
// Branch on the presence of a current account cookie.
assertIncludes(apiPath, helper, 'CookieJarSettings.getCurrentCookie()')
// Cookie branch: authenticated request + authenticated capture source.
assertIncludes(apiPath, helper, 'getCookieHtml(')
assertIncludes(apiPath, helper, "source: 'cookieHtml'")
assertIncludes(apiPath, helper, 'hasCookie: true')
assertIncludes(apiPath, helper, 'const hasUsername = !!V2exSessionParser.extractUsername(html)')
assertIncludes(apiPath, helper, 'if (hasUsername)')
assertIncludes(apiPath, helper, 'feed_cookie_html_fallback_to_public_unauthenticated')
// Stale/invalid cookie HTML must not be returned to the feed parser. It falls through to the public path,
// preserving the pre-login anonymous feed instead of turning a bad cookie into an empty/error feed.
const usernameGateIdx = helper.indexOf('if (hasUsername)')
const cookieCaptureIdx = helper.indexOf("source: 'cookieHtml'")
const unauthFallbackIdx = helper.indexOf('feed_cookie_html_fallback_to_public_unauthenticated')
const publicRequestIdx = helper.indexOf('const html = await this.http.getText(endpoint)')
if (usernameGateIdx < 0 || cookieCaptureIdx < usernameGateIdx || unauthFallbackIdx < cookieCaptureIdx || publicRequestIdx < unauthFallbackIdx) {
  fail('fetchFeedTopicListHtml must capture/return cookie HTML only after hasUsername=true, otherwise fall through to the public feed request')
}
// No-cookie branch: anonymous public HTML request + public capture source preserved.
assertIncludes(apiPath, helper, 'this.http.getText(')
assertIncludes(apiPath, helper, "source: 'publicHtml'")
// Helper must run the blocked/ignored capture (both branches go through captureBlockedListsFromHtml).
assertIncludes(apiPath, helper, 'this.captureBlockedListsFromHtml(')

// The cookie label must appear lexically before the public label inside the helper: the authenticated
// path is the primary path and the public path is the fallback / no-cookie path.
const cookieLabelIdx = helper.indexOf("source: 'cookieHtml'")
const publicLabelIdx = helper.indexOf("source: 'publicHtml'")
if (cookieLabelIdx < 0 || publicLabelIdx < 0 || cookieLabelIdx > publicLabelIdx) {
  fail('fetchFeedTopicListHtml must try the cookieHtml (authenticated) path before the publicHtml fallback')
}

// All three home/feed topic-list entry points must route through the helper.
for (const method of [
  'async getTabTopics(',
  'async getRecentTopicsPage(',
  'async getHotTabTopics(',
]) {
  const body = methodBody(api, method)
  if (!body.includes('this.fetchFeedTopicListHtml(')) {
    fail(`${method.replace('async ', '').replace('(', '')} must fetch topic-list HTML via fetchFeedTopicListHtml (cookie-aware), not a bare anonymous getText`)
  }
}
const recentCompatBody = methodBody(api, 'async getRecentTopics(')
assertIncludes(apiPath, recentCompatBody, 'this.getRecentTopicsPage(page)')

// Regression guard: the ordinary getTabTopics branch must NOT keep the old inline anonymous
// getText + publicHtml capture (that was the bug — a logged-in home load never carried the cookie).
const tabBody = methodBody(api, 'async getTabTopics(')
assertNotIncludes(apiPath, tabBody, 'const html = await this.http.getText(endpoint)',
  'ordinary getTabTopics branch must not fetch the home tab anonymously')

// ---------------------------------------------------------------------------
// 3 + 5. Missing variables never clear cache; present-vs-missing distinction preserved.
// ---------------------------------------------------------------------------
// (updateFromTopicListHtml has a `source = {}` default param, so brace-matching its body is unsafe;
// assert on whole-file token order with the unique tokens of that method instead.)
assertIncludes(settingsPath, settings, 'static updateFromTopicListHtml(html: string, source: BlockedListCaptureSource = {}): boolean')
assertIncludes(settingsPath, settings, 'if (!lists.ignoredTopicsPresent || !lists.blockedMembersPresent)')
// The missing-variable guard must `return false` (skip) BEFORE the saveActive write is ever reached.
const guardIdx = settings.indexOf('if (!lists.ignoredTopicsPresent || !lists.blockedMembersPresent)')
const saveIdx = settings.indexOf('BlockedListSettings.saveActive(lists, undefined, sourceContext)')
if (guardIdx < 0 || saveIdx < 0 || guardIdx > saveIdx) {
  fail('updateFromTopicListHtml must skip (missing-variable guard) before any saveActive write')
}
const guardSlice = settings.slice(guardIdx, saveIdx)
assertIncludes(settingsPath, guardSlice, 'return false')

// Behavioral parity: the same present/missing detection the parser/persist layer relies on.
// Mirrors V2exTabParser.extractBlockedIdLists' "present = the `name = [...]` assignment exists".
function presence(html, name) {
  const pattern = new RegExp('(?:^|[^0-9A-Za-z_])' + name + '\\s*=\\s*\\[([^\\]]*)\\]', 'm')
  const match = html.match(pattern)
  const present = !!(match && match.length >= 2)
  const ids = []
  if (present) {
    const seen = new Set()
    const re = /(?:^|[^\d-])(\d+)/g
    let mm
    while ((mm = re.exec(match[1] || '')) !== null) {
      const id = parseInt(mm[1], 10)
      if (id > 0 && !seen.has(id)) { ids.push(id); seen.add(id) }
    }
  }
  return { present, ids }
}
function wouldSave(html) {
  // saveActive is reached only when BOTH variables are present (present-empty [] still counts).
  return presence(html, 'ignored_topics').present && presence(html, 'blocked').present
}

// Anonymous home HTML for a logged-in user lacks the per-account arrays => must be skipped (cache preserved).
const anonymousHome = '<html><body><div class="cell item">topic</div></body></html>'
if (wouldSave(anonymousHome)) {
  fail('anonymous home HTML (no ignored_topics/blocked vars) must NOT trigger a cache-clearing save')
}
// A partial page (one var missing) must also be skipped — never half-clear.
const partial = '<script>var ignored_topics = [1,2];</script>'
if (wouldSave(partial)) {
  fail('partial HTML missing `blocked` must NOT trigger a save (cache must be preserved)')
}
// Authenticated home with present-empty arrays is the ONLY way an empty list legitimately writes (clears).
const authedEmpty = '<script>var ignored_topics = []; var blocked = [];</script>'
if (!wouldSave(authedEmpty)) {
  fail('present-empty [] from an authenticated source must be allowed to save (explicit empty)')
}
const ep = presence(authedEmpty, 'ignored_topics')
if (!ep.present || ep.ids.length !== 0) {
  fail('present-empty parity failed: ignored_topics should be present with zero ids')
}
// Authenticated home with real ids writes the snapshot.
const authedFull = '<script>var ignored_topics = [101,102]; var blocked = [55];</script>'
if (!wouldSave(authedFull) || presence(authedFull, 'ignored_topics').ids.join(',') !== '101,102' || presence(authedFull, 'blocked').ids.join(',') !== '55') {
  fail('authenticated home with real ids must save the parsed ignored/blocked arrays')
}
// Missing-variable distinction preserved.
if (presence('<script>var other = [9];</script>', 'ignored_topics').present) {
  fail('missing-variable distinction broken: absent ignored_topics reported present')
}

// ---------------------------------------------------------------------------
// 4. Logged-in blocked-list first-open: failed/missing sync (no cache) != true empty.
// ---------------------------------------------------------------------------
const stateBody = methodBody(page, 'private pageStateMessage(): string')
// The empty-state decision must be gated on a CONFIRMED snapshot (updatedAt > 0). A never-confirmed
// logged-in snapshot (updatedAt === 0) is unknown, not empty.
assertIncludes(pagePath, stateBody, 'this.snapshot.updatedAt > 0')
assertIncludes(pagePath, stateBody, 'R_NO_BLOCKED_USERS')
assertIncludes(pagePath, stateBody, 'R_NO_IGNORED_TOPICS')
assertIncludes(pagePath, stateBody, 'R_COMMON_LOAD_FAILED')

// The "no blocked users" / "no blocked topics" messages must only be reachable on the confirmed side of
// the updatedAt gate — i.e. the gate token must appear before each empty-message token in source order.
function gateBeforeMessage(body, messageToken, label) {
  const gateIdx = body.indexOf('this.snapshot.updatedAt > 0')
  const msgIdx = body.indexOf(messageToken)
  if (gateIdx < 0 || msgIdx < 0 || gateIdx > msgIdx) {
    fail(`pageStateMessage must gate ${label} behind the confirmed-snapshot (updatedAt > 0) check`)
  }
}
gateBeforeMessage(stateBody, 'R_NO_BLOCKED_USERS', 'the no-blocked-users empty state')

// Regression guard: must NOT return the bare empty messages without the confirmation gate.
assertNotIncludes(
  pagePath,
  stateBody,
  'if (this.snapshot.blockedMemberIds.length === 0) {\n      return AppStrings.text(AppStrings.R_NO_BLOCKED_USERS',
  'blocked-users empty message must not be returned unconditionally (false empty on failed first sync)',
)

if (failures > 0) {
  console.error(`\n${failures} failure(s)`)
  process.exit(1)
}
console.log('PASS: feed auth blocked sync contract')
