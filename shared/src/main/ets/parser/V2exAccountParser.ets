import type { V2exBalance, V2exDailyMission } from '../network/NetworkTypes'

export class V2exAccountParser {
  static extractBalance(html: string): V2exBalance {
    const text = V2exAccountParser.compactText(html)
    const gold = V2exAccountParser.extractCoin(text, '金币')
    const silver = V2exAccountParser.extractCoin(text, '银币')
    const bronze = V2exAccountParser.extractCoin(text, '铜币')
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
