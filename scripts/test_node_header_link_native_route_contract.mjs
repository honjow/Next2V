#!/usr/bin/env node
/**
 * Node-description header link routing contract.
 *
 * Bug: node-description links all went to the in-app WebView, even ones that map to a built-in page
 * (e.g. a "/go/xxx" related-node link → should open the native node page). Fix: route native-first —
 * topic /t/, node /go/, member /member/ and search resolve to their native destinations via
 * V2exUrlRouter; only links WITHOUT a native page (dict /d/, /i, external, …) fall back to the
 * cookie-injected in-app WebView. Mirrors TopicDetailPage's in-content link routing.
 *
 * Run: node scripts/test_node_header_link_native_route_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const page = readFileSync('feature/node/src/main/ets/pages/NodeTopicPage.ets', 'utf8')

// ── native-first: openHeaderLink tries a native route BEFORE the WebView fallback ──
const fn = page.match(/private openHeaderLink\(url: string\): void \{([\s\S]*?)\n  \}/)
assert.ok(fn, 'must define openHeaderLink')
const body = fn[1]
const iNative = body.indexOf('this.openNativeRoute(target)')
const iWebview = body.indexOf("pushPathByName('AccountWebView'")
assert.ok(iNative >= 0, 'openHeaderLink must try openNativeRoute')
assert.ok(iWebview >= 0, 'openHeaderLink must keep the in-app WebView fallback')
assert.ok(iNative < iWebview, 'the native route must be attempted BEFORE the WebView fallback')
// guard: native hit returns early so it never also opens the WebView
assert.match(body, /if \(this\.openNativeRoute\(target\)\)\s*\{\s*return/, 'a native hit must return before the WebView fallback')

// ── openNativeRoute: parse + push the four native destinations, false otherwise ──
const nr = page.match(/private openNativeRoute\(url: string\): boolean \{([\s\S]*?)\n  \}/)
assert.ok(nr, 'must define openNativeRoute returning boolean')
const route = nr[1]
assert.match(route, /V2exUrlRouter\.parse\(url\)/, 'openNativeRoute must parse via V2exUrlRouter')
assert.match(route, /if \(!route\)\s*\{\s*return false/, 'a non-V2EX URL returns false (→ caller falls back to WebView)')
assert.match(route, /route\.kind === 'topic'[\s\S]*?pushPathByName\('TopicDetail'/, 'topic → native TopicDetail')
assert.match(route, /route\.kind === 'member'[\s\S]*?pushPathByName\('UserProfile'/, 'member → native UserProfile')
assert.match(route, /route\.kind === 'node'[\s\S]*?pushPathByName\('NodeTopicList'/, 'node (/go/) → native NodeTopicList')
assert.match(route, /route\.kind === 'search'[\s\S]*?pushPathByName\('Search'/, 'search → native Search')
assert.match(route, /return true/, 'a handled route returns true')
assert.ok(route.trimEnd().endsWith('return false'), 'openNativeRoute ends by returning false for unhandled kinds')

console.log('node header link native-route contract passed')
