import { common } from '@kit.AbilityKit'
import type {
  BackupAccountRecord,
  BackupNetworkProxyProfile,
  BackupUserInfoSection,
} from './BackupTypes'
import { AccountStore, type AccountRecord } from '../settings/AccountStore'
import { AccountSessionCoordinator } from '../settings/AccountSessionCoordinator'
import { NetworkProxyProfileSettings, NetworkProxySettings } from '../settings/NetworkProxySettings'
import type {
  NetworkProxyProfile,
  NetworkProxySettingsSnapshot,
} from '../settings/NetworkProxySettings'

/**
 * Account/credentials adapter for the encrypted backup path ONLY.
 *
 * This is the single place in the backup layer that touches login credentials
 * (cookie/token snapshots) and AccountStore. It is reachable only after the encrypted
 * container has been opened with the user's password, so credentials never appear in a
 * plaintext envelope. The plaintext-eligible adapters (preferences/local data) stay
 * credential-free per the secret-exclusion contract.
 */
export class BackupAccountAdapter {
  static async exportSection(context: common.UIAbilityContext): Promise<BackupUserInfoSection> {
    const records = await AccountStore.getAll(context)
    const accounts: BackupAccountRecord[] = records.map(
      (record: AccountRecord): BackupAccountRecord => {
        return {
          id: record.id,
          username: record.username,
          avatar: record.avatar,
          loginMode: record.loginMode,
          baseUrl: record.baseUrl,
          cookieSnapshot: record.cookieSnapshot,
          tokenSnapshot: record.tokenSnapshot,
          validatedAt: record.validatedAt,
          addedAt: record.addedAt,
          updatedAt: record.updatedAt,
        }
      },
    )
    const proxyState = await NetworkProxyProfileSettings.load(context)
    const proxyProfiles: BackupNetworkProxyProfile[] = proxyState.profiles.map(
      (p: NetworkProxyProfile): BackupNetworkProxyProfile => {
        return {
          id: p.id,
          name: p.name,
          mode: p.snapshot.mode,
          proxyScheme: p.snapshot.proxyScheme || 'http',
          host: p.snapshot.host,
          port: p.snapshot.port,
          username: p.snapshot.username,
          password: p.snapshot.password,
          exclusionList: p.snapshot.exclusionList || [],
          updatedAt: p.updatedAt,
        }
      },
    )
    return {
      activeAccountId: AccountStore.getActiveId(),
      accounts: accounts,
      networkProxy: { activeProfileId: proxyState.activeProfileId, profiles: proxyProfiles },
    }
  }

  static count(section: BackupUserInfoSection): number {
    return section.accounts ? section.accounts.length : 0
  }

  /**
   * Replace the local account list with the backup's accounts and re-apply the active
   * account's cookie/session into the runtime. Existing local accounts are cleared first so
   * the restore is deterministic and matches the rest of the import (overwrite semantics).
   */
  static async restoreSection(
    context: common.UIAbilityContext,
    section: BackupUserInfoSection,
  ): Promise<void> {
    await BackupAccountAdapter.restoreNetworkProxy(context, section)
    const accounts = section.accounts || []
    await AccountStore.replaceAllFromBackup(context, BackupAccountAdapter.toRecords(accounts))

    const all = await AccountStore.getAll(context)
    const targetId = BackupAccountAdapter.pickActiveId(section.activeAccountId, all)
    if (!targetId) {
      return
    }
    const active = all.find((record: AccountRecord): boolean => record.id === targetId) ?? null
    if (active) {
      await AccountSessionCoordinator.switchToAccount(context, active)
    }
  }

  // Restore network-proxy profiles (incl. credentials) — independent of accounts, so it runs even
  // when the backup carries no accounts. Mirrors the proxy settings page's upsert + activate flow.
  private static async restoreNetworkProxy(
    context: common.UIAbilityContext,
    section: BackupUserInfoSection,
  ): Promise<void> {
    const proxy = section.networkProxy
    if (!proxy || !Array.isArray(proxy.profiles)) {
      return
    }
    for (const p of proxy.profiles) {
      const snapshot: NetworkProxySettingsSnapshot = {
        mode: NetworkProxySettings.normalizeMode(p.mode || 'off'),
        host: p.host || '',
        port: p.port || 0,
        proxyScheme: NetworkProxySettings.normalizeProxyScheme(p.proxyScheme || 'http'),
        username: p.username || '',
        password: p.password || '',
        exclusionList: Array.isArray(p.exclusionList) ? p.exclusionList : [],
      }
      const profile: NetworkProxyProfile = {
        id: p.id,
        name: p.name,
        snapshot: snapshot,
        updatedAt: p.updatedAt > 0 ? p.updatedAt : Date.now(),
      }
      await NetworkProxyProfileSettings.upsertProfile(context, profile)
    }
    if (proxy.activeProfileId) {
      try {
        await NetworkProxyProfileSettings.setActiveProfile(context, proxy.activeProfileId)
      } catch (_error) {
        // active profile id may not resolve; leave proxy inactive rather than failing the import
      }
    }
  }

  private static toRecords(accounts: BackupAccountRecord[]): AccountRecord[] {
    return accounts.map((account: BackupAccountRecord): AccountRecord => {
      const loginMode: 'cookie' | 'pat' = account.loginMode === 'pat' ? 'pat' : 'cookie'
      return {
        id: account.id,
        username: account.username || '',
        avatar: account.avatar || '',
        loginMode: loginMode,
        baseUrl: account.baseUrl || '',
        cookieSnapshot: account.cookieSnapshot || '',
        tokenSnapshot: account.tokenSnapshot || '',
        validatedAt: account.validatedAt > 0 ? account.validatedAt : 0,
        addedAt: account.addedAt > 0 ? account.addedAt : Date.now(),
        updatedAt: account.updatedAt > 0 ? account.updatedAt : Date.now(),
      }
    })
  }

  private static pickActiveId(preferredId: string, records: AccountRecord[]): string {
    if (records.length === 0) {
      return ''
    }
    const preferred = records.find((record: AccountRecord): boolean => record.id === preferredId)
    return preferred ? preferred.id : records[0].id
  }
}
