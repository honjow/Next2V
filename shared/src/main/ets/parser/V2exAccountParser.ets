import type { V2exBalance, V2exDailyMission } from '../network/NetworkTypes'
import { AppStrings } from '../i18n/AppStrings'

export class V2exAccountParser {
  static extractBalance(html: string): V2exBalance {
    const areaBalance = V2exAccountParser.extractBalanceArea(html)
    if (areaBalance) {
      return areaBalance
    }
    const text = V2exAccountParser.compactText(html)
    const gold = V2exAccountParser.extractCoin(text, '金币')
    const silver = V2exAccountParser.extractCoin(text, '银币')
    const bronze = V2exAccountParser.extractCoin(text, '铜币')
    return V2exAccountParser.createBalance(gold, silver, bronze)
  }

  /**
   * STRICT balance read from the top-right `balance_area` widget V2EX renders on every signed-in page
   * (feed, topic, notifications…). Unlike extractBalance(), this NEVER falls back to scanning the whole
   * page for "N 铜币" text — so a topic/feed body mentioning 铜币 cannot fabricate a balance. Returns null
   * when the widget is absent (e.g. a logged-out page or a /api/v2 JSON response). Used to keep the
   * AccountMetaState holder live on every navigation. The widget is an <a> (top nav) or <div> (/balance
   * page); match either, then read only that element's own content.
   */
  static extractNavBalance(html: string): V2exBalance | null {
    const tagRe = /<(a|div)[^>]*class=['"][^'"]*\bbalance_area\b[^'"]*['"][^>]*>/i
    const m = html.match(tagRe)
    if (!m || m.index === undefined || !m[1]) {
      return null
    }
    const start = m.index + m[0].length
    const closeTag = '</' + m[1].toLowerCase() + '>'
    const closeIdx = html.toLowerCase().indexOf(closeTag, start)
    const inner =
      closeIdx >= 0 ? html.substring(start, closeIdx) : html.substring(start, start + 400)
    const text = V2exAccountParser.compactText(inner)
    if (text.indexOf('金币') >= 0 || text.indexOf('银币') >= 0 || text.indexOf('铜币') >= 0) {
      return V2exAccountParser.createBalance(
        V2exAccountParser.extractCoin(text, '金币'),
        V2exAccountParser.extractCoin(text, '银币'),
        V2exAccountParser.extractCoin(text, '铜币'),
      )
    }
    // Compact form: the top-nav widget shows the coin counts as bare numbers beside the coin images.
    const nums = V2exAccountParser.extractNumbers(text)
    if (nums.length >= 3) {
      return V2exAccountParser.createBalance(nums[0], nums[1], nums[2])
    }
    if (nums.length === 2) {
      return V2exAccountParser.createBalance(0, nums[0], nums[1])
    }
    if (nums.length === 1) {
      return V2exAccountParser.createBalance(0, 0, nums[0])
    }
    return null
  }

  static extractDailyMission(html: string): V2exDailyMission {
    const redeemPath = V2exAccountParser.extractRedeemPath(html)
    if (redeemPath) {
      return { canRedeem: true, redeemPath, message: 'daily_checkin_available' }
    }
    const text = V2exAccountParser.compactText(html)
    // STRICT already-done detection. A genuine claimed /mission/daily renders the specific "每日登录奖励已领取"
    // line and a "查看我的账户余额" CTA, and carries no redeem?once= URL. The old loose test (已领取/已完成/明天)
    // also fired on degraded/anti-bot 200 pages that merely contained one of those words while lacking the
    // redeem token — so auto check-in wrote a false "already done" success and burned the whole day
    // (observed 2026-06-13 03:17: a degraded read with neither the redeem token nor the claimed markers was
    // classified already_done). Anything that is neither claimable nor a structurally-confirmed claimed page
    // stays 'daily_checkin_unavailable' (transient → retried, never persisted as success).
    const done = text.indexOf('每日登录奖励已领取') >= 0 || text.indexOf('查看我的账户余额') >= 0
    return {
      canRedeem: false,
      redeemPath: '',
      message: done ? 'already_checked_in_today' : 'daily_checkin_unavailable',
    }
  }

  private static extractCoin(text: string, label: string): number {
    const re = new RegExp(`(\\d+(?:\\.\\d+)?)\\s*${label}`)
    const m = text.match(re)
    if (!m || !m[1]) {
      return 0
    }
    return Number.parseFloat(m[1])
  }

  private static extractRedeemPath(html: string): string {
    // V2EX's /mission/daily renders the claim button as <input value="领取 N 铜币"
    // onclick="location.href = '/mission/daily/redeem?once=NNN'"> — the redeem URL lives in the ONCLICK,
    // not an href attribute. Matching only `href=` (the old regex) missed it entirely, so canRedeem was
    // always false → the account showed 已签到 even when claimable, and auto-checkin found nothing to
    // redeem. Match the URL anywhere instead (mirrors liaoliao666/v2ex). When already checked in the page
    // shows "查看我的账户余额" and carries no redeem?once= URL, so an anywhere-match stays correct.
    const re = /\/mission\/daily\/redeem\?once=\d+/i
    const m = html.match(re)
    return m ? V2exAccountParser.decodeHtml(m[0]) : ''
  }

  /**
   * Reward amount (铜币) of the most recent "每日登录" entry on the /balance table, used for the post
   * check-in toast. V2EX's balance table row is [time, 每日登录…, delta, balance]; the delta cell right
   * after the description is the reward. Returns 0 when not found (toast falls back to a plain success).
   */
  static extractLatestDailyReward(html: string): number {
    const rowRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi
    let row: RegExpExecArray | null = rowRe.exec(html)
    while (row) {
      if (row[1].indexOf('每日登录') >= 0) {
        const cells: string[] = []
        const cellRe = /<td[^>]*>([\s\S]*?)<\/td>/gi
        let cell: RegExpExecArray | null = cellRe.exec(row[1])
        while (cell) {
          cells.push(V2exAccountParser.compactText(cell[1]))
          cell = cellRe.exec(row[1])
        }
        for (let i = 0; i < cells.length; i++) {
          if (cells[i].indexOf('每日登录') >= 0 && i + 1 < cells.length) {
            const amount = Number.parseFloat(cells[i + 1].replace(/[^0-9.]/g, ''))
            if (Number.isFinite(amount) && amount > 0) {
              return amount
            }
          }
        }
      }
      row = rowRe.exec(html)
    }
    return 0
  }

  private static extractBalanceArea(html: string): V2exBalance | null {
    const areaRe =
      /<div[^>]*class=['"][^'"]*\bbalance_area\b[^'"]*\bbigger\b[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i
    const m = html.match(areaRe)
    if (!m || !m[1]) {
      return null
    }
    const text = V2exAccountParser.compactText(m[1])
    if (text.indexOf('金币') >= 0 || text.indexOf('银币') >= 0 || text.indexOf('铜币') >= 0) {
      return V2exAccountParser.createBalance(
        V2exAccountParser.extractCoin(text, '金币'),
        V2exAccountParser.extractCoin(text, '银币'),
        V2exAccountParser.extractCoin(text, '铜币'),
      )
    }
    const compactBalance = V2exAccountParser.extractCompactBalance(text)
    if (compactBalance) {
      return compactBalance
    }
    const nums = V2exAccountParser.extractNumbers(text)
    if (nums.length >= 3) {
      return V2exAccountParser.createBalance(nums[0], nums[1], nums[2])
    }
    if (nums.length === 2) {
      return V2exAccountParser.createBalance(0, nums[0], nums[1])
    }
    if (nums.length === 1) {
      return V2exAccountParser.createBalance(0, 0, nums[0])
    }
    return null
  }

  private static extractCompactBalance(text: string): V2exBalance | null {
    const withGold = text.match(/^(\d+)\s+(\d+)\s+0\.(\d+)$/)
    if (withGold && withGold[1] && withGold[2] && withGold[3]) {
      return V2exAccountParser.createBalance(
        Number.parseInt(withGold[1]),
        Number.parseInt(withGold[2]),
        Number.parseFloat(`0.${withGold[3]}`),
      )
    }
    const withoutGold = text.match(/^(\d+)\s+0\.(\d+)$/)
    if (withoutGold && withoutGold[1] && withoutGold[2]) {
      return V2exAccountParser.createBalance(
        0,
        Number.parseInt(withoutGold[1]),
        Number.parseFloat(`0.${withoutGold[2]}`),
      )
    }
    return null
  }

  private static extractNumbers(text: string): number[] {
    const nums: number[] = []
    const re = /\d+/g
    let m: RegExpExecArray | null = re.exec(text)
    while (m && m[0]) {
      nums.push(Number.parseInt(m[0]))
      m = re.exec(text)
    }
    return nums
  }

  private static createBalance(gold: number, silver: number, bronze: number): V2exBalance {
    const parts: string[] = []
    if (gold > 0) {
      parts.push(
        `${V2exAccountParser.formatCoinAmount(gold)} ${AppStrings.text($r('app.string.account_balance_gold'), 'Gold')}`,
      )
    }
    if (silver > 0) {
      parts.push(
        `${V2exAccountParser.formatCoinAmount(silver)} ${AppStrings.text($r('app.string.account_balance_silver'), 'Silver')}`,
      )
    }
    parts.push(
      `${V2exAccountParser.formatCoinAmount(bronze)} ${AppStrings.text($r('app.string.account_balance_bronze'), 'Bronze')}`,
    )
    return { gold, silver, bronze, summary: parts.join(' · ') }
  }

  private static formatCoinAmount(value: number): string {
    if (Math.floor(value) === value) {
      return value.toString()
    }
    return value.toFixed(2).replace(/0+$/, '').replace(/\.$/, '')
  }

  private static compactText(html: string): string {
    return V2exAccountParser.decodeHtml(
      html
        .replace(/<script[\s\S]*?<\/script>/gi, ' ')
        .replace(/<style[\s\S]*?<\/style>/gi, ' ')
        .replace(/<[^>]+>/g, ' '),
    )
      .replace(/\s+/g, ' ')
      .trim()
  }

  private static decodeHtml(value: string): string {
    return value
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
  }
}
