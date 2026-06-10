import { common } from '@kit.AbilityKit'
import { BackupAccountAdapter } from './BackupAccountAdapter'
import { BackupChecksum } from './BackupChecksum'
import { BackupCrypto } from './BackupCrypto'
import type { BackupSealResult } from './BackupCrypto'
import { BackupLocalDataAdapter } from './BackupLocalDataAdapter'
import { BackupPreferencesAdapter } from './BackupPreferencesAdapter'
import { BackupValidator } from './BackupValidator'
import type {
  BackupCipherMeta,
  BackupDataV1,
  BackupEncryptedEnvelope,
  BackupEnvelopeV1,
  BackupParseResult,
  BackupPreview,
  BackupRestoreResult,
  BackupSectionName,
} from './BackupTypes'
import {
  BACKUP_APP_ID,
  BACKUP_MAGIC,
  BACKUP_MIN_SUPPORTED_SCHEMA_VERSION,
  BACKUP_SCHEMA_VERSION,
} from './BackupTypes'

export interface BackupAppMetadata {
  versionName: string
  versionCode: number
}

export interface BackupExportOptions {
  // When true, the backup includes the user-info section (accounts + login credentials) and
  // MUST be encrypted with a password. The picker layer enforces that password is non-empty.
  includeUserInfo: boolean
  password: string
}

interface BackupRollbackSnapshot {
  sections: BackupSectionName[]
  data: BackupDataV1
}

export class BackupService {
  static async createBackup(
    context: common.UIAbilityContext,
    metadata?: BackupAppMetadata,
    options?: BackupExportOptions,
  ): Promise<BackupEnvelopeV1> {
    const includeUserInfo = options?.includeUserInfo === true
    const preferences = await BackupPreferencesAdapter.exportSection(context)
    const drafts = await BackupLocalDataAdapter.exportDrafts(context)
    const collections = await BackupLocalDataAdapter.exportCollections(context)
    const search = await BackupLocalDataAdapter.exportSearch(context)
    const notifications = await BackupLocalDataAdapter.exportNotifications(context)
    const sections: BackupSectionName[] = [
      'preferences',
      'drafts',
      'collections',
      'search',
      'notifications',
    ]
    const data: BackupDataV1 = {
      preferences: preferences,
      drafts: drafts,
      collections: collections,
      search: search,
      notifications: notifications,
    }
    const envelope: BackupEnvelopeV1 = {
      magic: BACKUP_MAGIC,
      appId: BACKUP_APP_ID,
      schemaVersion: BACKUP_SCHEMA_VERSION,
      minSupportedSchemaVersion: BACKUP_MIN_SUPPORTED_SCHEMA_VERSION,
      createdAt: new Date().toISOString(),
      appVersion: metadata?.versionName || '1.0.6',
      appVersionCode: metadata?.versionCode || 19,
      sections: sections,
      counts: {
        preferences: BackupPreferencesAdapter.count(preferences),
        drafts: { replyDrafts: drafts.replyDrafts.length, topicDraft: drafts.topicDraft ? 1 : 0 },
        collections: {
          savedTopics: collections.savedTopics.length,
          savedNodes: collections.savedNodes.length,
          viewedTopics: collections.viewedTopics.length,
          readPositions: collections.readPositions.length,
          readStates: collections.readStates.length,
        },
        search: { history: search.history.length },
        notifications: { items: notifications.items.length },
      },
      data: data,
    }
    if (includeUserInfo) {
      const userInfo = await BackupAccountAdapter.exportSection(context)
      data.userInfo = userInfo
      envelope.sections = [
        'preferences',
        'drafts',
        'collections',
        'search',
        'notifications',
        'userInfo',
      ]
      envelope.counts.userInfo = { accounts: BackupAccountAdapter.count(userInfo) }
    }
    return await BackupChecksum.signEnvelope(envelope)
  }

  /**
   * Produce the file body to write. Without user info → pretty plaintext JSON (unchanged).
   * With user info + password → a signed envelope sealed inside the encrypted container, so the
   * exported file never exposes accounts/credentials in cleartext.
   */
  static async serializeBackup(
    context: common.UIAbilityContext,
    metadata?: BackupAppMetadata,
    options?: BackupExportOptions,
  ): Promise<string> {
    const envelope = await BackupService.createBackup(context, metadata, options)
    if (options && options.includeUserInfo === true) {
      const sealed: BackupSealResult = BackupCrypto.seal(JSON.stringify(envelope), options.password)
      const container: BackupEncryptedEnvelope = {
        magic: BACKUP_MAGIC,
        appId: BACKUP_APP_ID,
        schemaVersion: envelope.schemaVersion,
        minSupportedSchemaVersion: envelope.minSupportedSchemaVersion,
        encrypted: true,
        createdAt: envelope.createdAt,
        appVersion: envelope.appVersion,
        appVersionCode: envelope.appVersionCode,
        cipherMeta: sealed.cipherMeta,
        ciphertext: sealed.ciphertext,
      }
      return JSON.stringify(container, null, 2)
    }
    return JSON.stringify(envelope, null, 2)
  }

  static async parseAndPreview(raw: string): Promise<BackupParseResult> {
    return await BackupValidator.parseEnvelope(raw)
  }

