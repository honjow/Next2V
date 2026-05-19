#!/usr/bin/env node
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (path) => readFileSync(path, 'utf8')

const page = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
const viewModel = read('feature/detail/src/main/ets/viewmodel/DetailViewModel.ets')
const coordinator = read('feature/detail/src/main/ets/model/TopicDetailActionCoordinator.ets')

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
const optimisticIndex = executeBody.indexOf('this.v.optimisticallyMarkReplyThanked(reply.id)')
const localMarkIndex = executeBody.indexOf('this.markReplyThanked(reply.id)')
const networkIndex = executeBody.indexOf('TopicDetailActionCoordinator')
assert.ok(optimisticIndex >= 0, 'reply thank must optimistically update viewmodel state')
assert.ok(localMarkIndex > optimisticIndex, 'local thanked id must be marked after viewmodel optimistic apply')
assert.ok(networkIndex > localMarkIndex, 'network action must start after optimistic apply and local mark')
assert.match(executeBody, /\.then\(\(\)\s*=>\s*\{[\s\S]*已感谢[\s\S]*\}\)/)
assert.match(executeBody, /\.catch\(\(error: Error\)\s*=>\s*\{[\s\S]*this\.v\.rollbackReplyThank\(replyThankSnapshot\)[\s\S]*rollbackReplyThankedIds\(\s*thankedIdsSnapshot,\s*this\.thankedReplyIdsJson,\s*\)[\s\S]*感谢失败/)
assert.match(executeBody, /\.finally\(\(\)\s*=>\s*\{[\s\S]*this\.isReplyThankLoading = false[\s\S]*this\.clearReplyThankLock\(\)/)
assert.doesNotMatch(executeBody, /\.then\(\(\)\s*=>\s*\{[\s\S]*markReplyThanked\(reply\.id\)/)

const optimisticBody = methodBody(viewModel, 'optimisticallyMarkReplyThanked')
assert.match(viewModel, /export interface ReplyThankSnapshot/)
assert.match(optimisticBody, /previousThanks:\s*Math\.max\(0,\s*reply\.thanks \|\| 0\)/)
assert.match(optimisticBody, /wasThanked:\s*!!reply\.thanked/)
assert.match(optimisticBody, /if \(!reply\.thanked\)\s*\{[\s\S]*reply\.thanks = Math\.max\(0,\s*reply\.thanks \|\| 0\) \+ 1[\s\S]*\}/)
assert.match(optimisticBody, /reply\.thanked = true/)
assert.match(optimisticBody, /replyDataSource\.setData\(this\.getVisibleReplies\(\)\)/)

const rollbackBody = methodBody(viewModel, 'rollbackReplyThank')
assert.match(rollbackBody, /reply\.thanks = snapshot\.previousThanks/)
assert.match(rollbackBody, /reply\.thanked = snapshot\.wasThanked/)
assert.match(rollbackBody, /reply\.renderKey = snapshot\.previousRenderKey/)
assert.match(rollbackBody, /replyDataSource\.setData\(this\.getVisibleReplies\(\)\)/)

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
