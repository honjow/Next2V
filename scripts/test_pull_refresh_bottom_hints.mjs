import fs from 'node:fs'
import assert from 'node:assert/strict'

const sourcePath = new URL('../shared/src/main/ets/components/PullRefresh.ets', import.meta.url)
const source = fs.readFileSync(sourcePath, 'utf8')

const bottomIndicatorStart = source.indexOf("Row({ space: ThemeConstants.SPACE_SM })")
assert.notEqual(bottomIndicatorStart, -1, 'bottom indicator guard should remain present')
const bottomIndicatorEnd = source.indexOf('.clip(false)', bottomIndicatorStart)
assert.notEqual(bottomIndicatorEnd, -1, 'bottom indicator block should remain before Stack clipping configuration')
const bottomIndicator = source.slice(bottomIndicatorStart, bottomIndicatorEnd)

assert.equal(
  /Text\s*\(\s*this\.bottomText\s*\(\s*\)\s*\)/.test(bottomIndicator),
  false,
  'default bottom indicator must not render Text(this.bottomText())',
)

for (const forbiddenHint of ['上拉刷新', '松开刷新']) {
  assert.equal(
    source.includes(forbiddenHint),
    false,
    `default PullRefresh source must not contain bottom hint copy: ${forbiddenHint}`,
  )
}

assert.match(
  bottomIndicator,
  /LoadingProgress\s*\(\s*\)\s*\n\s*\.width\(ThemeConstants\.LOADING_SIZE_SMALL\)/,
  'bottom indicator should render a visual spinner/progress control',
)
assert.equal(
  /if\s*\(\s*this\.bottomRefreshState\s*>=\s*2\s*\)\s*\{\s*LoadingProgress\s*\(/.test(bottomIndicator),
  false,
  'bottom LoadingProgress must not be limited to the running-only branch',
)
// Opacity is now a pure function of the live gap (bottomPullOffset) via the shared indicatorOpacity()
// helper, intentionally decoupled from bottomRefreshState (commits 20c151f/144325e: indicator
// opacity/position/mount must be pure fns of the gap). It still fades in during pull and is fully
// visible at the resting hold offset, but no longer keys off the >=2 running state.
assert.match(
  bottomIndicator,
  /\.opacity\(this\.indicatorOpacity\(this\.bottomPullOffset,\s*ThemeConstants\.LOADING_SIZE_SMALL\)\)/,
  'bottom spinner opacity should be the gap-pure indicatorOpacity(bottomPullOffset, ...) fade, not a refreshState ternary',
)
// The historical 0.2 floor was removed on purpose: the gap-pure helper pins opacity to 0 until the gap
// clears the spinner's own diameter, so a half-shown spinner can never overlap the adjacent content row.
const indicatorOpacityStart = source.indexOf('private indicatorOpacity(gap: number, indicatorSize: number): number')
assert.notEqual(indicatorOpacityStart, -1, 'shared indicatorOpacity helper should remain present')
const indicatorOpacityBody = source.slice(indicatorOpacityStart, source.indexOf('\n  }', indicatorOpacityStart))
assert.match(
  indicatorOpacityBody,
  /Math\.min\(Math\.max\(\(gap - indicatorSize\)\s*\/\s*range,\s*0\),\s*1\)/,
  'indicatorOpacity must keep opacity 0 until the gap exceeds the spinner diameter (no overlap), ramping to 1 at the hold offset',
)
assert.match(
  source,
  /onBottomRefresh\s*\(\s*\)/,
  'bottom refresh callback invocation should remain wired',
)
assert.match(
  source,
  /bottomPullOffset\s*>=\s*this\.threshold/,
  'bottom refresh threshold check should remain wired',
)
assert.match(
  source,
  /canStartBottomRefresh\s*\(\s*\)/,
  'bottom gesture eligibility hook should remain wired',
)
assert.match(
  source,
  /isListAtBottom\s*\(\s*\)/,
  'manual bottom refresh should remain gated by bottom position',
)
assert.match(
  source,
  /triggerHaptic\s*\(\s*\)/,
  'haptic trigger should remain wired',
)
assert.match(
  source,
  /onScrollEnableChange\s*\(\s*false\s*\)/,
  'scroll disabling during active pull gestures should remain wired',
)

const bottomIndicatorYStart = source.indexOf('private bottomIndicatorY(): number')
assert.notEqual(bottomIndicatorYStart, -1, 'bottom indicator anchor helper should remain present')
const bottomIndicatorYEnd = source.indexOf('\n  }\n\n  build()', bottomIndicatorYStart)
assert.notEqual(bottomIndicatorYEnd, -1, 'bottom indicator anchor helper should end before build()')
const bottomIndicatorY = source.slice(bottomIndicatorYStart, bottomIndicatorYEnd)
assert.match(
  bottomIndicatorY,
  /this\.bottomPullOffset\s*\/\s*2/,
  'bottom indicator Y should mirror top indicator positioning and track half of real edge-rebased pull distance',
)
assert.equal(
  /if \(this\.bottomPullOffset > 0 \|\| this\.bottomRefreshState > 0\)/.test(source),
  false,
  'bottom indicator should remain mounted like top indicator instead of being conditionally inserted during pull',
)

console.log('PASS PullRefresh bottom manual-refresh text hints are hidden while spinner feedback and centered positioning remain present')
