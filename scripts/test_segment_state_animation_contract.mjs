#!/usr/bin/env node
// Static contract: both V2 segmented-tab surfaces re-enable the selection-state
// animation by passing `enableStateAnimation: true` to TabSegmentButtonV2.
//
// `enableStateAnimation` is a `@Param readonly enableStateAnimation?: boolean` on the
// TabSegmentButtonV2 struct in @ohos.arkui.advanced.SegmentButtonV2.d.ets, marked
// `@since 24` ("Enable animation when selectedIndexes change."). API 23 rejected it at
// compile time; the SDK/API 24 upgrade exposes it. This contract pins that BOTH affected
// call sites opt in, WITHOUT regressing the compact SegmentButton-equivalent width those
// surfaces pin (the prior layout fix: .width(COMPACT_SEGMENT_BUTTON_WIDTH) + min==max
// constraintSize).
//
// Must FAIL before the production change (call sites don't yet pass the flag) and PASS
// after. The flag is asserted INSIDE the TabSegmentButtonV2(...) call, not merely present
// somewhere in the file.
//
// Run: node scripts/test_segment_state_animation_contract.mjs
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const repo = join(dirname(fileURLToPath(import.meta.url)), '..')
const read = (rel) => readFileSync(join(repo, rel), 'utf8')
const stripComments = (t) => t.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '')

// Balanced-paren argument text of the first `TabSegmentButtonV2(` call in src.
function extractTabCall(src, structName) {
  const m = /TabSegmentButtonV2\s*\(/.exec(src)
  assert.ok(m, `${structName}: TabSegmentButtonV2(...) call site not found`)
  const open = m.index + m[0].length - 1
  let depth = 0
  for (let i = open; i < src.length; i++) {
    const c = src[i]
    if (c === '(') depth++
    else if (c === ')' && --depth === 0) return src.slice(open, i + 1)
  }
  assert.fail(`${structName}: TabSegmentButtonV2(...) call has unbalanced parentheses`)
}

function assertAnimatedCompactSegment(file, structName) {
  const src = stripComments(read(file))
  const call = extractTabCall(src, structName)

  // 1. The selection-state animation flag is passed explicitly as `true`, inside the call.
  assert.match(
    call,
    /enableStateAnimation\s*:\s*true\b/,
    `${structName} must pass enableStateAnimation: true to TabSegmentButtonV2 (API 24 @since 24 @Param)`
  )

  // 2. Compact width constraints preserved (no regression of the prior layout fix).
  assert.match(
    src,
    /\.width\(ThemeConstants\.COMPACT_SEGMENT_BUTTON_WIDTH\)/,
    `${structName} must keep the compact SegmentButton-equivalent width`
  )
  assert.match(
    src,
    /\.constraintSize\(\{\s*minWidth:\s*ThemeConstants\.COMPACT_SEGMENT_BUTTON_WIDTH,\s*maxWidth:\s*ThemeConstants\.COMPACT_SEGMENT_BUTTON_WIDTH,\s*\}\)/,
    `${structName} must keep min==max==COMPACT_SEGMENT_BUTTON_WIDTH sizing`
  )
}

assertAnimatedCompactSegment(
  'feature/user/src/main/ets/components/UserProfileActivityTabs.ets',
  'UserProfileActivityTabs'
)
assertAnimatedCompactSegment(
  'entry/src/main/ets/components/BlockedListsTabsSegment.ets',
  'BlockedListsTabsSegment'
)

console.log('segment state-animation contract OK')
