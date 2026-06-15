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

// ── parser: already-done detection is STRUCTURAL, not loose substrings ──────────
// 2026-06-13 false-success: a degraded 200 /mission/daily read carrying neither the redeem token nor the
// claimed markers was classified already_done off a bare 明天/已完成 substring, so auto check-in persisted
// success without redeeming and silently burned the streak. Lock the strict claimed-page markers and the
// absence of the loose tests (scoped to the `const done =` expression so the rationale comment is exempt).
const doneExpr = parser.match(/const done =[^\n]*/)?.[0] || ''
check(/每日登录奖励已领取/.test(doneExpr) && /查看我的账户余额/.test(doneExpr), 'already-done detection keys off the structural claimed-page markers')
check(doneExpr.length > 0 && !/明天/.test(doneExpr) && !/已完成/.test(doneExpr), 'already-done no longer trusts the loose 明天/已完成 substrings (2026-06-13 false-success guard)')

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
check(/surfaceSuccess/.test(auto) && /app\.string\.daily_checkin_reward_toast/.test(auto), 'auto check-in surfaces the coin reward on success')
check(/surfaceFailure/.test(auto) && /app\.string\.daily_checkin_failed_toast/.test(auto), 'auto check-in surfaces a manual-checkin prompt when the redeem is blocked (status failed)')
check(/AppPrompt\.openToast/.test(auto) && /CheckinNotifier\.publish/.test(auto), 'auto check-in shows a foreground toast and posts a notification for the actionable (failed) case')
const acc = read('entry/src/main/ets/pages/AccountPage.ets')
check(/app\.string\.daily_checkin_reward_toast/.test(acc), 'manual check-in (AccountPage) toasts the coin reward')
const detail = read('entry/src/main/ets/pages/AccountDetailPage.ets')
check(/app\.string\.daily_checkin_reward_toast/.test(detail), 'manual check-in (AccountDetailPage) toasts the coin reward')
// i18n key present in all 7 locales
for (const loc of ['base', 'en_US', 'zh_CN', 'zh_HK', 'zh_TW', 'ja_JP', 'ko_KR']) {
  const json = JSON.parse(read(`entry/src/main/resources/${loc}/element/string.json`))
  for (const key of ['daily_checkin_reward_toast', 'daily_checkin_failed_toast', 'daily_checkin_notify_title']) {
    check(json.string.some((s) => s.name === key), `i18n: ${key} in ${loc}`)
  }
}

// ── redeem goes through a real ArkWeb engine; a headless HTTP redeem cannot pass ──
// V2EX's "请用一个干净安装的浏览器重试" gate blocks a headless HTTP redeem, but a real ArkWeb engine passes
// it (verified on-device, and by the user checking in one-shot via the in-app WebView while an HTTP redeem
// kept failing). So AUTO check-in and the AccountPage manual button redeem through the hidden
// DailyCheckinWebRunner; AccountDetailPage keeps its long-standing HTTP redeem. The day breadcrumb is
// persisted only on a confirmed claim (handleWebResult), so a failed run retries on the next app open.
check(/requestWebRedeem/.test(auto) && /connectWebCheckinRunner/.test(auto),
  'auto check-in hands the redeem off to the hidden web runner')
check(/handleWebResult/.test(auto), 'auto check-in persists the result via the runner callback (handleWebResult)')
check(/saveLastSuccessDate/.test(auto), 'auto check-in persists the success breadcrumb on a confirmed claim')
check(/checkinTrigger/.test(acc) && /DailyCheckinWebRunner/.test(acc),
  'manual check-in (AccountPage) drives its own hidden web runner')
check(/redeemDailyMissionWithCookie/.test(detail), 'manual check-in (AccountDetailPage) redeems over HTTP')
check(fs.existsSync(path.join(REPO, 'entry/src/main/ets/components/DailyCheckinWebRunner.ets')),
  'hidden DailyCheckinWebRunner component present')
check(fs.existsSync(path.join(REPO, 'shared/src/main/ets/state/WebCheckinRunnerState.ets')),
  'WebCheckinRunnerState command bus present')
const index = read('entry/src/main/ets/pages/Index.ets')
check(/DailyCheckinWebRunner/.test(index) && /connectWebCheckinRunner/.test(index),
  'Index mounts the hidden web runner for auto check-in')

for (const f of failures) console.error(`FAIL  ${f}`)
console.log(`\ndaily check-in contract: ${ok.length} checks passed, ${failures.length} failure(s)`)
process.exit(failures.length === 0 ? 0 : 1)
