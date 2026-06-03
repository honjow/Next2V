import { AppStorageV2 } from '@kit.ArkUI'
import { V2exBalance, V2exDailyMission } from '../network/NetworkTypes'

/**
 * The ONE reactive source of truth for the signed-in account's coin balance + daily-mission state.
 *
 * Before this holder, the 我的 card (AccountPage) and the 账号 detail page (AccountDetailPage) each kept
 * their own private `@Local accountBalance`, each fetched /balance independently at different times, and
 * only shared a non-reactive preferences cache (last-writer-wins). Two independent fetches seconds apart
 * (a daily reward / thank / transfer in between) legitimately return different totals, so the two
 * surfaces could show different numbers. Both now mirror THIS holder, so they can no longer diverge.
 *
 * Single-writer: only `AccountMetaPublisher` mutates these fields. `ownerKey` is the identity gate —
 * readers display `balance` only while `ownerKey` equals their expected key, so a stale account's value
 * never bleeds across an account switch. `updatedAt` (epoch seconds) is the subscription point readers
 * `@Monitor('accountMeta.updatedAt')`; it is bumped on every change.
 */
@ObservedV2
export class AccountMetaState {
  @Trace ownerKey: string = ''
  // Fingerprint of the cookie whose authoritative fetch last set `balance`. The page-browse harvest only
  // enriches when this matches the CURRENT cookie, so during an account switch (current cookie already B,
  // holder still A) a feed harvest can't write B's balance under A's ownerKey. Never the raw cookie.
  @Trace ownerCookieHash: string = ''
  @Trace balance: V2exBalance | null = null
  @Trace dailyMission: V2exDailyMission | null = null
  @Trace updatedAt: number = 0
}

const ACCOUNT_META_V2_KEY: string = 'v2:accountMeta'

/** Returns the app-wide AccountMetaState singleton from AppStorageV2. */
export function connectAccountMeta(): AccountMetaState {
  return AppStorageV2.connect(AccountMetaState, ACCOUNT_META_V2_KEY, () => new AccountMetaState())!
}
