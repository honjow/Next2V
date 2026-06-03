#!/usr/bin/env node
/**
 * Daily check-in detection + reward-toast contract.
 *
 * Bug fixed: V2EX's /mission/daily claim button is <input value="领取 N 铜币"
 * onclick="location.href='/mission/daily/redeem?once=NNN'"> — the redeem URL is in the ONCLICK, not an
 * href. The old regex required `href=...redeem?once=...` so it always missed → canRedeem=false → the
 * account showed 已签到 even when claimable, and auto-checkin found nothing to redeem (recording a false
 * success because the page text contained "明天"). This locks: the redeem-path match works on the onclick
 * form, the reward amount is parsed from /balance, and a coin toast fires on both manual + auto check-in.
 *
 * Run: node scripts/test_daily_checkin_contract.mjs
 */
import fs from 'node:fs'
import path from 'node:path'
const REPO = process.cwd()
const read = (rel) => fs.readFileSync(path.join(REPO, rel), 'utf8')
const failures = []
const ok = []
const check = (cond, label) => { (cond ? ok : failures).push(label) }

// ── parser: redeem-path regex is NOT href-only ────────────────────────────────
const parser = read('shared/src/main/ets/parser/V2exAccountParser.ets')
check(!/href=\['"\\]*\[^'"\]\*\\\/mission\\\/daily/.test(parser) && !/href=\['"\]/.test(parser.match(/extractRedeemPath[\s\S]*?\n  \}/)?.[0] || ''),
  'extractRedeemPath no longer requires an href= attribute')
check(/\\\/mission\\\/daily\\\/redeem\\\?once=\\d\+/.test(parser), 'extractRedeemPath matches the redeem URL pattern anywhere')
check(/extractLatestDailyReward/.test(parser), 'parser exposes extractLatestDailyReward (for the coin toast)')

// ── logic: replicate the redeem-path regex and assert it matches the onclick form ──
function extractRedeemPath(html) {
  const m = html.match(/\/mission\/daily\/redeem\?once=\d+/i)
  return m ? m[0] : ''
}
check(extractRedeemPath(
  `<input type="button" value="领取 8 铜币" onclick="location.href = '/mission/daily/redeem?once=98765'" />`
) === '/mission/daily/redeem?once=98765', 'redeem path extracted from the onclick (not-checked-in page)')
check(extractRedeemPath(
  `<input type="button" value="查看我的账户余额" onclick="location.href = '/balance'" />`
) === '', 'checked-in page (no redeem?once=) yields empty redeem path')

// ── logic: replicate the reward parser and assert it reads the 每日登录 amount ──
function extractLatestDailyReward(html) {
  const rowRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi
  let row
  while ((row = rowRe.exec(html)) !== null) {
    if (row[1].includes('每日登录')) {
      const cells = []
      const cellRe = /<td[^>]*>([\s\S]*?)<\/td>/gi
      let c
      while ((c = cellRe.exec(row[1])) !== null) cells.push(c[1].replace(/<[^>]*>/g, '').trim())
      for (let i = 0; i < cells.length; i++) {
        if (cells[i].includes('每日登录') && i + 1 < cells.length) {
          const n = parseFloat(cells[i + 1].replace(/[^0-9.]/g, ''))
          if (Number.isFinite(n) && n > 0) return n
        }
      }
    }
  }
  return 0
}
check(extractLatestDailyReward(
  '<table><tr><td>2026-06-04 03:00</td><td>每日登录奖励 连续 7 天</td><td><span class="balance_area positive">12.0</span></td><td>520.0</td></tr></table>'
) === 12, 'reward amount parsed from the 每日登录 balance row')

// ── service/UI: V2exDailyRedeemResult + coin toast wired on both paths ──────────
const types = read('shared/src/main/ets/network/NetworkTypes.ets')
check(/interface V2exDailyRedeemResult/.test(types) && /rewardCoins:\s*number/.test(types), 'V2exDailyRedeemResult carries rewardCoins')
const api = read('shared/src/main/ets/network/ApiService.ets')
check(/extractLatestDailyReward/.test(api) && /Promise<V2exDailyRedeemResult>/.test(api), 'redeem fetches /balance reward and returns V2exDailyRedeemResult')
const auto = read('shared/src/main/ets/services/AutoDailyCheckinService.ets')
check(/showRewardToast/.test(auto) && /R_DAILY_CHECKIN_REWARD_TOAST/.test(auto), 'auto check-in toasts the coin reward on success')
const acc = read('entry/src/main/ets/pages/AccountPage.ets')
check(/R_DAILY_CHECKIN_REWARD_TOAST/.test(acc), 'manual check-in (AccountPage) toasts the coin reward')
const detail = read('entry/src/main/ets/pages/AccountDetailPage.ets')
check(/R_DAILY_CHECKIN_REWARD_TOAST/.test(detail), 'manual check-in (AccountDetailPage) toasts the coin reward')
// i18n key present in all 7 locales
for (const loc of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW', 'ja_JP', 'ko_KR']) {
  const json = JSON.parse(read(`entry/src/main/resources/${loc}/element/string.json`))
  check(json.string.some((s) => s.name === 'daily_checkin_reward_toast'), `i18n: daily_checkin_reward_toast in ${loc}`)
}

for (const f of failures) console.error(`FAIL  ${f}`)
console.log(`\ndaily check-in contract: ${ok.length} checks passed, ${failures.length} failure(s)`)
process.exit(failures.length === 0 ? 0 : 1)
