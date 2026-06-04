#!/usr/bin/env node
/**
 * Floor-jump correctness under 楼中楼 (threaded) reordering.
 *
 * Bug: every floor jump used `2 + floor`, assuming the reply at floor N sits at dataArray[N-1]. In
 * threaded mode the visible list is REORDERED — a late reply (#21) that replies to an early one (#8)
 * becomes a nested child with no top-level row, so `2 + 21` landed near the end instead of at #21's real
 * (nested) position. Fix: TopicDetailScrollCoordinator.listIndexForFloor now scans the actual displayed
 * data for the row whose subtree (self + nested threadChildren) contains the floor, and every jump site
 * funnels through TopicDetailPage.jumpToFloorIndex. The reverse (read-floor) offset off-by-one (-3 → -2)
 * and the threaded-breaking loadedFloor clamp are also fixed/removed.
 *
 * Run: node scripts/test_floor_jump_threaded_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const coord = readFileSync('feature/detail/src/main/ets/model/TopicDetailScrollCoordinator.ets', 'utf8')
const page = readFileSync('feature/detail/src/main/ets/pages/TopicDetailPage.ets', 'utf8')

// ── coordinator: data-aware mapping, off-by-one fix, dead clamp removed ────────
assert.match(coord, /static listIndexForFloor\(\s*floor: number,\s*count: number,\s*getData: \(index: number\) => V2exReply,?\s*\)/, 'listIndexForFloor must take (floor, count, getData) and consult the real data')
assert.match(coord, /static dataIndexForFloor\(/, 'must expose dataIndexForFloor (scan for the row containing the floor)')
assert.match(coord, /subtreeContainsFloor\(reply: V2exReply, floor: number\): boolean/, 'must recurse threadChildren via subtreeContainsFloor')
assert.match(coord, /reply\.threadChildren \|\| \[\]/, 'subtree scan must walk threadChildren')
assert.match(coord, /return centerIndex - TopicDetailScrollCoordinator\.REPLY_LIST_OFFSET/, 'reverse mapping must use the same offset (off-by-one -3 → -2 fix)')
assert.match(coord, /REPLY_LIST_OFFSET: number = 2/, 'list offset (TopicCard + ReplyDivider) is 2')
assert.doesNotMatch(coord, /static loadedFloor\(/, 'the loadedFloor clamp (which clamps to the root count and breaks threaded jumps) must be removed')

// ── page: all jumps funnel through jumpToFloorIndex; no chronological 2+floor ──
assert.match(page, /private jumpToFloorIndex\(floor: number\): void/, 'TopicDetailPage must define jumpToFloorIndex')
assert.match(page, /TopicDetailScrollCoordinator\.listIndexForFloor\(\s*floor,\s*source\.totalCount\(\),\s*\(index: number\) => source\.getData\(index\)/, 'jumpToFloorIndex must resolve via listIndexForFloor over the live data source')
assert.doesNotMatch(page, /scrollToListIndex\(2 \+ floor/, 'no jump may use the chronological 2 + floor guess')
assert.doesNotMatch(page, /loadedFloor\(/, 'no jump may use the removed loadedFloor clamp')
// the three coordinator-driven jump sites delegate to jumpToFloorIndex
assert.ok((page.match(/this\.jumpToFloorIndex\(/g) || []).length >= 3, 'manual-jump, resume, and reply-context jumps must all call jumpToFloorIndex')

// ── logic replica: scan finds the nested row, ignoring the redundant tail clone ──
function subtreeContainsFloor(reply, floor) {
  if ((reply.floor || 0) === floor) return true
  const children = reply.threadChildren || []
  for (const c of children) if (subtreeContainsFloor(c, floor)) return true
  return false
}
function dataIndexForFloor(floor, rows) {
  if (floor <= 0) return -1
  for (let i = 0; i < rows.length; i++) if (subtreeContainsFloor(rows[i], floor)) return i
  return -1
}
const REPLY_LIST_OFFSET = 2
const listIndexForFloor = (floor, rows) => {
  const di = dataIndexForFloor(floor, rows)
  return di < 0 ? -1 : REPLY_LIST_OFFSET + di
}

// #6 has #8 nested, #8 has #21 nested; redundant mode also appends flat dup clones of #8 and #21.
const threaded = [
  { floor: 1, threadChildren: [] },
  { floor: 6, threadChildren: [{ floor: 8, threadChildren: [{ floor: 21, threadChildren: [] }] }] },
  { floor: 9, threadChildren: [] },
  { floor: 8, threadChildren: [] }, // redundant tail clone
  { floor: 21, threadChildren: [] }, // redundant tail clone
]
// #21 resolves to the #6 root (display row 1 → list index 3), NOT the tail clone (row 4 → list index 6).
assert.equal(dataIndexForFloor(21, threaded), 1, '#21 jumps to the row that actually contains it (#6 subtree)')
assert.equal(listIndexForFloor(21, threaded), 3, '#21 → list index 3 (its real nested position), not the end')
assert.equal(dataIndexForFloor(8, threaded), 1, '#8 also resolves to its #6 root row, not the dup clone')
assert.equal(listIndexForFloor(99, threaded), -1, 'an absent floor returns -1 so the caller falls back to the end')

// flat mode: floor F sits at dataArray[F-1] → list index F+1 (the old 2+floor was off by one too).
const flat = [1, 2, 3, 4, 5].map((f) => ({ floor: f, threadChildren: [] }))
assert.equal(listIndexForFloor(1, flat), 2, 'flat: floor 1 → list index 2 (first reply row), not 3')
assert.equal(listIndexForFloor(4, flat), 5, 'flat: floor 4 → list index 5')

console.log('floor-jump threaded contract passed')
