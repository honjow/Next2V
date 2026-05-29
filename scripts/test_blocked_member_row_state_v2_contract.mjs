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

assertIncludes(page, '@ObservedV2', 'blocked member row model must use State Management V2 @ObservedV2')
assertIncludes(page, 'class BlockedMemberListItem', 'blocked member row model must be a class, not a plain interface')
assertNotIncludes(page, 'interface BlockedMemberListItem', 'blocked member row model must not remain a plain interface')

for (const field of ['username', 'tagline', 'avatar', 'created', 'resolved']) {
  const pattern = new RegExp(`@Trace\\s+${field}\\s*:`)
  if (!pattern.test(page)) {
    fail(`BlockedMemberListItem.${field} must be @Trace so same-id row content updates refresh UI`)
  }
}

assertIncludes(page, '@ComponentV2', 'blocked member row view must use a V2 component boundary')
assertIncludes(page, '@Param item: BlockedMemberListItem', 'V2 row view must receive the observed row model via @Param')

assertIncludes(page, 'private memberRowsById: Map<number, BlockedMemberListItem>', 'page must keep stable row objects by member id')
assertIncludes(page, 'private ensureMemberRowsForIds', 'page must expose id-diff helper that reuses row objects')
assertIncludes(page, 'private memberRowForId', 'page must create/reuse exactly one row object per member id')
assertIncludes(page, '.applyProfile(profile)', 'async profile resolution must update the existing row object in place')
assertIncludes(page, 'blocked_member_row_resolved', 'member resolution must log the row update boundary for device proof')

const memberListBody = methodBody(page, '  BlockedMembersList')
assertIncludes(memberListBody, 'ForEach(this.members', 'BlockedMembersList must render the canonical row store, not a computed fallback array')
assertIncludes(memberListBody, '`blocked-member-${item.id}`', 'blocked member row key must stay stable by member id')
for (const forbiddenKeyPart of ['item.resolved', 'Date.now()', 'updatedAt', 'renderKey', 'version']) {
  assertNotIncludes(memberListBody, forbiddenKeyPart, `blocked member key must not include ${forbiddenKeyPart}`)
}

assertNotIncludes(page, 'private renderableMembers()', 'computed fallback arrays bypass stable V2 row identity')
assertNotIncludes(page, '.map((id: number): BlockedMemberListItem => this.fallbackMember(id))', 'fallback rows must be canonical row objects, not transient computed objects')

const resolveMembersBody = methodBody(page, 'private resolveMembers')
assertIncludes(resolveMembersBody, 'this.ensureMemberRowsForIds(memberIds)', 'resolveMembers must seed/reuse stable row objects before async profile resolution')
assertNotIncludes(resolveMembersBody, 'this.members = items', 'resolveMembers must not replace resolved same-id rows with new plain objects')
assertNotIncludes(resolveMembersBody, 'Promise<BlockedMemberListItem>', 'async member resolution should mutate row objects instead of returning replacement rows')

console.log('PASS: blocked member row state V2 contract')
