#!/usr/bin/env node
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const repo = process.env.SOURCE_ROOT || process.cwd()
const pagePath = 'feature/node/src/main/ets/pages/NodeTopicPage.ets'
const vmPath = 'feature/node/src/main/ets/viewmodel/NodeViewModel.ets'
const apiPath = 'shared/src/main/ets/network/ApiService.ets'
const sessionParserPath = 'shared/src/main/ets/parser/V2exSessionParser.ets'

const pageSource = fs.readFileSync(path.join(repo, pagePath), 'utf8')
const vmSource = fs.readFileSync(path.join(repo, vmPath), 'utf8')
const apiSource = fs.readFileSync(path.join(repo, apiPath), 'utf8')
const sessionParserSource = fs.readFileSync(path.join(repo, sessionParserPath), 'utf8')

function mustContain(source, pattern, message) {
  assert.match(source, pattern, message)
}

function mustNotContain(source, pattern, message) {
  assert.doesNotMatch(source, pattern, message)
}

// NodeTopicPage must snapshot the current web cookie before either plain-web page-1 or
// API-v2→web fallback can run. /go/sandbox redirects anonymous requests to /signin, so
// a logged-in app must not let the web fallback silently become anonymous HTML.
mustContain(pageSource, /CookieJarSettings/, 'NodeTopicPage must import/use CookieJarSettings for node-topic web loads')
mustContain(
  pageSource,
  /setNodeTopicsWebCookie\(CookieJarSettings\.getCurrentCookie\(\)\)[\s\S]*AuthSettings\.load/,
  'NodeTopicPage must load the current cookie before choosing API-v2 vs web node-topic source'
)
mustContain(
  pageSource,
  /loadNodeTopicsWebFallback[\s\S]*loadNodeTopics\(nodeName, \{ requestId: requestId, source: 'web', fallback: true \}\)/,
  'API-v2 page-one fallback must still use the same VM web-load path that carries the cookie'
)

// The VM carries the cookie across page 1 and load-more so pagination cannot switch back
// from authenticated /go/{node} HTML to anonymous public HTML.
mustContain(vmSource, /private nodeTopicsWebCookie: string = ''/, 'NodeViewModel must hold node-topic web cookie source context')
mustContain(vmSource, /setNodeTopicsWebCookie\(cookie: string\): void[\s\S]*\(cookie \|\| ''\)\.trim\(\)/, 'NodeViewModel must normalize the carried web cookie')
mustContain(vmSource, /getNodeTopicsPage\(nodeName, 1, this\.nodeTopicsWebCookie\)/, 'page-one web node-topic load must pass the carried cookie')
mustContain(vmSource, /getNodeTopicsPage\(nodeName, nextPage, this\.nodeTopicsWebCookie\)/, 'load-more web node-topic load must pass the carried cookie')

// ApiService must preserve public-node behavior while adding an authenticated HTML path for
// login-gated nodes. Cookie-backed signin/session pages are auth errors, not empty topic lists.
mustContain(apiSource, /getNodeTopicsPage\(\s*nodeName: string,\s*page: number = 1,\s*cookie: string = '',?\s*\)/, 'getNodeTopicsPage must accept an optional cookie')
mustContain(apiSource, /const useCookie = \(cookie \|\| ''\)\.trim\(\)\.length > 0/, 'getNodeTopicsPage must branch on cookie presence')
mustContain(apiSource, /useCookie\s*\?\s*await this\.getCookieHtml\(endpoint, cookie\)\s*:\s*await this\.http\.getText\(endpoint\)/, 'cookie-backed node-topic loads must use getCookieHtml and public loads must keep http.getText')
mustContain(apiSource, /V2exSessionParser\.extractUsername\(html\)/, 'cookie-backed node-topic loads must classify session HTML with V2exSessionParser')
mustContain(apiSource, /if \(useCookie && !hasUsername\)[\s\S]*node_topic_session_rejected[\s\S]*classification: 'signin_or_session_expired'[\s\S]*throw ApiErrors\.webSessionExpired\(\)/, 'cookie-backed signin/session-expired HTML must be rejected instead of parsed as []')
mustContain(apiSource, /node_topic_html_received[\s\S]*source: sourceLabel[\s\S]*hasCookie: useCookie[\s\S]*count: topics\.length[\s\S]*classification: 'topics'/, 'node-topic HTML boundary must log source/cookie/count classification without raw cookies or HTML')
mustContain(apiSource, /assertNoTwoFactorChallenge\(endpoint, res\.text, res\.location\)/, 'cookie HTML helper must preserve 2FA challenge rejection')
mustContain(sessionParserSource, /class=["']top|hasClass\(className, 'top'\)/, 'session parser must identify an authenticated top-bar member link')

// Empty state must be centered by an overlay matching LoadingView, not rendered as a top-aligned
// ListItem. The zero-height ListItem keeps the refreshable list present; the visible EmptyView is
// outside the list, full-height, safe-area aware, and non-intercepting.
mustNotContain(pageSource, /ListItem\(\)\s*\{\s*this\.EmptyView\(\)\s*\}/, 'empty state must not be the old top-aligned bare ListItem')
mustContain(pageSource, /ListItem\(\)\s*\{\s*Column\(\)\s*(?:\{\})?\.height\(0\)\s*\}/, 'empty list must keep only a zero-height refresh placeholder inside PagedListScaffold')
mustContain(pageSource, /else if \(!this\.vm\.errorMessage && this\.vm\.nodeTopics\.length === 0\)[\s\S]*this\.EmptyView\(\)/, 'visible true-empty state must render as a Stack overlay distinct from loading and error')
mustContain(pageSource, /CardEmptyState\(\{\s*message: AppStrings\.text\(\$r\('app\.string\.node_no_topics'\)[\s\S]*expand: false,?\s*\}\)[\s\S]*\.justifyContent\(FlexAlign\.Center\)[\s\S]*\.height\('100%'\)[\s\S]*this\.layout\.topAvoidHeight \+ ThemeConstants\.TITLE_BAR_HEIGHT[\s\S]*\.hitTestBehavior\(HitTestMode\.None\)/, 'EmptyView must center the message in the safe content area and not block refresh gestures')

// No State Management V1 decorators in touched files. V2 decorators (@ComponentV2, @ObservedV2,
// @Trace, @Local, @Param) are allowed.
for (const [file, source] of [[pagePath, pageSource], [vmPath, vmSource], [apiPath, apiSource]]) {
  mustNotContain(
    source,
    /@(Component|State|Prop|Link|Watch|StorageLink|StorageProp|Provide|Consume|ObjectLink|Observed|Track|LocalStorageLink|LocalStorageProp)\b/,
    `${file} must not introduce State Management V1 decorators`
  )
}

console.log('node sandbox topics contract passed')
