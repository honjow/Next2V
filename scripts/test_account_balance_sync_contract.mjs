#!/usr/bin/env node
/**
 * Account balance consistency contract.
 *
 * Bug: the 我的 card (AccountPage) and the 账号 detail page (AccountDetailPage) each kept their own private
 * @Local accountBalance, each fetched /balance independently, and only shared a non-reactive last-writer
 * preferences cache — so the two surfaces could show different coin totals. Fix: one shared AccountMetaState
 * holder, written only by AccountMetaPublisher, mirrored by both pages. Plus real-time sync: the top-right
 * balance widget present on every signed-in page is harvested at the getCookieHtml chokepoint.
 *
 * Run: node scripts/test_account_balance_sync_contract.mjs
 */
import fs from 'node:fs'
import path from 'node:path'
const REPO = process.cwd()
const read = (rel) => fs.readFileSync(path.join(REPO, rel), 'utf8')
const failures = []
const ok = []
const check = (cond, label) => { (cond ? ok : failures).push(label) }

// ── shared holder: one reactive source of truth ───────────────────────────────
const holder = read('shared/src/main/ets/state/AccountMetaState.ets')
check(/@ObservedV2/.test(holder) && /class AccountMetaState/.test(holder), 'AccountMetaState is an @ObservedV2 holder')
for (const f of ['ownerKey', 'balance', 'dailyMission', 'updatedAt', 'ownerCookieHash']) {
  check(new RegExp(`@Trace\\s+${f}`).test(holder), `holder has @Trace ${f}`)
}
check(/connectAccountMeta/.test(holder), 'holder exposes connectAccountMeta()')

// ── single-writer publisher ───────────────────────────────────────────────────
const pub = read('shared/src/main/ets/settings/AccountMetaPublisher.ets')
check(/publishFetched/.test(pub) && /saveCache/.test(pub), 'publishFetched mutates holder AND persists cache')
check(/publishCached/.test(pub) && /holder\.ownerKey === ownerKey && holder\.balance/.test(pub), 'publishCached never downgrades a live holder value')
check(/harvestFromHtml/.test(pub) && /getCurrentCookie\(\)/.test(pub), 'harvestFromHtml guards on the current cookie')
check(/ownerCookieHash !== AccountMetaPublisher\.cookieHash\(cookie\)/.test(pub), 'harvest gated on the holder-owning cookie (no cross-account write during a switch)')

// ── both surfaces MIRROR the holder, do not keep an independent source ─────────
for (const rel of ['entry/src/main/ets/pages/AccountPage.ets', 'entry/src/main/ets/pages/AccountDetailPage.ets']) {
  const page = read(rel)
  const name = rel.split('/').pop()
  check(/connectAccountMeta\(\)/.test(page), `${name}: connects the shared holder`)
  check(/@Monitor\('accountMeta\.updatedAt'\)/.test(page), `${name}: mirrors via @Monitor('accountMeta.updatedAt')`)
  check(/AccountMetaPublisher\.publishFetched/.test(page), `${name}: routes fetched meta through the publisher`)
  check(/mirrorAccountMetaFromHolder/.test(page) && /this\.accountMeta\.ownerKey !== ownerKey/.test(page), `${name}: ownerKey-gated mirror (no cross-account bleed)`)
  check(!/private saveAccountMetaCache/.test(page), `${name}: no private cache writer (publisher owns persistence)`)
}

// ── real-time harvest wired at the single authed-HTML chokepoint ──────────────
const api = read('shared/src/main/ets/network/ApiService.ets')
check(/AccountMetaPublisher\.harvestFromHtml\(res\.text, cookie\)/.test(api), 'getCookieHtml harvests the balance widget on every authed page')

// ── parser: STRICT nav-widget extraction (no whole-page text fallback) ─────────
const parser = read('shared/src/main/ets/parser/V2exAccountParser.ets')
check(/extractNavBalance/.test(parser), 'parser exposes extractNavBalance')

// logic replica of extractNavBalance, asserted against the REAL on-device markup
function compactText(html) { return html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim() }
function extractNavBalance(html) {
  const m = html.match(/<(a|div)[^>]*class=['"][^'"]*\bbalance_area\b[^'"]*['"][^>]*>/i)
  if (!m || m.index === undefined) return null
  const start = m.index + m[0].length
  const closeTag = '</' + m[1].toLowerCase() + '>'
  const closeIdx = html.toLowerCase().indexOf(closeTag, start)
  const inner = closeIdx >= 0 ? html.substring(start, closeIdx) : html.substring(start, start + 400)
  const text = compactText(inner)
  if (text.includes('金币') || text.includes('银币') || text.includes('铜币')) {
    const coin = (t, l) => { const r = t.match(new RegExp(`(\\d+(?:\\.\\d+)?)\\s*${l}`)); return r ? parseFloat(r[1]) : 0 }
    return { gold: coin(text, '金币'), silver: coin(text, '银币'), bronze: coin(text, '铜币') }
  }
  const nums = (text.match(/\d+/g) || []).map((n) => parseInt(n))
  if (nums.length >= 3) return { gold: nums[0], silver: nums[1], bronze: nums[2] }
  if (nums.length === 2) return { gold: 0, silver: nums[0], bronze: nums[1] }
  if (nums.length === 1) return { gold: 0, silver: 0, bronze: nums[0] }
  return null
}
// EXACT markup captured on-device from the signed-in top nav (#money widget).
const liveNav = `<div id="money"><a href="/balance" class="balance_area" style="">1 <img src="/static/img/gold@2x.png" height="16" alt="G" border="0" /> 4 <img src="/static/img/silver@2x.png" height="16" alt="S" border="0" /> 69 <img src="/static/img/bronze@2x.png" height="16" alt="B" border="0" /></a></div>`
const nav = extractNavBalance(liveNav)
check(nav && nav.gold === 1 && nav.silver === 4 && nav.bronze === 69, 'nav widget parses 1 gold / 4 silver / 69 bronze from the real markup')
// STRICT: a logged-out page (no widget) yields null, not a fabricated balance
check(extractNavBalance('<html><body>no money widget here</body></html>') === null, 'absent widget → null')
// STRICT: topic body mentioning 铜币 must NOT fabricate a balance (no balance_area element present)
check(extractNavBalance('<div class="topic_content">签到获得 8 铜币，余额很多</div>') === null, 'topic body 铜币 text is not mistaken for a balance')

for (const f of failures) console.error(`FAIL  ${f}`)
console.log(`\naccount balance sync contract: ${ok.length} checks passed, ${failures.length} failure(s)`)
process.exit(failures.length === 0 ? 0 : 1)
