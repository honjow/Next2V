import { common } from '@kit.AbilityKit'
import { BackupChecksum } from './BackupChecksum'
import { BackupLocalDataAdapter } from './BackupLocalDataAdapter'
import { BackupPreferencesAdapter } from './BackupPreferencesAdapter'
import { BackupValidator } from './BackupValidator'
import type { BackupDataV1, BackupEnvelopeV1, BackupParseResult, BackupPreview, BackupRestoreResult, BackupSectionName } from './BackupTypes'
import { BACKUP_APP_ID, BACKUP_MAGIC, BACKUP_MIN_SUPPORTED_SCHEMA_VERSION, BACKUP_SCHEMA_VERSION } from './BackupTypes'

export interface BackupAppMetadata {
  versionName: string
  versionCode: number
}

interface BackupRollbackSnapshot {
  sections: BackupSectionName[]
  data: BackupDataV1
}

export class BackupService {
  static async createBackup(context: common.UIAbilityContext, metadata?: BackupAppMetadata): Promise<BackupEnvelopeV1> {
    const preferences = await BackupPreferencesAdapter.exportSection(context)
    const drafts = await BackupLocalDataAdapter.exportDrafts(context)
    const collections = await BackupLocalDataAdapter.exportCollections(context)
    const search = await BackupLocalDataAdapter.exportSearch(context)
    const notifications = await BackupLocalDataAdapter.exportNotifications(context)
    const sections: BackupSectionName[] = ['preferences', 'drafts', 'collections', 'search', 'notifications']
    const envelope: BackupEnvelopeV1 = {
      magic: BACKUP_MAGIC,
      appId: BACKUP_APP_ID,
      schemaVersion: BACKUP_SCHEMA_VERSION,
      minSupportedSchemaVersion: BACKUP_MIN_SUPPORTED_SCHEMA_VERSION,
      createdAt: new Date().toISOString(),
      appVersion: metadata?.versionName || '0.6.1',
      appVersionCode: metadata?.versionCode || 7,
      sections: sections,
      counts: {
        preferences: BackupPreferencesAdapter.count(preferences),
        drafts: { replyDrafts: drafts.replyDrafts.length, topicDraft: drafts.topicDraft ? 1 : 0 },
        collections: {
          savedTopics: collections.savedTopics.length,
          savedNodes: collections.savedNodes.length,
          viewedTopics: collections.viewedTopics.length,
          readPositions: collections.readPositions.length,
          readStates: collections.readStates.length
        },
        search: { history: search.history.length },
        notifications: { items: notifications.items.length }
      },
      data: { preferences: preferences, drafts: drafts, collections: collections, search: search, notifications: notifications }
    }
    return await BackupChecksum.signEnvelope(envelope)
  }

  static async serializeBackup(context: common.UIAbilityContext, metadata?: BackupAppMetadata): Promise<string> {
    const envelope = await BackupService.createBackup(context, metadata)
    return JSON.stringify(envelope, null, 2)
  }

  static async parseAndPreview(raw: string): Promise<BackupParseResult> {
    return await BackupValidator.parseEnvelope(raw)
  }

  static preview(envelope: BackupEnvelopeV1): BackupPreview {
    return BackupValidator.preview(envelope)
  }

  static async restoreBackup(context: common.UIAbilityContext, envelope: BackupEnvelopeV1): Promise<BackupRestoreResult> {
    const validation = await BackupValidator.validateEnvelope(envelope)
    if (!validation.ok) {
      return { ok: false, restoredSections: [], failedSections: envelope.sections || [], message: validation.message }
    }
    const rollbackSnapshot = await BackupService.createRollbackSnapshot(context)
    for (let i = 0; i < envelope.sections.length; i++) {
      const section = envelope.sections[i]
      try {
        await BackupService.restoreSection(context, section, envelope.data)
      } catch (error) {
        try {
          await BackupService.rollbackRestore(context, rollbackSnapshot)
        } catch (rollbackError) {
          const e = rollbackError as Error
          return { ok: false, restoredSections: [], failedSections: [section], message: `Backup import failed; rollback also failed: ${e.message || 'unknown error'}` }
        }
        return { ok: false, restoredSections: [], failedSections: [section], message: 'Backup import failed and local data was restored.' }
      }
    }
    return { ok: true, restoredSections: envelope.sections, failedSections: [], message: 'Backup import complete.' }
  }

  private static async createRollbackSnapshot(context: common.UIAbilityContext): Promise<BackupRollbackSnapshot> {
    return {
      sections: ['preferences', 'drafts', 'collections', 'search', 'notifications'],
      data: {
        preferences: await BackupPreferencesAdapter.exportSection(context),
        drafts: await BackupLocalDataAdapter.exportDrafts(context),
        collections: await BackupLocalDataAdapter.exportCollections(context),
        search: await BackupLocalDataAdapter.exportSearch(context),
        notifications: await BackupLocalDataAdapter.exportNotifications(context)
      }
    }
  }

  private static async rollbackRestore(context: common.UIAbilityContext, snapshot: BackupRollbackSnapshot): Promise<void> {
    for (let i = snapshot.sections.length - 1; i >= 0; i--) {
      await BackupService.restoreSection(context, snapshot.sections[i], snapshot.data)
    }
  }

  private static async restoreSection(context: common.UIAbilityContext, section: BackupSectionName, data: BackupDataV1): Promise<void> {
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
    } else {
      throw new Error(`Missing backup data for ${section}`)
    }
  }
}
