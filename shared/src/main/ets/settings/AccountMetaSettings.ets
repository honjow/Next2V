import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { V2exBalance, V2exDailyMission } from '../network/NetworkTypes'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { STORE_NAME_ACCOUNT_META } from './SettingsStores'

const STORE_NAME: string = STORE_NAME_ACCOUNT_META
const KEY_ACCOUNT_META_CACHE: string = 'accountMetaCache'

export interface AccountMetaSnapshot {
  ownerKey: string
  source: string
  balance: V2exBalance | null
  dailyMission: V2exDailyMission | null
  updatedAt: number
}

export class AccountMetaSettings {
  static ownerKey(username: string, source: string): string {
    const cleanUsername = (username || '').trim()
    const cleanSource = (source || '').trim()
    if (!cleanUsername || !cleanSource) {
      return ''
    }
    return 'member:' + cleanUsername + ':source:' + cleanSource
  }

  static async loadCache(context: common.UIAbilityContext, ownerKey: string): Promise<AccountMetaSnapshot | null> {
    if (!ownerKey) {
      return null
    }
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_ACCOUNT_META_CACHE, '') as string
      const snapshot = AccountMetaSettings.parse(raw)
      if (!snapshot || snapshot.ownerKey !== ownerKey) {
        DiagnosticLogger.info('account', 'account_meta_store_load', { ownerHash: DiagnosticLogger.ownerHash(ownerKey), hit: false, updatedAt: 0 })
        return null
      }
      DiagnosticLogger.info('account', 'account_meta_store_load', { ownerHash: DiagnosticLogger.ownerHash(ownerKey), hit: true, updatedAt: snapshot.updatedAt })
      return snapshot
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取账号缓存失败')
    }
  }

  static async saveCache(
    context: common.UIAbilityContext,
    ownerKey: string,
    balance: V2exBalance | null,
    dailyMission: V2exDailyMission | null,
    source: string = 'cookie'
  ): Promise<AccountMetaSnapshot | null> {
    if (!ownerKey || !balance) {
      return null
    }
    try {
      const snapshot: AccountMetaSnapshot = {
        ownerKey: ownerKey,
        source: source || 'cookie',
        balance: AccountMetaSettings.normalizeBalance(balance),
        dailyMission: AccountMetaSettings.normalizeDailyMission(dailyMission),
        updatedAt: Math.floor(Date.now() / 1000)
      }
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_ACCOUNT_META_CACHE, JSON.stringify(snapshot))
      store.flushSync()
      DiagnosticLogger.info('account', 'account_meta_store_save', {
        ownerHash: DiagnosticLogger.ownerHash(ownerKey),
        source: source || 'cookie',
        hasBalance: !!balance,
        hasDailyMission: !!dailyMission
      })
      return snapshot
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存账号缓存失败')
    }
  }

  static async clearCache(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_ACCOUNT_META_CACHE)
      store.flushSync()
      DiagnosticLogger.info('account', 'account_meta_store_clear', {})
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '清理账号缓存失败')
    }
  }

  private static parse(raw: string): AccountMetaSnapshot | null {
    if (!raw) {
      return null
    }
    try {
      const parsed = JSON.parse(raw) as AccountMetaSnapshot
      if (!parsed || !parsed.ownerKey || !parsed.balance) {
        return null
      }
      return {
        ownerKey: parsed.ownerKey,
        source: parsed.source || 'cookie',
        balance: AccountMetaSettings.normalizeBalance(parsed.balance),
        dailyMission: AccountMetaSettings.normalizeDailyMission(parsed.dailyMission),
        updatedAt: parsed.updatedAt > 0 ? parsed.updatedAt : 0
      }
    } catch (_error) {
      return null
    }
  }

  private static normalizeBalance(balance: V2exBalance | null): V2exBalance | null {
    if (!balance) {
      return null
    }
    return {
      gold: Number(balance.gold || 0),
      silver: Number(balance.silver || 0),
      bronze: Number(balance.bronze || 0),
      summary: balance.summary || ''
    }
  }

  private static normalizeDailyMission(dailyMission: V2exDailyMission | null): V2exDailyMission | null {
    if (!dailyMission) {
      return null
    }
    return {
      canRedeem: dailyMission.canRedeem === true,
      redeemPath: dailyMission.redeemPath || '',
      message: dailyMission.message || ''
    }
  }
}
