import { common } from '@kit.AbilityKit'
import { AccountStore, AccountRecord, AccountRecordInput } from './AccountStore'
import { AuthSessionSettings, AuthSessionSnapshot } from './AuthSessionSettings'
import { CookieJarSettings } from './CookieJarSettings'
import { HttpClient } from '../network/HttpClient'
import { AppStrings } from '../i18n/AppStrings'

/**
 * Central coordinator for multi-account session management.
 *
 * Operations:
 *   registerCurrentSession — call from login success paths after CookieJar/AuthSession save
 *   switchToAccount         — apply a stored account's cookie/session into runtime
 *   removeAccount           — per-account removal with active-fallback logic
 *   prepareAddAccount       — mark pending add-account entry without changing runtime identity
 *   restoreActiveAccount    — on restart, restore active account's cookie/session from AccountStore
 */
export class AccountSessionCoordinator {

  /**
   * After login success and CookieJarSettings/AuthSessionSettings save,
   * register/update the current session in AccountStore.
   * Returns the created or updated AccountRecord.
   */
  static async registerCurrentSession(
    context: common.UIAbilityContext,
    username: string,
    avatar: string,
    loginMode: 'cookie' | 'pat'
  ): Promise<AccountRecord> {
    const cookie = CookieJarSettings.getCurrentCookie()
    const baseUrl = HttpClient.getInstance().getBaseUrl()

    console.info('AccountSessionCoordinator: registerCurrentSession start username=' + username +
      ' loginMode=' + loginMode + ' hasSessionSnapshot=' + (cookie.length > 0))

    const now = Date.now()
    const input: AccountRecordInput = {
      username,
      avatar,
      loginMode,
      baseUrl,
      cookieSnapshot: cookie,
      tokenSnapshot: '',
      validatedAt: now
    }

    // Check if we already have a record for this username+loginMode on this baseUrl
    const existing = await AccountStore.getAll(context)
    const match = existing.find(r =>
      r.username === username &&
      r.loginMode === loginMode &&
      r.baseUrl === baseUrl
    )

    let record: AccountRecord
    if (match) {
      // Update existing record with fresh cookie/session
      match.cookieSnapshot = cookie
      match.avatar = avatar || match.avatar
      match.validatedAt = now
      record = await AccountStore.update(context, match)
      console.info('AccountSessionCoordinator: registerCurrentSession updated id=' + record.id)
    } else {
      record = await AccountStore.add(context, input)
      console.info('AccountSessionCoordinator: registerCurrentSession created id=' + record.id)
    }

    await AccountStore.setActiveId(context, record.id)
    return record
  }

  /**
   * Apply a stored account's cookie and session into runtime.
   * This loads the cookie into CookieJarSettings, session into AuthSessionSettings,
   * restores WebCookieManager, and sets the active account ID.
   */
  static async switchToAccount(context: common.UIAbilityContext, record: AccountRecord): Promise<void> {
    console.info('AccountSessionCoordinator: switchToAccount id=' + record.id +
      ' username=' + record.username + ' hasSessionSnapshot=' + (record.cookieSnapshot.length > 0))

    // 1. Apply cookie to CookieJarSettings
    if (record.cookieSnapshot) {
      await CookieJarSettings.saveForBaseUrl(context, record.baseUrl, record.cookieSnapshot)
    }

    // 2. Apply session to AuthSessionSettings
    const sessionSnapshot: AuthSessionSnapshot = {
      loginMode: record.loginMode,
      username: record.username,
      avatar: record.avatar,
      validatedAt: record.validatedAt
    }
    await AuthSessionSettings.save(context, sessionSnapshot)

    // 3. Restore WebCookieManager (already called by CookieJarSettings.saveForBaseUrl)
    //    but ensure it's done explicitly
    await CookieJarSettings.restoreCurrentToWebCookieManager()

    // 4. Set active account ID
    await AccountStore.setActiveId(context, record.id)

    console.info('AccountSessionCoordinator: switchToAccount complete id=' + record.id)
  }

