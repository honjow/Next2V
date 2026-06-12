#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(path, 'utf8')

const page = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
const viewModel = read('feature/detail/src/main/ets/viewmodel/DetailViewModel.ets')
const coordinator = read('feature/detail/src/main/ets/model/TopicDetailActionCoordinator.ets')
const replyCardActions = read('shared/src/main/ets/components/reply/ReplyCardActions.ets')

function methodBody(source, name) {
  const marker = `${name}(`
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

const executeBody = methodBody(page, 'executeReplyThank')
// Formatter wraps the reply.id argument onto a continuation line; match the call, not a fixed one-liner.
const optimisticIndex = executeBody.indexOf('this.v.optimisticallyMarkReplyThanked(')
const localMarkIndex = executeBody.indexOf('this.markReplyThanked(reply.id)')
const networkIndex = executeBody.indexOf('TopicDetailActionCoordinator')
assert.ok(optimisticIndex >= 0, 'reply thank must optimistically update viewmodel state')
assert.ok(localMarkIndex > optimisticIndex, 'local thanked id must be marked after viewmodel optimistic apply')
assert.ok(networkIndex > localMarkIndex, 'network action must start after optimistic apply and local mark')
// Success path stays silent (no success toast / no re-render of the list): the exact then body below
// contains ONLY persistReplyThankOverlay (which persists the thanked overlay locally so the optimistic
// state survives a cache reload) — nothing else, so there is no success toast.
assert.match(executeBody, /\.then\(\(\)\s*=>\s*\{\s*this\.persistReplyThankOverlay\(reply\.id\)\s*\}\)/, 'reply thank success path must only persist the overlay (stay silent, no success toast)')
assert.match(executeBody, /\.catch\(\(error: Error\)\s*=>\s*\{[\s\S]*this\.v\.rollbackReplyThank\(replyThankSnapshot\)[\s\S]*rollbackReplyThankedIds\(\s*thankedIdsSnapshot,\s*this\.thankedReplyIdsJson,\s*\)[\s\S]*translateApiError\(error\)/)
assert.match(executeBody, /\.finally\(\(\)\s*=>\s*\{[\s\S]*this\.isReplyThankLoading = false[\s\S]*this\.clearReplyThankLock\(\)/)
assert.doesNotMatch(executeBody, /\.then\(\(\)\s*=>\s*\{[\s\S]*markReplyThanked\(reply\.id\)/)

const thankButtonBody = methodBody(replyCardActions, 'ThankButton')
assert.doesNotMatch(
  thankButtonBody,
  /\.(?:enabled|opacity)\([^)]*isThankPending[^)]*\)/,
  'reply thank pending state must not drive disabled or opacity visuals',
)
assert.doesNotMatch(
  thankButtonBody,
  /(?:LoadingProgress|Progress)\s*\([^)]*\)[\s\S]*isThankPending|isThankPending[\s\S]*(?:LoadingProgress|Progress)\s*\([^)]*\)/,
  'reply thank pending state must not drive loading/progress visuals',
)
assert.match(thankButtonBody, /if \(this\.onThankClick && !this\.isThankPending\)/)

const optimisticBody = methodBody(viewModel, 'optimisticallyMarkReplyThanked')
assert.match(viewModel, /export interface ReplyThankSnapshot/)
assert.match(optimisticBody, /previousThanks:\s*Math\.max\(0,\s*reply\.thanks \|\| 0\)/)
assert.match(optimisticBody, /wasThanked:\s*!!reply\.thanked/)
assert.match(optimisticBody, /if \(!reply\.thanked\)\s*\{[\s\S]*reply\.thanks = Math\.max\(0,\s*reply\.thanks \|\| 0\) \+ 1[\s\S]*\}/)
assert.match(optimisticBody, /reply\.thanked = true/)
// Optimistic apply first updates the hot-reply clone that may already be on screen, then publishes
// through the single chokepoint when no reload is holding the page-1 publish. The held path keeps the
// normal list stable but still fixes the high-reply count for the changed reply.
assert.match(
  optimisticBody,
  /if \(snapshot !== null\)\s*\{[\s\S]*this\.syncHotReplyCandidateFromLoadedReply\(replyId\)[\s\S]*if \(!this\.heldRepliesPublish\)\s*\{[\s\S]*this\.publishVisibleReplies\(\)/,
)

const rollbackBody = methodBody(viewModel, 'rollbackReplyThank')
assert.match(rollbackBody, /reply\.thanks = snapshot\.previousThanks/)
assert.match(rollbackBody, /reply\.thanked = snapshot\.wasThanked/)
assert.match(rollbackBody, /reply\.renderKey = snapshot\.previousRenderKey/)
assert.match(
  rollbackBody,
  /if \(changed\)\s*\{[\s\S]*this\.syncHotReplyCandidateSnapshot\(snapshot\)[\s\S]*if \(!this\.heldRepliesPublish\)\s*\{[\s\S]*this\.publishVisibleReplies\(\)/,
)

assert.match(
  viewModel,
  /private syncHotReplyCandidateValues\([\s\S]*?const next: V2exReply\[\] = \[\][\s\S]*?JSON\.parse\(JSON\.stringify\(this\.hotReplyCandidates\[i\]\)\) as V2exReply[\s\S]*?this\.hotReplyCandidates = next/,
)
assert.match(
  viewModel,
  /private syncHotReplyCandidateTree\([\s\S]*?reply\.thanks = Math\.max\(0,\s*thanks \|\| 0\)[\s\S]*?reply\.thanked = thanked[\s\S]*?reply\.threadChildren \|\| \[\]/,
)

// The chokepoint is the only place that pushes the visible list to the data source: it keeps the
// floor-lookup snapshot (publishedReplies) and the loaded-count in lockstep with the rendered rows.
// Anchor on the definition signature — publishVisibleReplies is also CALLED above its declaration,
// so a name-based body scan would grab a call site instead of the method body.
assert.match(
  viewModel,
  /private publishVisibleReplies\(\): void \{[\s\S]*?this\.publishedReplies = this\.replies[\s\S]*?const visibleReplies = this\.getVisibleReplies\(\)[\s\S]*?this\.refreshHotReplyCandidates\(\)[\s\S]*?this\.replyDataSource\.setData\(visibleReplies\)[\s\S]*?this\.repliesLoaded = this\.replies\.length/,
)

assert.match(coordinator, /export interface ReplyThankedIdsSnapshot/)
assert.match(coordinator, /static markReplyThankedWithSnapshot\(/)
assert.match(coordinator, /static unmarkReplyThanked\(/)
assert.match(coordinator, /static rollbackReplyThankedIds\(/)
const unmarkBody = methodBody(coordinator, 'unmarkReplyThanked')
assert.match(unmarkBody, /\.filter\(\(id: number\) => id !== replyId\)/)
const localRollbackBody = methodBody(coordinator, 'rollbackReplyThankedIds')
assert.match(coordinator, /rollbackReplyThankedIds\([\s\S]*currentJson:\s*string = ''/)
assert.match(localRollbackBody, /if \(!snapshot\)\s*\{[\s\S]*return currentJson[\s\S]*\}/)
assert.doesNotMatch(localRollbackBody, /if \(!snapshot\)\s*\{[\s\S]*return '\[\]'[\s\S]*\}/)
assert.match(localRollbackBody, /if \(!snapshot\.addedReplyId\)/)
assert.match(localRollbackBody, /unmarkReplyThanked\(snapshot\.replyId,\s*snapshot\.nextJson\)/)
assert.match(localRollbackBody, /snapshot\.previousJson/)

console.log('PASS reply thank optimistic static contract')
