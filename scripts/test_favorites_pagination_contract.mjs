#!/usr/bin/env node
/**
 * Favorites (主题收藏 /my/topics) pagination contract.
 *
 * Bug: MyTopicsPage decided "has more" with `topics.length >= 20`, but the favorites page returns fewer
 * than 20 items per page — so after page 1 it set hasMore=false and never auto-loaded more. Fix:
 * getMyTopicsWithCookie returns { topics, hasMore } where hasMore is read from the pagination footer
 * (V2exTabParser.hasNextPage: page_current + the highest ?p=N), and MyTopicsPage uses result.hasMore.
 *
 * Run: node scripts/test_favorites_pagination_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (p) => readFileSync(p, 'utf8')

// ── parser: hasNextPage exists and is footer-based ────────────────────────────
const tab = read('shared/src/main/ets/parser/V2exTabParser.ets')
assert.match(tab, /static hasNextPage\(html: string\): boolean/, 'V2exTabParser.hasNextPage must exist')
assert.match(tab, /page_current/, 'hasNextPage must read the page_current marker')
assert.match(tab, /\[\?&\]p=/, 'hasNextPage must scan ?p=N for the max page')

// ── API returns { topics, hasMore } from the footer, not a count ──────────────
const api = read('shared/src/main/ets/network/ApiService.ets')
assert.match(api, /async getMyTopicsWithCookie\(cookie: string, page: number = 1\): Promise<V2exPagedTopicsResult>/, 'getMyTopicsWithCookie must return V2exPagedTopicsResult')
assert.match(api, /const hasMore = V2exTabParser\.hasNextPage\(html\)/, 'hasMore must come from the pagination footer')
assert.match(read('shared/src/main/ets/network/NetworkTypes.ets'), /export interface V2exPagedTopicsResult\s*\{\s*topics: V2exTopic\[\]\s*hasMore: boolean/, 'V2exPagedTopicsResult { topics, hasMore } must be defined')

// ── page consumes result.hasMore, no per-page-count heuristic left ────────────
const page = read('entry/src/main/ets/pages/MyTopicsPage.ets')
assert.match(page, /\.then\(\(result: V2exPagedTopicsResult\) =>/, 'MyTopicsPage must consume the paged result')
assert.match(page, /this\.hasMore = result\.hasMore/, 'hasMore must come from the result')
assert.doesNotMatch(page, /length >= this\.PAGE_SIZE/, 'the brittle topics.length >= PAGE_SIZE heuristic must be gone')
assert.doesNotMatch(page, /PAGE_SIZE/, 'the unused PAGE_SIZE constant must be removed')

// ── logic replica of hasNextPage ──────────────────────────────────────────────
function hasNextPage(html) {
  const clean = html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ').replace(/<!--[\s\S]*?-->/g, ' ')
  const cur = clean.match(/<a[^>]*class=['"][^'"]*page_current[^'"]*['"][^>]*>(\d+)<\/a>/i)
  if (cur && cur[1]) {
    const current = parseInt(cur[1], 10)
    let max = current
    const re = /[?&]p=(\d+)/gi
    let m
    while ((m = re.exec(clean)) !== null) max = Math.max(max, parseInt(m[1] || '0', 10))
    return max > current
  }
  return /[?&]p=2/i.test(clean)
}
// page 1 of 3 → has more (even though only ~14 items, fewer than 20)
const p1 = `<a href="/my/topics?p=1" class="page_current">1</a><a href="/my/topics?p=2" class="page_normal">2</a><a href="/my/topics?p=3" class="page_normal">3</a>`
assert.equal(hasNextPage(p1), true, 'page 1 of 3 has a next page')
// last page → no more
const pLast = `<a href="/my/topics?p=1" class="page_normal">1</a><a href="/my/topics?p=2" class="page_normal">2</a><a href="/my/topics?p=3" class="page_current">3</a>`
assert.equal(hasNextPage(pLast), false, 'the last page has no next page')
// single page (no footer) → no more
assert.equal(hasNextPage('<div class="box"><div class="cell item">only a few favorites</div></div>'), false, 'a single page has no next page')
// a `?p=2` only inside a stripped <script> must NOT count as a next page
assert.equal(hasNextPage('<script>var u="/my/topics?p=2"</script><div class="cell item">x</div>'), false, 'a ?p=2 buried in script must not signal a next page')

console.log('favorites pagination contract passed')
