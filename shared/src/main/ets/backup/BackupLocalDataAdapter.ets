import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import type { BackupCollectionsSection, BackupDraftsSection, BackupNotificationsSection, BackupSearchSection } from './BackupTypes'
import { DraftSettings, type ReplyDraft, type TopicDraft } from '../settings/DraftSettings'
import { CollectionSettings, type SavedNode, type SavedTopic, type TopicReadPosition, type TopicReadState, type ViewedTopic } from '../settings/CollectionSettings'
import { SearchSettings } from '../settings/SearchSettings'
import { NotificationSettings, type NotificationCacheSnapshot } from '../settings/NotificationSettings'
import type { V2exNotification } from '../network/NetworkTypes'
import { LocalDataStore } from '../storage/LocalDataStore'

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
    const store = await LocalDataStore.open(context)
    await store.executeSql('DELETE FROM collection_saved_topics')
    await store.executeSql('DELETE FROM collection_saved_nodes')
    await store.executeSql('DELETE FROM collection_viewed_topics')
    await store.executeSql('DELETE FROM collection_topic_read_positions')
    await store.executeSql('DELETE FROM collection_topic_read_states')
    const topics = (section.savedTopics || []) as SavedTopic[]
    for (let i = 0; i < topics.length; i++) {
      const item = topics[i]
      const args: relationalStore.ValueType[] = [item.id, item.title, item.nodeName, item.nodeTitle, item.username, item.avatar || '', item.memberPro || 0, item.created, item.replies || 0, item.savedAt]
      await store.executeSql('INSERT OR REPLACE INTO collection_saved_topics (topic_id, title, node_name, node_title, username, avatar, member_pro, created, replies, saved_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', args)
    }
    const nodes = (section.savedNodes || []) as SavedNode[]
    for (let i = 0; i < nodes.length; i++) {
      const item = nodes[i]
      const args: relationalStore.ValueType[] = [item.name, item.title, item.topics || 0, item.avatarMini || '', item.avatarNormal || '', item.avatarLarge || '', item.savedAt || 0]
      await store.executeSql('INSERT OR REPLACE INTO collection_saved_nodes (node_name, title, topics, avatar_mini, avatar_normal, avatar_large, saved_at) VALUES (?, ?, ?, ?, ?, ?, ?)', args)
    }
    const viewed = (section.viewedTopics || []) as ViewedTopic[]
    for (let i = 0; i < viewed.length; i++) {
      const item = viewed[i]
      const args: relationalStore.ValueType[] = [item.id, item.title, item.nodeName, item.nodeTitle, item.username, item.avatar || '', item.memberPro || 0, item.replies || 0, item.viewedAt]
      await store.executeSql('INSERT OR REPLACE INTO collection_viewed_topics (topic_id, title, node_name, node_title, username, avatar, member_pro, replies, viewed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', args)
    }
    const positions = (section.readPositions || []) as TopicReadPosition[]
    for (let i = 0; i < positions.length; i++) {
      const item = positions[i]
      const args: relationalStore.ValueType[] = [item.id, item.floor, item.updatedAt]
      await store.executeSql('INSERT OR REPLACE INTO collection_topic_read_positions (topic_id, floor, updated_at) VALUES (?, ?, ?)', args)
    }
    const states = (section.readStates || []) as TopicReadState[]
    for (let i = 0; i < states.length; i++) {
      const item = states[i]
      const args: relationalStore.ValueType[] = [item.id, item.touchedAt, item.updatedAt]
      await store.executeSql('INSERT OR REPLACE INTO collection_topic_read_states (topic_id, touched_at, updated_at) VALUES (?, ?, ?)', args)
    }
    await CollectionSettings.loadLocalContentStats(context)
    await CollectionSettings.syncTopicReadStates(context)
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