  /**
   * Remove a single account. If the removed account was active:
   *   - If other accounts exist, switch to the first remaining account
   *   - If no accounts remain, clear current cookie/session (logged-out state)
   */
  static async removeAccount(context: common.UIAbilityContext, id: string): Promise<void> {
    console.info('AccountSessionCoordinator: removeAccount start id=' + id +
      ' wasActive=' + (AccountStore.getActiveId() === id))

    const wasActive = AccountStore.getActiveId() === id

    // Remove from store first
    await AccountStore.remove(context, id)

    // After remove(), if the removed account was active, AccountStore.remove()
    // already cleared activeAccountId and AppStorage. But we need to also clear
    // CookieJar/AuthSession runtime state.

    if (!wasActive) {
      console.info('AccountSessionCoordinator: removeAccount done, not active account')
      return
    }

    // Active account was removed — pick a fallback
    const remaining = await AccountStore.getAll(context)
    if (remaining.length > 0) {
      // Switch to first remaining account
      const fallback = remaining[0]
      console.info('AccountSessionCoordinator: removeAccount fallback to id=' + fallback.id +
        ' username=' + fallback.username)
      await AccountSessionCoordinator.switchToAccount(context, fallback)
    } else {
      // No accounts left — clear current runtime identity
      console.info('AccountSessionCoordinator: removeAccount no accounts remain, clearing session')
      await CookieJarSettings.clear(context)
      await AuthSessionSettings.clear(context)
    }
  }

  /**
   * Enter pending add-account mode without clearing the active runtime identity.
   * The current cookie/session remains valid until a login success saves a
   * validated new session and registerCurrentSession switches the active record.
   */
  static async prepareAddAccount(context: common.UIAbilityContext): Promise<void> {
    const accounts = await AccountStore.getAll(context).catch((_error: Error): AccountRecord[] => [])
    console.info('AccountSessionCoordinator: prepareAddAccount pending, preservedActiveId=' +
      AccountStore.getActiveId() + ' accountsCount=' + accounts.length)
  }

  /**
   * Restore the active account's cookie and session from AccountStore into
   * CookieJarSettings, AuthSessionSettings, and WebCookieManager.
   * Call this during SettingsBootstrap/startup before any HTTP requests.
   * Returns the restored AccountRecord, or null if no active account exists.
   */
  static async restoreActiveAccount(context: common.UIAbilityContext): Promise<AccountRecord | null> {
    // First restore active ID from persisted preferences
    const activeId = await AccountStore.restoreActiveId(context)
    if (!activeId) {
      console.info('AccountSessionCoordinator: restoreActiveAccount no active id')
      return null
    }

    const record = await AccountStore.getById(context, activeId)
    if (!record) {
      console.info('AccountSessionCoordinator: restoreActiveAccount record not found for id=' + activeId)
      await AccountStore.setActiveId(context, '')
      await CookieJarSettings.clear(context)
      await AuthSessionSettings.clear(context)
      return null
    }

    console.info('AccountSessionCoordinator: restoreActiveAccount restoring id=' + record.id +
      ' username=' + record.username + ' hasSessionSnapshot=' + (record.cookieSnapshot.length > 0))

    // Apply cookie — but DON'T double-restore if CookieJarSettings already loaded
    // We directly apply the snapshot from AccountStore into the runtime
    if (record.cookieSnapshot) {
      await CookieJarSettings.saveForBaseUrl(context, record.baseUrl, record.cookieSnapshot)
    }

    const sessionSnapshot: AuthSessionSnapshot = {
      loginMode: record.loginMode,
      username: record.username,
      avatar: record.avatar,
      validatedAt: record.validatedAt
    }
    await AuthSessionSettings.save(context, sessionSnapshot)

    await CookieJarSettings.restoreCurrentToWebCookieManager()

    return record
  }
}