  /**
   * Decrypt a recognized encrypted backup with the user's password, then parse/validate the
   * inner envelope through the same path as a plaintext import. A wrong password fails GCM tag
   * verification and surfaces as a 'bad_password' parse result. The password is used here only
   * and is never retained.
   */
  static async decryptAndPreview(raw: string, password: string): Promise<BackupParseResult> {
    let container: BackupEncryptedEnvelope
    try {
      container = JSON.parse(raw) as BackupEncryptedEnvelope
    } catch (_error) {
      return { ok: false, code: 'not_json', message: 'This file is not valid JSON.' }
    }
    if (
      !container ||
      container.magic !== BACKUP_MAGIC ||
      container.appId !== BACKUP_APP_ID ||
      container.encrypted !== true
    ) {
      return { ok: false, code: 'foreign_backup', message: 'This file is not a V2Next backup.' }
    }
    const meta: BackupCipherMeta | undefined = container.cipherMeta
    if (!meta || !container.ciphertext) {
      return { ok: false, code: 'malformed_section', message: 'Backup sections are malformed.' }
    }
    let plaintext: string
    try {
      plaintext = BackupCrypto.open(container.ciphertext, password, meta)
    } catch (_error) {
      // Wrong password or tampered data both fail GCM authentication here.
      return {
        ok: false,
        code: 'bad_password',
        message: 'Incorrect password or the backup is damaged.',
      }
    }
    // fromEncrypted=true: the inner envelope may legitimately carry the userInfo section, which is
    // only valid because it arrived sealed inside the encrypted container we just opened.
    return await BackupValidator.parseEnvelope(plaintext, true)
  }

  static preview(envelope: BackupEnvelopeV1): BackupPreview {
    return BackupValidator.preview(envelope)
  }

  static async restoreBackup(
    context: common.UIAbilityContext,
    envelope: BackupEnvelopeV1,
  ): Promise<BackupRestoreResult> {
    // An envelope reaching restore with an encryption-only section (userInfo) can only have come
    // from a container this app already decrypted, so accept those sections during validation.
    const fromEncrypted = BackupValidator.hasEncryptedOnlySection(envelope)
    const validation = await BackupValidator.validateEnvelope(envelope, fromEncrypted)
    if (!validation.ok) {
      return {
        ok: false,
        restoredSections: [],
        failedSections: envelope.sections || [],
        message: validation.message,
      }
    }
    // Snapshot only the sections this import will touch, so a plaintext import never reads or
    // rewrites account data on rollback (and a userInfo import restores accounts on failure).
    const rollbackSnapshot = await BackupService.createRollbackSnapshot(context, envelope.sections)
    for (let i = 0; i < envelope.sections.length; i++) {
      const section = envelope.sections[i]
      try {
        await BackupService.restoreSection(context, section, envelope.data)
      } catch (error) {
        try {
          await BackupService.rollbackRestore(context, rollbackSnapshot)
        } catch (rollbackError) {
          const e = rollbackError as Error
          return {
            ok: false,
            restoredSections: [],
            failedSections: [section],
            message: `Backup import failed; rollback also failed: ${e.message || 'unknown error'}`,
          }
        }
        return {
          ok: false,
          restoredSections: [],
          failedSections: [section],
          message: 'Backup import failed and local data was restored.',
        }
      }
    }
    return {
      ok: true,
      restoredSections: envelope.sections,
      failedSections: [],
      message: 'Backup import complete.',
    }
  }

  private static async createRollbackSnapshot(
    context: common.UIAbilityContext,
    sections: BackupSectionName[],
  ): Promise<BackupRollbackSnapshot> {
    const data: BackupDataV1 = {
      preferences: await BackupPreferencesAdapter.exportSection(context),
      drafts: await BackupLocalDataAdapter.exportDrafts(context),
      collections: await BackupLocalDataAdapter.exportCollections(context),
      search: await BackupLocalDataAdapter.exportSearch(context),
      notifications: await BackupLocalDataAdapter.exportNotifications(context),
    }
    const snapshotSections: BackupSectionName[] = [
      'preferences',
      'drafts',
      'collections',
      'search',
      'notifications',
    ]
    // Only read account data when the import actually carries it; plaintext imports never touch it.
    if (sections.indexOf('userInfo') >= 0) {
      data.userInfo = await BackupAccountAdapter.exportSection(context)
      snapshotSections.push('userInfo')
    }
    return {
      sections: snapshotSections,
      data: data,
    }
  }

  private static async rollbackRestore(
    context: common.UIAbilityContext,
    snapshot: BackupRollbackSnapshot,
  ): Promise<void> {
    for (let i = snapshot.sections.length - 1; i >= 0; i--) {
      await BackupService.restoreSection(context, snapshot.sections[i], snapshot.data)
    }
  }

  private static async restoreSection(
    context: common.UIAbilityContext,
    section: BackupSectionName,
    data: BackupDataV1,
  ): Promise<void> {
    if (section === 'preferences' && data.preferences) {
      await BackupPreferencesAdapter.restoreSection(context, data.preferences)
    } else if (section === 'drafts' && data.drafts) {
      await BackupLocalDataAdapter.restoreDrafts(context, data.drafts)
    } else if (section === 'collections' && data.collections) {
      await BackupLocalDataAdapter.restoreCollections(context, data.collections)
    } else if (section === 'search' && data.search) {
      await BackupLocalDataAdapter.restoreSearch(context, data.search)
    } else if (section === 'notifications' && data.notifications) {
      await BackupLocalDataAdapter.restoreNotifications(context, data.notifications)
    } else if (section === 'userInfo' && data.userInfo) {
      await BackupAccountAdapter.restoreSection(context, data.userInfo)
    } else {
      throw new Error(`Missing backup data for ${section}`)
    }
  }
}
