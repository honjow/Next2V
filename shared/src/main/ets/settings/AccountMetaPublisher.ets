import { common } from '@kit.AbilityKit'
import { V2exBalance, V2exDailyMission } from '../network/NetworkTypes'
import { AccountMetaSettings } from './AccountMetaSettings'
import { CookieJarSettings } from './CookieJarSettings'
import { connectAccountMeta } from '../state/AccountMetaState'
import { V2exAccountParser } from '../parser/V2exAccountParser'

/**
 * The SINGLE writer of `AccountMetaState`. Both the 我的 card (AccountPage) and the 账号 detail page
 * (AccountDetailPage) mirror that holder, so routing every balance/daily-mission update through this one
 * publisher is what keeps the two surfaces from diverging. Three entry points:
 *  - publishFetched: authoritative result of a /balance + /mission fetch (mutate holder AND persist cache)
 *  - publishCached:  hydrate the holder from the preferences cache (no re-save) so a peer surface mirrors
 *  - harvestFromHtml: real-time enrichment — pull the top-right balance widget out of ANY authenticated
 *    full-page HTML so a feed refresh / opening a topic keeps the balance fresh without a /balance fetch.
 */
export class AccountMetaPublisher {
  static publishFetched(
    context: common.UIAbilityContext,
    ownerKey: string,
    balance: V2exBalance | null,
    dailyMission: V2exDailyMission | null,
    source: string,
    cookie: string,
  ): void {
    if (!ownerKey || !balance) {
      return
    }
    const holder = connectAccountMeta()
    holder.ownerCookieHash = AccountMetaPublisher.cookieHash(cookie)
    AccountMetaPublisher.applyToHolder(ownerKey, balance, dailyMission)
    AccountMetaSettings.saveCache(context, ownerKey, balance, dailyMission, source).catch(
      (_e: Error) => {},
    )
  }

  // Hydrate the holder from the persisted cache, but NEVER downgrade a holder that already carries a live
  // value for this owner (a peer fetch or a browse-harvest may have set something fresher than the cache).
  static publishCached(
    ownerKey: string,
    balance: V2exBalance | null,
    dailyMission: V2exDailyMission | null,
  ): void {
    if (!ownerKey || !balance) {
      return
    }
    const holder = connectAccountMeta()
    if (holder.ownerKey === ownerKey && holder.balance) {
      return
    }
    AccountMetaPublisher.applyToHolder(ownerKey, balance, dailyMission)
  }

  // Guards: only the active account's cookie, only once an account context exists (holder.ownerKey set),
  // only when the strict nav widget is present. In-memory only (no context here) — the preferences cache
  // keeps the last authoritative value; this just keeps the live holder current between fetches.
  static harvestFromHtml(html: string, cookie: string): void {
    if (!html || !cookie || cookie !== CookieJarSettings.getCurrentCookie()) {
      return
    }
    const holder = connectAccountMeta()
    const ownerKey = holder.ownerKey
    // Only enrich when the holder's value already belongs to THIS cookie (set by an authoritative fetch).
    // Guards the account-switch window where the current cookie is B but the holder still describes A.
    if (!ownerKey || holder.ownerCookieHash !== AccountMetaPublisher.cookieHash(cookie)) {
      return
    }
    const balance = V2exAccountParser.extractNavBalance(html)
    if (!balance || AccountMetaPublisher.sameBalance(balance, holder.balance)) {
      return
    }
    AccountMetaPublisher.applyToHolder(ownerKey, balance, holder.dailyMission)
  }

  // After a confirmed daily check-in performed by the hidden ArkWeb runner (which redeems through a real Web
  // engine and so NEVER touches the HTTP-layer accountMeta), flip the live holder's dailyMission to the
  // claimed state so the 我的 card + 账号 detail page show 已签到 immediately — without a forced re-fetch or
  // an app restart. Only mutates the holder when it already describes the active account (ownerKey set +
  // cookie matches); otherwise the holder is empty/foreign and the next authoritative fetch loads the fresh
  // server state anyway. Balance is left as-is (the just-earned reward refreshes on the next harvest/fetch).
  static markDailyRedeemed(cookie: string): void {
    const clean = (cookie || '').trim()
    if (!clean) {
      return
    }
    const holder = connectAccountMeta()
    if (!holder.ownerKey || holder.ownerCookieHash !== AccountMetaPublisher.cookieHash(clean)) {
      return
    }
    const mission = holder.dailyMission
    if (mission && !mission.canRedeem && mission.message === 'already_checked_in_today') {
      return
    }
    const claimed: V2exDailyMission = {
      canRedeem: false,
      redeemPath: '',
      message: 'already_checked_in_today',
    }
    AccountMetaPublisher.applyToHolder(holder.ownerKey, holder.balance, claimed)
  }

  private static applyToHolder(
    ownerKey: string,
    balance: V2exBalance | null,
    dailyMission: V2exDailyMission | null,
  ): void {
    const holder = connectAccountMeta()
    holder.ownerKey = ownerKey
    if (balance) {
      holder.balance = balance
    }
    if (dailyMission) {
      holder.dailyMission = dailyMission
    }
    holder.updatedAt = Math.floor(Date.now() / 1000)
  }

  private static sameBalance(a: V2exBalance | null, b: V2exBalance | null): boolean {
    if (!a || !b) {
      return false
    }
    return a.gold === b.gold && a.silver === b.silver && a.bronze === b.bronze
  }

  // Cheap FNV-1a fingerprint of the cookie (length + hash). Identifies WHICH account the holder describes
  // without ever storing the raw cookie.
  private static cookieHash(cookie: string): string {
    const clean = (cookie || '').trim()
    if (!clean) {
      return ''
    }
    let hash = 2166136261
    for (let i = 0; i < clean.length; i += 1) {
      hash ^= clean.charCodeAt(i)
      hash = Math.imul(hash, 16777619) >>> 0
    }
    return `${clean.length}:${hash.toString(16)}`
  }
}
