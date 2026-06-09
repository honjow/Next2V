#!/usr/bin/env node
/**
 * In-app cookie WebView for non-topic links + topic "open in app".
 *
 * - Node-description links (e.g. the dict node's relative "/d/" link) opened nothing (no external handler);
 *   they now route into the in-app WebView.
 * - The topic title-bar gained "应用内打开" (open in app) alongside the external "浏览器打开".
 * - AccountWebViewPage is generalized into a first-party-OR-external WebView: it resolves relative paths
 *   against the V2EX origin and injects the session cookie ONLY for that origin (never to third parties).
 *
 * Run: node scripts/test_inapp_webview_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (p) => readFileSync(p, 'utf8')

// ── topic title-bar: "open in app" menu item ──────────────────────────────────
const coord = read('entry/src/main/ets/model/TopicDetailTitleBarCoordinator.ets')
assert.match(coord, /\|\s*'openInApp'/, "TopicDetailTitleAction union must include 'openInApp'")
assert.match(coord, /\$r\('app\.string\.topic_action_open_in_app'\),\s*action:\s*'openInApp'/, "menu must list the 'openInApp' action with its label")
assert.ok(coord.indexOf("action: 'openInApp'") < coord.indexOf("action: 'openBrowser'"), 'open-in-app should sit just before open-in-browser')

const detail = read('feature/detail/src/main/ets/pages/TopicDetailPage.ets')
assert.match(detail, /action === 'openInApp'/, 'TopicDetailPage must handle the openInApp action')
assert.match(detail, /private openInAppWebView\(/, 'TopicDetailPage must define openInAppWebView')
assert.match(detail, /publishAccountWebViewUrl\(target\)[\s\S]{0,80}pushPathByName\('AccountWebView'/, 'openInAppWebView must publish the URL then push the in-app WebView route')

// ── node-description links route to the in-app WebView ────────────────────────
const node = read('feature/node/src/main/ets/pages/NodeTopicPage.ets')
assert.match(node, /onHeaderLinkClick:\s*\(url: string\)\s*=>/, 'NodeTopicPage must pass onHeaderLinkClick to NodeInfoCard')
assert.match(node, /private openHeaderLink\(/, 'NodeTopicPage must define openHeaderLink')
assert.match(node, /startsWith\('\/'\)[\s\S]{0,80}startsWith\('http/, 'openHeaderLink must route relative + http(s) links into the WebView')
assert.match(node, /publishAccountWebViewUrl\(target\)[\s\S]{0,80}pushPathByName\('AccountWebView'/, 'openHeaderLink must publish + push the in-app WebView route')

// ── AccountWebViewPage generalized: relative-resolve + origin-scoped cookie ────
const web = read('entry/src/main/ets/pages/AccountWebViewPage.ets')
assert.match(web, /target\.startsWith\('\/'\)[\s\S]{0,60}target = origin \+ target/, 'WebView must resolve a relative path against the V2EX origin')
assert.match(web, /target\.startsWith\('http:\/\/'\)[\s\S]{0,30}target\.startsWith\('https:\/\/'\)/, 'WebView must accept any http(s) URL (first-party OR external)')
assert.match(web, /const isV2exOrigin = origin\.length > 0 && target\.startsWith\(origin\)/, 'first-party is determined by the V2EX origin')
assert.match(web, /if \(isV2exOrigin && cookie\)/, 'cookie is injected ONLY for the V2EX origin (never leaked to third parties)')
assert.doesNotMatch(web, /isV2exAllowedUrl/, 'the first-party-only rejection is gone (external pages are now allowed)')

// ── i18n: topic_action_open_in_app across all 7 locales + AppStrings ──────────
for (const loc of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW', 'ja_JP', 'ko_KR']) {
  const json = JSON.parse(read(`entry/src/main/resources/${loc}/element/string.json`))
  assert.ok(json.string.some((s) => s.name === 'topic_action_open_in_app'), `i18n: topic_action_open_in_app in ${loc}`)
}
// The R_TOPIC_ACTION_OPEN_IN_APP constant was retired by the ResourceManager migration; the title-bar
// coordinator now references the label inline via $r('app.string.topic_action_open_in_app'). The 7-locale
// resource presence is asserted above; here we pin the menu's use of the resource key.
assert.match(coord, /\$r\('app\.string\.topic_action_open_in_app'\)/, 'topic title-bar menu must reference the open-in-app label resource')

console.log('in-app webview contract passed')
