import { common } from '@kit.AbilityKit'
import type { BackupCollectionsSection, BackupDraftsSection, BackupNotificationsSection, BackupSearchSection } from './BackupTypes'
import { DraftSettings, type ReplyDraft, type TopicDraft } from '../settings/DraftSettings'
import { CollectionSettings } from '../settings/CollectionSettings'
import { SearchSettings } from '../settings/SearchSettings'
import { NotificationSettings, type NotificationCacheSnapshot } from '../settings/NotificationSettings'
import type { V2exNotification } from '../network/NetworkTypes'

export class BackupLocalDataAdapter {
  static async exportDrafts(context: common.UIAbilityContext): Promise<BackupDraftsSection> {
    const replyDrafts = await DraftSettings.exportReplyDraftsForBackup(context)
    const topicDraft = await DraftSettings.loadTopicDraft(context)
    return { replyDrafts: replyDrafts, topicDraft: topicDraft }
  }

  static async restoreDrafts(context: common.UIAbilityContext, section: BackupDraftsSection): Promise<void> {
    await DraftSettings.restoreBackup(context, section.replyDrafts as ReplyDraft[], section.topicDraft as TopicDraft | null)
  }

  static async exportCollections(context: common.UIAbilityContext): Promise<BackupCollectionsSection> {
    return {
      savedTopics: await CollectionSettings.loadSavedTopics(context),
      savedNodes: await CollectionSettings.loadSavedNodes(context),
      viewedTopics: await CollectionSettings.loadViewedTopics(context),
      readPositions: await CollectionSettings.loadTopicReadPositions(context),
      readStates: await CollectionSettings.loadTopicReadStates(context)
    }
  }

  static async restoreCollections(context: common.UIAbilityContext, section: BackupCollectionsSection): Promise<void> {
    await CollectionSettings.restoreBackup(context, section)
  }

  static async exportSearch(context: common.UIAbilityContext): Promise<BackupSearchSection> {
    return { history: await SearchSettings.loadHistory(context), sourceMode: await SearchSettings.loadSourceMode(context) }
  }

  static async restoreSearch(context: common.UIAbilityContext, section: BackupSearchSection): Promise<void> {
    await SearchSettings.clearHistory(context)
    const history = section.history || []
    for (let i = history.length - 1; i >= 0; i--) {
      await SearchSettings.recordQuery(context, history[i])
    }
    await SearchSettings.saveSourceMode(context, section.sourceMode as 'local' | 'localWithNodes' | 'remote' | 'externalWeb')
  }

  static async exportNotifications(context: common.UIAbilityContext): Promise<BackupNotificationsSection> {
    const snapshot = await NotificationSettings.exportCacheForBackup(context)
    return {
      ownerKey: snapshot.ownerKey,
      items: snapshot.items,
      page: snapshot.page,
      hasMore: snapshot.hasMore,
      updatedAt: snapshot.updatedAt
    }
  }

  static async restoreNotifications(context: common.UIAbilityContext, section: BackupNotificationsSection): Promise<void> {
    const snapshot: NotificationCacheSnapshot = {
      ownerKey: section.ownerKey || '',
      items: section.items as V2exNotification[],
      page: section.page > 0 ? section.page : 1,
      hasMore: section.hasMore === true,
      updatedAt: section.updatedAt > 0 ? section.updatedAt : 0
    }
    await NotificationSettings.restoreCacheFromBackup(context, snapshot)
  }
}
