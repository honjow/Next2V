#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const page = readFileSync('feature/detail/src/main/ets/pages/TopicDetailPage.ets', 'utf8')

function methodBody(source, name) {
  const marker = `private ${name}(`
  const start = source.indexOf(marker)
  assert.ok(start >= 0, `${name} method missing`)
  const brace = source.indexOf('{', start)
  assert.ok(brace >= 0, `${name} method body missing`)
  let depth = 0
  for (let i = brace; i < source.length; i++) {
    if (source[i] === '{') {
      depth += 1
    } else if (source[i] === '}') {
      depth -= 1
      if (depth === 0) {
        return source.slice(brace + 1, i)
      }
    }
  }
  assert.fail(`${name} method body did not close`)
}

function blockAfter(source, marker) {
  const start = source.indexOf(marker)
  assert.ok(start >= 0, `${marker} block missing`)
  const brace = source.indexOf('{', start)
  assert.ok(brace >= 0, `${marker} block body missing`)
  let depth = 0
  for (let i = brace; i < source.length; i++) {
    if (source[i] === '{') {
      depth += 1
    } else if (source[i] === '}') {
      depth -= 1
      if (depth === 0) {
        return source.slice(brace + 1, i)
      }
    }
  }
  assert.fail(`${marker} block did not close`)
}

function assertNoSuccessToast(method, successMarker, label) {
  const success = blockAfter(method, successMarker)
  assert.doesNotMatch(success, /openToast/, `${label} success path must not toast`)
}

function assertFailureToastAfterRollback(method, catchMarker, rollbackMarkers, label) {
  const failure = blockAfter(method, catchMarker)
  let lastRollbackIndex = -1
  for (const marker of rollbackMarkers) {
    const index = failure.indexOf(marker)
    assert.ok(index >= 0, `${label} failure rollback missing: ${marker}`)
    lastRollbackIndex = Math.max(lastRollbackIndex, index)
  }
  const toastIndex = failure.indexOf('openToast')
  assert.ok(toastIndex > lastRollbackIndex, `${label} failure toast must remain after rollback`)
  assert.match(failure, /translateApiError\(error\)/, `${label} failure toast must translate API error`)
}

const favorite = methodBody(page, 'prepareSiteFavoriteToggle')
assertNoSuccessToast(favorite, '.then((favorited: boolean) =>', 'topic favorite/unfavorite')
assertFailureToastAfterRollback(
  favorite,
  '.catch((error: Error) =>',
  [
    'this.isSiteFavorited = previousIsSiteFavorited',
    'this.topicDetailSiteFavorited = previousTopicDetailSiteFavorited',
  ],
  'topic favorite/unfavorite',
)

const topicThank = methodBody(page, 'executeTopicThank')
assert.match(topicThank, /const previousIsTopicThanked = this\.isTopicThanked/)
assert.match(topicThank, /const previousTopicDetailThanked = this\.topicDetailThanked/)
const topicOptimisticIndex = topicThank.indexOf('this.isTopicThanked = true')
const topicNetworkIndex = topicThank.indexOf('.executeTopicThank(this.api, cookie, this.topicId)')
assert.ok(topicOptimisticIndex >= 0 && topicOptimisticIndex < topicNetworkIndex, 'topic thank must optimistically update before API call')
assert.match(topicThank, /this\.topicDetailThanked = true[\s\S]*TopicDetailActionCoordinator/, 'topic thank must optimistically update detail state before API call')
assertNoSuccessToast(topicThank, '.then(() =>', 'topic thank')
assertFailureToastAfterRollback(
  topicThank,
  '.catch((error: Error) =>',
  [
    'this.isTopicThanked = previousIsTopicThanked',
    'this.topicDetailThanked = previousTopicDetailThanked',
  ],
  'topic thank',
)

const replyThank = methodBody(page, 'executeReplyThank')
const replyOptimisticIndex = replyThank.indexOf('this.v.optimisticallyMarkReplyThanked(reply.id)')
const replyNetworkIndex = replyThank.indexOf('.executeReplyThank(this.api, cookie, this.topicId, reply.id)')
assert.ok(replyOptimisticIndex >= 0 && replyOptimisticIndex < replyNetworkIndex, 'reply thank must keep optimistic update before API call')
assertNoSuccessToast(replyThank, '.then(() =>', 'reply thank')
assertFailureToastAfterRollback(
  replyThank,
  '.catch((error: Error) =>',
  [
    'this.v.rollbackReplyThank(replyThankSnapshot)',
    'TopicDetailActionCoordinator.rollbackReplyThankedIds',
  ],
  'reply thank',
)

const confirmTopicThank = methodBody(page, 'confirmTopicThank')
assert.match(confirmTopicThank, /showAlertDialog/, 'topic thank confirmation dialog must remain')
assert.match(confirmTopicThank, /this\.executeTopicThank\(cookie\)/, 'topic thank confirmation must execute confirmed action')

console.log('PASS: low-intrusion optimistic action toast/rollback contract')
