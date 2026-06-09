#!/usr/bin/env node
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repo = process.cwd()

function read(rel) {
  return fs.readFileSync(path.join(repo, rel), 'utf8')
}

function stripComments(text) {
  return text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '')
}

function assertCompactSegment(file, structName) {
  const src = stripComments(read(file))
  assert.match(src, /TabSegmentButtonV2\s*\(/, `${structName} must keep the V2 segmented button host`)
  assert.doesNotMatch(src, /\bSegmentButton\s*\(/, `${structName} must not restore the V1 SegmentButton`)
  assert.match(
    src,
    /\.width\(ThemeConstants\.COMPACT_SEGMENT_BUTTON_WIDTH\)/,
    `${structName} must force TabSegmentButtonV2 to the compact SegmentButton-equivalent width`
  )
  assert.match(
    src,
    /\.constraintSize\(\{\s*minWidth:\s*ThemeConstants\.COMPACT_SEGMENT_BUTTON_WIDTH,\s*maxWidth:\s*ThemeConstants\.COMPACT_SEGMENT_BUTTON_WIDTH,\s*\}\)/,
    `${structName} must not leave TabSegmentButtonV2 max-only/fill-width sizing`
  )
}

const theme = stripComments(read('shared/src/main/ets/theme/ThemeConstants.ets'))
assert.match(
  theme,
  /static readonly COMPACT_SEGMENT_BUTTON_WIDTH:\s*number\s*=\s*216;?/,
  'ThemeConstants must define the compact segmented-control width token'
)

assertCompactSegment(
  'feature/user/src/main/ets/components/UserProfileActivityTabs.ets',
  'UserProfileActivityTabs'
)
assertCompactSegment(
  'entry/src/main/ets/components/BlockedListsTabsSegment.ets',
  'BlockedListsTabsSegment'
)

console.log('compact segment tabs contract OK')
