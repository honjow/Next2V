#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'

const repo = process.cwd()

function read(rel) {
  return fs.readFileSync(path.join(repo, rel), 'utf8')
}

const api = read('shared/src/main/ets/network/ApiService.ets')
const parser = read('shared/src/main/ets/parser/V2exTabParser.ets')
const feedVm = read('feature/feed/src/main/ets/viewmodel/FeedViewModel.ets')
const home = read('feature/feed/src/main/ets/pages/HomePage.ets')
const topicCard = read('shared/src/main/ets/components/TopicCard.ets')
const networkTypes = read('shared/src/main/ets/network/NetworkTypes.ets')

assert.match(
  api,
  /async\s+getAllTopicsPage\(page: number = 1\): Promise<V2exPagedTopicsResult>\s*{[\s\S]*fetchFeedTopicListHtml\('\/\?tab=all'\)[\s\S]*V2exTabParser\.hasMoreRecentTopicsLink\(html\)/,
  'all-tab first page must fetch /?tab=all and derive hasMore from the More Recent Topics link',
)

assert.match(
  api,
  /if\s*\(safePage\s*>\s*1\)\s*{[\s\S]*return\s+this\.getRecentTopicsPage\(safePage - 1\)/,
  'all-tab follow-up pages must continue through /recent?p=N after the first page',
)

assert.match(
  api,
  /async\s+getRecentTopicsPage\(page: number = 1\): Promise<V2exPagedTopicsResult>\s*{[\s\S]*fetchFeedTopicListHtml\(`\/recent\?p=\$\{safePage\}`\)[\s\S]*V2exTabParser\.hasNextPage\(html\)/,
  'recent pagination must keep hasMore from the V2EX pagination footer',
)

assert.match(
  home,
  /this\.vm\.setPagedResultLoader\(\(page: number\) => this\.api\.getAllTopicsPage\(page\)\)/,
  'home "全部" tab must use the all-tab paged result loader',
)

assert.match(
  feedVm,
  /private pagedResultLoader: \(\(page: number\) => Promise<V2exPagedTopicsResult>\) \| null = null/,
  'FeedViewModel must support paged results carrying hasMore',
)

assert.match(
  feedVm,
  /private resolveHasMore\(fetchedCount: number, uniqueCount: number, sourceHasMore: boolean\): boolean[\s\S]*if \(this\.pagedResultLoader\) \{[\s\S]*return sourceHasMore/,
  'FeedViewModel must not stop all-tab recent fallback just because a page was fully de-duplicated',
)

assert.match(
  parser,
  /static hasMoreRecentTopicsLink\(html: string\): boolean/,
  'V2exTabParser must expose More Recent Topics link detection',
)
assert.match(parser, /corner_star\\.png/i, 'V2exTabParser must recognize V2EX pinned topic marker')
assert.match(networkTypes, /pinned\?: number/, 'V2exTopic must carry pinned state')
assert.match(topicCard, /R_TOPIC_PINNED_BADGE/, 'TopicCard must render a localized pinned badge')
assert.match(
  topicCard,
  /if \(this\.isPinned\(\)\) \{\s*this\.PinnedBadge\(\)\s*\}\s*if \(this\.showNodeTag\)/,
  'TopicCard must place the pinned badge beside the node badge instead of inside the title row',
)
assert.match(
  topicCard,
  /private PinnedBadge\(\) \{[\s\S]*\.fontSize\(ThemeConstants\.FONT_SIZE_TAG\)[\s\S]*\.fontColor\(\$r\('sys\.color\.font_secondary'\)\)[\s\S]*\.borderRadius\(ThemeConstants\.RADIUS_SM\)[\s\S]*\.backgroundColor\(\$r\('sys\.color\.ohos_id_color_sub_background'\)\)/,
  'TopicCard pinned badge should share the same quiet chip style as node badges',
)
assert.doesNotMatch(
  topicCard,
  /PINNED_BADGE_|\.border\(\{/,
  'TopicCard pinned badge should not use custom warning colors or an outlined border',
)
assert.doesNotMatch(
  topicCard,
  /Row\(\{ space: 6 \}\) \{[\s\S]{0,160}PinnedBadge/,
  'TopicCard title row should remain text-only so pinned topics do not shift title layout',
)
assert.match(home, /topic\.pinned/, 'home feed render key must include pinned state')

for (const locale of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW', 'ja_JP', 'ko_KR']) {
  const strings = read(`entry/src/main/resources/${locale}/element/string.json`)
  assert.match(strings, /"name": "topic_pinned_badge"/, `${locale} must define topic_pinned_badge`)
}

console.log('home all-tab recent fallback contract OK')
