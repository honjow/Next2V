#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()
const topicDetailPath = path.join(repo, 'feature/detail/src/main/ets/pages/TopicDetailPage.ets')
const source = fs.readFileSync(topicDetailPath, 'utf8')

function fail(message) {
  console.error(`FAIL: ${message}`)
  process.exit(1)
}

function assertContains(haystack, needle, message) {
  if (!haystack.includes(needle)) {
    fail(message)
  }
}

function assertNotContains(haystack, needle, message) {
  if (haystack.includes(needle)) {
    fail(message)
  }
}

assertNotContains(source, 'confirmSiteFavoriteToggle', 'topic site favorite confirmation method/path must not remain')
assertNotContains(source, "topic_action_site_favorite'), 'Site favorite'),\n      message: TopicDetailActionCoordinator.topicFavoriteMessage", 'topic site favorite must not show a confirmation dialog')

const methodMatch = source.match(/private prepareSiteFavoriteToggle\(\): void \{[\s\S]*?\n  \}\n\n  private loadSiteFavoriteState\(\): void \{/)
if (!methodMatch) {
  fail('prepareSiteFavoriteToggle method block not found')
}
const method = methodMatch[0]

assertContains(method, 'if (this.isSiteFavoriteLoading)', 'duplicate request guard missing')
assertContains(method, 'const previousIsSiteFavorited = this.isSiteFavorited', 'must snapshot previous component favorite state')
// The appbar/storage favorite state migrated from a directly-assigned `this.topicDetailSiteFavorited`
// field to the single-writer command bus `publishTopicDetailSiteFavorited(...)`. The optimistic
// snapshot for BOTH component and appbar is now the one `previousIsSiteFavorited` captured above (they
// are mutated in lockstep), so the appbar rollback below reuses it — the invariant is unchanged.
assertContains(method, 'publishTopicDetailSiteFavorited(previousIsSiteFavorited)', 'must roll the appbar/storage favorite state back to the captured snapshot on failure')
assertContains(method, 'const targetFavorited = !this.isSiteFavorited', 'must compute optimistic target from current UI state')
assertContains(method, 'this.isSiteFavoriteLoading = true', 'must set loading guard before API call')
assertContains(method, 'this.isSiteFavorited = targetFavorited', 'must optimistically update component state')
assertContains(method, 'publishTopicDetailSiteFavorited(targetFavorited)', 'must optimistically update appbar/storage state')
assertContains(method, '.toggleTopicFavoriteWithCookie(cookie, this.topicId)', 'must run existing topic favorite API toggle call')
assertContains(method, 'this.isSiteFavorited = favorited', 'success must apply server returned favorite state to component')
assertContains(method, 'publishTopicDetailSiteFavorited(favorited)', 'success must apply server returned favorite state to appbar/storage')
const favoriteSuccessMatch = method.match(/\.then\(\(favorited: boolean\) => \{[\s\S]*?\n      \}\)/)
if (!favoriteSuccessMatch) {
  fail('favorite success block not found')
}
assertNotContains(favoriteSuccessMatch[0], 'openToast', 'favorite/unfavorite success path must not show toast')
assertContains(method, 'this.isSiteFavorited = previousIsSiteFavorited', 'failure must rollback component state')
assertContains(method, 'publishTopicDetailSiteFavorited(previousIsSiteFavorited)', 'failure must rollback appbar/storage state')
assertContains(method, 'translateApiError(error)', 'failure must show translated API error toast')

console.log('PASS: topic favorite no-dialog optimistic rollback contract')
