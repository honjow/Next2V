import { common } from '@kit.AbilityKit'
import type { BackupAccountRecord, BackupUserInfoSection } from './BackupTypes'
import { AccountStore, type AccountRecord } from '../settings/AccountStore'
import { AccountSessionCoordinator } from '../settings/AccountSessionCoordinator'

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
    return { activeAccountId: AccountStore.getActiveId(), accounts: accounts }
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
