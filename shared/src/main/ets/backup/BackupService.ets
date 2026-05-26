import { common } from '@kit.AbilityKit'
import { BackupChecksum } from './BackupChecksum'
import { BackupLocalDataAdapter } from './BackupLocalDataAdapter'
import { BackupPreferencesAdapter } from './BackupPreferencesAdapter'
import { BackupValidator } from './BackupValidator'
import type { BackupEnvelopeV1, BackupParseResult, BackupPreview, BackupRestoreResult, BackupSectionName } from './BackupTypes'
import { BACKUP_APP_ID, BACKUP_MAGIC, BACKUP_MIN_SUPPORTED_SCHEMA_VERSION, BACKUP_SCHEMA_VERSION } from './BackupTypes'

export interface BackupAppMetadata {
  versionName: string
  versionCode: number
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
    const restored: BackupSectionName[] = []
    const failed: BackupSectionName[] = []
    for (let i = 0; i < envelope.sections.length; i++) {
      const section = envelope.sections[i]
      try {
        if (section === 'preferences' && envelope.data.preferences) {
          await BackupPreferencesAdapter.restoreSection(context, envelope.data.preferences)
        } else if (section === 'drafts' && envelope.data.drafts) {
          await BackupLocalDataAdapter.restoreDrafts(context, envelope.data.drafts)
        } else if (section === 'collections' && envelope.data.collections) {
          await BackupLocalDataAdapter.restoreCollections(context, envelope.data.collections)
        } else if (section === 'search' && envelope.data.search) {
          await BackupLocalDataAdapter.restoreSearch(context, envelope.data.search)
        } else if (section === 'notifications' && envelope.data.notifications) {
          await BackupLocalDataAdapter.restoreNotifications(context, envelope.data.notifications)
        }
        restored.push(section)
      } catch (_error) {
        failed.push(section)
      }
    }
    return { ok: failed.length === 0, restoredSections: restored, failedSections: failed, message: failed.length === 0 ? 'Backup import complete.' : 'Some backup sections could not be restored.' }
  }
}
