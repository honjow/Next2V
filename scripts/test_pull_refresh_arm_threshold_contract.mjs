#!/usr/bin/env node
/**
 * PullRefresh must not arm a pull on a tap's finger jitter.
 *
 * Bug: tapping a Discover node chip often did nothing (multi-tap eventually worked). PullRefresh's
 * onTouch armed a pull as soon as the finger moved > PULL_START_DRAG_VP (4vp) vertically and called
 * onScrollEnableChange(false), which disabled the inner Scroll and swallowed the tapped child's onClick.
 * A tap's small jitter randomly cleared 4vp → random dead taps. Fix: arm only on a deliberate,
 * vertical-dominant drag past a larger PULL_ARM_VP, and always re-enable the Scroll on touch end.
 *
 * Run: node scripts/test_pull_refresh_arm_threshold_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const src = readFileSync('shared/src/main/ets/components/PullRefresh.ets', 'utf8')

// a dedicated, larger arm threshold (separate from the offset anchor)
const armMatch = src.match(/const PULL_ARM_VP: number = (\d+)/)
assert.ok(armMatch, 'must define a PULL_ARM_VP arm threshold')
assert.ok(Number(armMatch[1]) >= 8, `PULL_ARM_VP must be clearly larger than a tap jitter (got ${armMatch[1]})`)
assert.match(src, /const PULL_START_DRAG_VP: number = 4/, 'PULL_START_DRAG_VP stays as the smaller offset anchor')

// arming requires vertical dominance AND the larger threshold (not PULL_START_DRAG_VP)
assert.match(src, /const verticalDominant = Math\.abs\(deltaY\) > Math\.abs\(deltaX\) \* 1\.5/, 'arming must require vertical-dominant motion')
assert.match(src, /verticalDominant && deltaY > PULL_ARM_VP && this\.isListAtTop\(\)/, 'top pull arms only on a vertical-dominant drag past PULL_ARM_VP')
assert.match(src, /verticalDominant &&\s*deltaY < -PULL_ARM_VP/, 'bottom pull arms only on a vertical-dominant drag past PULL_ARM_VP')
// the old jitter-prone arm (deltaY > PULL_START_DRAG_VP) must be gone
assert.doesNotMatch(src, /deltaY > PULL_START_DRAG_VP/, 'must not arm at the 4vp PULL_START_DRAG_VP (too low — tap jitter trips it)')

// self-heal: touch end always re-enables the inner Scroll so a disabled scroll can't stick into the next tap
const upBlock = src.match(/if \(event\.type === TouchType\.Up \|\| event\.type === TouchType\.Cancel\) \{([\s\S]*?)\n {8}\}/)
assert.ok(upBlock, 'must handle Up/Cancel')
assert.match(upBlock[1], /this\.onScrollEnableChange\(true\)\s*\n\s*this\.resetTouchState\(\)/, 'Up/Cancel must unconditionally re-enable the Scroll before resetting touch state')

console.log('pull-refresh arm-threshold contract passed')
