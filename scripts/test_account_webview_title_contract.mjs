#!/usr/bin/env node
/**
 * In-app WebView title contract.
 *
 * Bug: after AccountWebViewPage was generalized into a shared in-app WebView (dict / node-description
 * links, "open topic in app", …), its NavDestination title stayed hardcoded to "网页登录" (R_NAV_WEB_LOGIN)
 * for every non-balance/settings page — a stale leftover from when this page was the account login view
 * (login now has its own 'webLogin' destination). Fix: title the bar with the page's live <title>
 * (onTitleReceive), keeping the balance/settings first-party titles, and leave it empty until the title
 * arrives instead of showing "网页登录".
 *
 * Run: node scripts/test_account_webview_title_contract.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (p) => readFileSync(p, 'utf8')

// ── holder: a @Trace title + publisher, and a new target resets it ────────────
const holder = read('shared/src/main/ets/state/AccountWebViewUrlState.ets')
assert.match(holder, /@Trace title: string = ''/, 'holder must carry a @Trace title')
assert.match(holder, /export function publishAccountWebViewTitle\(value: string\): void/, 'holder must export publishAccountWebViewTitle')
const pubUrl = holder.match(/export function publishAccountWebViewUrl\([\s\S]*?\n\}/)
assert.ok(pubUrl, 'holder must define publishAccountWebViewUrl')
assert.match(pubUrl[0], /\.title = ''/, 'publishing a new URL must reset the title (no stale title from the previous page)')
assert.match(read('shared/src/main/ets/Index.ets'), /publishAccountWebViewTitle/, 'shared must export publishAccountWebViewTitle')

// ── V2exWebView exposes onTitleReceive and wires it to the raw Web ────────────
const web = read('shared/src/main/ets/components/V2exWebView.ets')
assert.match(web, /@Event onTitleReceive\?: \(event\?: OnTitleReceiveEvent\) => void/, 'V2exWebView must expose an onTitleReceive @Event')
assert.match(web, /\.onTitleReceive\(\(event: OnTitleReceiveEvent\) => \{[\s\S]*?this\.onTitleReceive\(event\)/, 'V2exWebView must forward the Web onTitleReceive to its @Event')

// ── AccountWebViewPage publishes only a REAL <title> ─────────────────────────
const page = read('entry/src/main/ets/pages/AccountWebViewPage.ets')
assert.match(page, /onTitleReceive:\s*\(event\?: OnTitleReceiveEvent\) =>/, 'page must handle onTitleReceive')
assert.match(page, /event\.isRealTitle !== true/, 'page must skip URL-derived titles (isRealTitle false)')
assert.match(page, /publishAccountWebViewTitle\(title\)/, 'page must publish the real <title>')

// ── Index titles the bar with the live title, NOT the stale login label ──────
const index = read('entry/src/main/ets/pages/Index.ets')
const fn = index.match(/private accountWebViewTitle\(\): ResourceStr \{([\s\S]*?)\n  \}/)
assert.ok(fn, 'Index must define accountWebViewTitle')
const body = fn[1]
assert.doesNotMatch(body, /R_NAV_WEB_LOGIN/, 'the in-app WebView title must NOT fall back to the "网页登录" login label')
assert.match(body, /R_BALANCE_DETAILS/, 'balance keeps its first-party title')
assert.match(body, /R_WEB_ACCOUNT_SETTINGS/, 'settings keeps its first-party title')
assert.match(body, /return \(this\.accountWebView\.title \|\| ''\)\.trim\(\)/, 'the default returns the live page title (empty until it arrives)')

console.log('account webview title contract passed')
