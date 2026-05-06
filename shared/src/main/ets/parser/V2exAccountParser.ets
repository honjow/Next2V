import type { V2exBalance, V2exDailyMission } from '../network/NetworkTypes'

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

  static extractDailyMission(html: string): V2exDailyMission {
    const redeemPath = V2exAccountParser.extractRedeemPath(html)
    if (redeemPath) {
      return { canRedeem: true, redeemPath, message: '今日可签到' }
    }
    const text = V2exAccountParser.compactText(html)
    const done = text.indexOf('已领取') >= 0 || text.indexOf('已完成') >= 0 || text.indexOf('明天') >= 0
    return {
      canRedeem: false,
      redeemPath: '',
      message: done ? '今日已签到' : '暂不可签到'
    }
  }

  private static extractCoin(text: string, label: string): number {
    const re = new RegExp(`(\\d+)\\s*${label}`)
    const m = text.match(re)
    if (!m || !m[1]) {
      return 0
    }
    return Number.parseInt(m[1])
  }

  private static extractRedeemPath(html: string): string {
    const re = /href=['"]([^'"]*\/mission\/daily\/redeem\?once=\d+[^'"]*)['"]/i
    const m = html.match(re)
    return m && m[1] ? V2exAccountParser.decodeHtml(m[1]) : ''
  }

  private static extractBalanceArea(html: string): V2exBalance | null {
    const areaRe = /<div[^>]*class=['"][^'"]*\bbalance_area\b[^'"]*\bbigger\b[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i
    const m = html.match(areaRe)
    if (!m || !m[1]) {
      return null
    }
    const text = V2exAccountParser.compactText(m[1])
    if (text.indexOf('金币') >= 0 || text.indexOf('银币') >= 0 || text.indexOf('铜币') >= 0) {
      return V2exAccountParser.createBalance(
        V2exAccountParser.extractCoin(text, '金币'),
        V2exAccountParser.extractCoin(text, '银币'),
        V2exAccountParser.extractCoin(text, '铜币')
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
        Number.parseFloat(`0.${withGold[3]}`)
      )
    }
    const withoutGold = text.match(/^(\d+)\s+0\.(\d+)$/)
    if (withoutGold && withoutGold[1] && withoutGold[2]) {
      return V2exAccountParser.createBalance(
        0,
        Number.parseInt(withoutGold[1]),
        Number.parseFloat(`0.${withoutGold[2]}`)
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
      parts.push(`${gold} 金币`)
    }
    if (silver > 0) {
      parts.push(`${silver} 银币`)
    }
    parts.push(`${bronze} 铜币`)
    return { gold, silver, bronze, summary: parts.join(' · ') }
  }

  private static compactText(html: string): string {
    return V2exAccountParser.decodeHtml(html.replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<[^>]+>/g, ' '))
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
