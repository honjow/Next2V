#!/usr/bin/env node
/**
 * Native-first link routing contract (shared V2exRouteNavigator).
 *
 * A V2EX URL that maps to a built-in page (topic /t/, node /go/, member /member/, search) must open the
 * native page; only URLs without a native page (dict /d/, /i, external, …) fall back to the in-app
 * WebView / system browser. This policy lives in ONE place — shared/utils/V2exRouteNavigator — and is
 * used by the deep-link handler (Index), topic/reply in-content links (TopicDetailPage) and
 * node-description links (NodeTopicPage), so they all route identically.
 *
 * Run: node scripts/test_node_header_link_native_route_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (p) => readFileSync(p, 'utf8')

// ── the single source of truth: V2exRouteNavigator pushes the 4 native destinations ──
const nav = read('shared/src/main/ets/utils/V2exRouteNavigator.ets')
assert.match(nav, /static openInApp\(stack: NavPathStack, url: string\): boolean/, 'V2exRouteNavigator.openInApp(stack, url) must exist')
assert.match(nav, /static pushRoute\(stack: NavPathStack, route: V2exRoute\): boolean/, 'V2exRouteNavigator.pushRoute(stack, route) must exist')
assert.match(nav, /V2exUrlRouter\.parse\(url\)/, 'openInApp must parse the URL via V2exUrlRouter')
assert.match(nav, /if \(!route\)\s*\{\s*return false/, 'a non-V2EX URL returns false (→ caller falls back)')
assert.match(nav, /route\.kind === 'topic'[\s\S]*?pushPathByName\('TopicDetail'/, 'topic → native TopicDetail')
assert.match(nav, /route\.kind === 'member'[\s\S]*?pushPathByName\('UserProfile'/, 'member → native UserProfile')
assert.match(nav, /route\.kind === 'node'[\s\S]*?pushPathByName\('NodeTopicList'/, 'node (/go/) → native NodeTopicList')
assert.match(nav, /route\.kind === 'search'[\s\S]*?SearchQueryBus\.publishPending[\s\S]*?pushPathByName\('Search'/, 'search → native Search')
// imports its deps from sibling modules, NOT the barrel (no cycle)
assert.match(nav, /from '\.\.\/model\/RouteParams'/, 'route param types come from ./model/RouteParams, not the barrel (avoids a cycle)')
assert.doesNotMatch(nav, /from '\.\.\/Index'/, 'V2exRouteNavigator must NOT import from the barrel (cycle)')

// ── node-description links: native-first, WebView only as fallback ────────────
const node = read('feature/node/src/main/ets/pages/NodeTopicPage.ets')
const fn = node.match(/private openHeaderLink\(url: string\): void \{([\s\S]*?)\n  \}/)
assert.ok(fn, 'NodeTopicPage must define openHeaderLink')
const body = fn[1]
const iNative = body.indexOf('V2exRouteNavigator.openInApp(this.stack, target)')
const iWebview = body.indexOf("pushPathByName('AccountWebView'")
assert.ok(iNative >= 0, 'openHeaderLink must try V2exRouteNavigator.openInApp first')
assert.ok(iWebview >= 0, 'openHeaderLink must keep the in-app WebView fallback')
assert.ok(iNative < iWebview, 'native routing must be attempted BEFORE the WebView fallback')
assert.match(body, /if \(V2exRouteNavigator\.openInApp\(this\.stack, target\)\)\s*\{\s*return/, 'a native hit returns before the WebView fallback')
assert.doesNotMatch(node, /private openNativeRoute\(/, 'the per-page native-route copy must be gone (consolidated into V2exRouteNavigator)')

// ── topic/reply in-content links delegate to the same helper ──────────────────
const detail = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
assert.match(detail, /V2exRouteNavigator\.openInApp\(this\.stack, clean\)/, 'TopicDetailPage.openContentLink must use V2exRouteNavigator')
assert.doesNotMatch(detail, /private openV2exRoute\(/, 'TopicDetailPage.openV2exRoute copy must be gone (consolidated)')

// ── deep-link handler delegates to the same helper ────────────────────────────
const index = read('entry/src/main/ets/pages/Index.ets')
assert.match(index, /V2exRouteNavigator\.openInApp\(this\.ns, url\)/, 'Index deep-link routing must use V2exRouteNavigator')
assert.doesNotMatch(index, /private pushV2exRoute\(/, 'Index.pushV2exRoute copy must be gone (consolidated)')
assert.doesNotMatch(read('entry/src/main/ets/model/IndexRouteCoordinator.ets'), /static topicParams\(/, 'the dead IndexRouteCoordinator route-param builders must be removed')

console.log('native-first link routing contract passed')
