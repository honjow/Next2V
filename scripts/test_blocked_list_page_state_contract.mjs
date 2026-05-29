#!/usr/bin/env node

import { readFileSync } from 'node:fs'

const pagePath = 'entry/src/main/ets/pages/BlockedListsPage.ets'
const page = readFileSync(new URL(`../${pagePath}`, import.meta.url), 'utf8')

function fail(message) {
  console.error(`FAIL: ${message}`)
  process.exit(1)
}

function assertIncludes(text, needle, message) {
  if (!text.includes(needle)) {
    fail(message || `missing expected text: ${needle}`)
  }
}

function assertNotIncludes(text, needle, message) {
  if (text.includes(needle)) {
    fail(message || `forbidden text found: ${needle}`)
  }
}

function methodBody(text, methodName) {
  const marker = methodName.includes('(') ? methodName : `${methodName}(`
  const start = text.indexOf(marker)
  if (start < 0) {
    fail(`missing method marker: ${marker}`)
  }
  const braceStart = text.indexOf('{', start)
  if (braceStart < 0) {
    fail(`missing method body for: ${marker}`)
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
}

function requireMethodCallOrder(body, first, second, message) {
  const firstIndex = body.indexOf(first)
  const secondIndex = body.indexOf(second)
  if (firstIndex < 0 || secondIndex < 0 || firstIndex >= secondIndex) {
    fail(message || `expected ${first} before ${second}`)
  }
}

const loadingBody = methodBody(page, 'private shouldShowPageLoading')
assertNotIncludes(
  loadingBody,
  'this.syncInFlight || this.loadingMembers || this.members.length === 0',
  'shouldShowPageLoading must not use sync/loading/member-empty as fullscreen loading for cached blocked members',
)
assertNotIncludes(
  loadingBody,
  'this.syncInFlight || this.loadingTopics',
  'shouldShowPageLoading must not use sync/loading as fullscreen loading for ignored topics',
)
assertIncludes(loadingBody, 'hasAnyRenderableForCurrentTab()', 'shouldShowPageLoading must gate fullscreen loading on renderable content')

assertIncludes(page, '@Watch(\'onBlockedListStorageChanged\')', 'BlockedListsPage must watch blocked-list AppStorage changes')
assertIncludes(page, 'private onBlockedListStorageChanged()', 'BlockedListsPage must have a storage-change handler')
assertIncludes(page, 'private applyRuntimeSnapshot', 'BlockedListsPage must have a runtime snapshot application entrypoint')
const storageHandlerBody = methodBody(page, 'private onBlockedListStorageChanged')
assertIncludes(storageHandlerBody, 'this.ignoredTopicIdsJson', 'storage-change handler must consume ignoredTopicIdsJson')
assertIncludes(storageHandlerBody, 'this.blockedMemberIdsJson', 'storage-change handler must consume blockedMemberIdsJson')
assertIncludes(storageHandlerBody, 'this.updatedAt', 'storage-change handler must consume updatedAt')
assertIncludes(storageHandlerBody, 'applyRuntimeSnapshot', 'storage-change handler must apply runtime snapshot')

const applyRuntimeBody = methodBody(page, 'private applyRuntimeSnapshot')
assertIncludes(applyRuntimeBody, 'BlockedListSettings.runtimeSnapshot()', 'applyRuntimeSnapshot must read the shared runtime snapshot')
assertIncludes(applyRuntimeBody, 'this.applySnapshot(', 'applyRuntimeSnapshot must reuse page snapshot application')

const memberBody = methodBody(page, 'private resolveMembers')
assertIncludes(memberBody, 'ensureMemberRowsForIds', 'resolveMembers must preserve stable V2 row objects that remain in the id set')
assertNotIncludes(memberBody, 'this.members = memberIds.map((id: number): BlockedMemberListItem => this.fallbackMember(id))', 'resolveMembers must not replace the whole member list with fallback rows on every id-set change')
assertIncludes(page, 'private ensureMemberRowsForIds', 'BlockedListsPage must expose member row diff helper')
const preserveMembersBody = methodBody(page, 'private ensureMemberRowsForIds')
assertIncludes(preserveMembersBody, 'Map<number, BlockedMemberListItem>', 'ensureMemberRowsForIds must use id-keyed stable V2 row state')

const topicsBody = methodBody(page, 'private resolveTopics')
assertNotIncludes(topicsBody, 'if (this.topics.length > 0 && !this.topicIdsMatch(this.topics, topicIds)) {\n      this.topics = []\n    }', 'resolveTopics must not clear visible topics before resolving changed ids')

requireMethodCallOrder(page, 'private shouldShowPageLoading', 'private pageStateMessage', 'page state helpers moved unexpectedly')

for (const forbidden of ['EMPTY_STATE_HEIGHT', 'stateHeight:', 'BlockedEmptyState(', 'TabHeaderItem()', 'SegmentButton({']) {
  assertNotIncludes(page, forbidden, `BlockedListsPage must not contain ${forbidden}`)
}

console.log('PASS: blocked list page state contract')
