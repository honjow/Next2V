import fs from 'node:fs'
import assert from 'node:assert/strict'

const pullRefreshPath = new URL('../shared/src/main/ets/components/PullRefresh.ets', import.meta.url)
const topicPagePath = new URL('../feature/detail/src/main/ets/pages/TopicDetailPage.ets', import.meta.url)
const viewModelPath = new URL('../feature/detail/src/main/ets/viewmodel/DetailViewModel.ets', import.meta.url)

const pullRefresh = fs.readFileSync(pullRefreshPath, 'utf8')
const topicPage = fs.readFileSync(topicPagePath, 'utf8')
const viewModel = fs.readFileSync(viewModelPath, 'utf8')

function methodBody(source, signature, nextSignature) {
  const start = source.indexOf(signature)
  assert.notEqual(start, -1, `${signature} should remain present`)
  const end = source.indexOf(nextSignature, start)
  assert.notEqual(end, -1, `${signature} should end before ${nextSignature}`)
  return source.slice(start, end)
}

const bottomIndicatorY = methodBody(
  pullRefresh,
  'private bottomIndicatorY(): number',
  '\n  build()'
)
assert.equal(
  /this\.bottomPullOffset/.test(bottomIndicatorY),
  false,
  'manual bottom spinner y-position must be viewport/safe-area anchored, not tied to pull distance'
)
assert.match(
  bottomIndicatorY,
  /this\.containerHeight\s*-\s*this\.bottomIndicatorBottom[\s\S]*ThemeConstants\.TITLE_BAR_HEIGHT\s*\/\s*2/,
  'manual bottom spinner should remain anchored from container height and bottom safe-area padding'
)

assert.match(
  pullRefresh,
  /\.offset\(\{\s*y:\s*this\.pullOffset\s*-\s*this\.bottomPullOffset\s*\}\)/,
  'content should still move for top and bottom pull gestures'
)
assert.match(
  pullRefresh,
  /deltaY\s*<\s*-PULL_START_DRAG_VP[\s\S]*this\.isListAtBottom\(\)[\s\S]*this\.canStartBottomRefresh\(\)/,
  'manual bottom gesture should remain gated by exact bottom position and page business state'
)

const canBottomRefresh = methodBody(
  viewModel,
  'canBottomRefresh(): boolean',
  '\n\n  shouldShowRepliesFooter()'
)
for (const required of [
  '!this.isRepliesLoadingMore',
  '!this.isBottomRefreshing',
  "this.repliesLoadMoreState === 'endReached'",
  '!this.repliesHasMore',
]) {
  assert.ok(canBottomRefresh.includes(required), `manual bottom refresh gate should include ${required}`)
}

const footerVisibility = methodBody(
  viewModel,
  'shouldShowRepliesFooter(): boolean',
  '\n\n  private estimateTotalReplies()'
)
assert.match(
  footerVisibility,
  /this\.repliesLoadMoreState\s*===\s*'loadingMore'[\s\S]*this\.repliesLoadMoreState\s*===\s*'loadMoreError'/,
  'auto-pagination footer should only render during loading/error, not after endReached manual refresh eligibility'
)

const pageBottomGate = methodBody(
  topicPage,
  'private canTriggerBottomRefresh(): boolean',
  '\n\n  private handleReplyListReachEnd()'
)
assert.match(
  pageBottomGate,
  /return\s+this\.v\.canBottomRefresh\(\)/,
  'TopicDetailPage should delegate manual bottom-refresh eligibility to DetailViewModel business state'
)
assert.equal(
  /return[\s\S]*isReplyListAtEnd/.test(pageBottomGate),
  false,
  'manual bottom refresh must not reuse loose last-visible-item auto-pagination state'
)

console.log('PASS topic bottom loader contract: manual spinner anchor is stable and separated from auto-pagination footer')
