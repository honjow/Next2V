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
assert.match(
  bottomIndicator,
  /\.opacity\s*\([\s\S]*this\.bottomRefreshState\s*>=\s*2[\s\S]*\?\s*1[\s\S]*this\.bottomPullOffset\s*\/\s*this\.threshold[\s\S]*\)/,
  'bottom spinner should be fully visible while running and fade in during active pull/release-ready states',
)
assert.match(
  bottomIndicator,
  /Math\.max\s*\(\s*this\.bottomPullOffset\s*\/\s*this\.threshold\s*,\s*0\.2\s*\)/,
  'active bottom pull should keep a non-zero spinner opacity instead of an empty blank area',
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
