import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import type { BackupCollectionsSection } from '../backup/BackupTypes'
import { V2exTopic } from '../network/NetworkTypes'
import { LocalDataStore } from '../storage/LocalDataStore'
import {
  MAX_READ_POSITIONS,
  MAX_READ_STATES,
  MAX_SAVED_NODES,
  MAX_SAVED_TOPICS,
  MAX_VIEWED_TOPICS,
} from './CollectionLimits'
import { cleanNodeTitle } from './CollectionParsers'
import type {
  LocalContentStats,
  SavedNode,
  SavedTopic,
  TopicReadPosition,
  TopicReadState,
  ViewedTopic,
} from './CollectionTypes'
import { LocalDataPublisher } from './LocalDataPublisher'
import { deleteKeysAndFlush, withPreferencesStore } from './SettingsStorage'
import { STORE_NAME_COLLECTIONS } from './SettingsStores'
import { AppStrings } from '../i18n/AppStrings'

export type {
  LocalContentStats,
  SavedNode,
  SavedTopic,
  TopicReadPosition,
  TopicReadState,
  ViewedTopic,
} from './CollectionTypes'

const STORE_NAME: string = STORE_NAME_COLLECTIONS
const KEY_SAVED_TOPICS: string = 'savedTopics'
const KEY_SAVED_NODES: string = 'savedNodes'
const KEY_VIEWED_TOPICS: string = 'viewedTopics'
const KEY_TOPIC_READ_POSITIONS: string = 'topicReadPositions'
// Legacy/compatibility Preferences key that mirrors StorageKeys.TOPIC_READ_STATES.
const KEY_TOPIC_READ_STATES: string = 'topicReadStates'

const SQL_SELECT_SAVED_TOPICS: string = 'SELECT topic_id, title, node_name, node_title, username, avatar, member_pro, created, replies, saved_at FROM collection_saved_topics ORDER BY saved_at DESC, topic_id DESC LIMIT 100'
const SQL_UPSERT_SAVED_TOPIC: string = 'INSERT OR REPLACE INTO collection_saved_topics (topic_id, title, node_name, node_title, username, avatar, member_pro, created, replies, saved_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
const SQL_DELETE_SAVED_TOPIC: string = 'DELETE FROM collection_saved_topics WHERE topic_id = ?'
const SQL_PRUNE_SAVED_TOPICS: string = 'DELETE FROM collection_saved_topics WHERE topic_id NOT IN (SELECT topic_id FROM collection_saved_topics ORDER BY saved_at DESC, topic_id DESC LIMIT 100)'
const SQL_COUNT_SAVED_TOPICS: string = 'SELECT COUNT(*) AS count_value FROM collection_saved_topics'

const SQL_SELECT_SAVED_NODES: string = 'SELECT node_name, title, topics, avatar_mini, avatar_normal, avatar_large, saved_at FROM collection_saved_nodes ORDER BY saved_at DESC, node_name ASC LIMIT 80'
const SQL_UPSERT_SAVED_NODE: string = 'INSERT OR REPLACE INTO collection_saved_nodes (node_name, title, topics, avatar_mini, avatar_normal, avatar_large, saved_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
const SQL_DELETE_SAVED_NODE: string = 'DELETE FROM collection_saved_nodes WHERE node_name = ?'
const SQL_PRUNE_SAVED_NODES: string = 'DELETE FROM collection_saved_nodes WHERE node_name NOT IN (SELECT node_name FROM collection_saved_nodes ORDER BY saved_at DESC, node_name ASC LIMIT 80)'
const SQL_COUNT_SAVED_NODES: string = 'SELECT COUNT(*) AS count_value FROM collection_saved_nodes'

const SQL_SELECT_VIEWED_TOPICS: string = 'SELECT topic_id, title, node_name, node_title, username, avatar, member_pro, replies, viewed_at FROM collection_viewed_topics ORDER BY viewed_at DESC, topic_id DESC LIMIT 100'
const SQL_UPSERT_VIEWED_TOPIC: string = 'INSERT OR REPLACE INTO collection_viewed_topics (topic_id, title, node_name, node_title, username, avatar, member_pro, replies, viewed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
const SQL_PRUNE_VIEWED_TOPICS: string = 'DELETE FROM collection_viewed_topics WHERE topic_id NOT IN (SELECT topic_id FROM collection_viewed_topics ORDER BY viewed_at DESC, topic_id DESC LIMIT 100)'
const SQL_COUNT_VIEWED_TOPICS: string = 'SELECT COUNT(*) AS count_value FROM collection_viewed_topics'

const SQL_SELECT_TOPIC_READ_POSITIONS: string = 'SELECT topic_id, floor, updated_at FROM collection_topic_read_positions ORDER BY updated_at DESC, topic_id DESC LIMIT 200'
const SQL_SELECT_TOPIC_READ_FLOOR: string = 'SELECT floor FROM collection_topic_read_positions WHERE topic_id = ? LIMIT 1'
const SQL_UPSERT_TOPIC_READ_POSITION: string = 'INSERT OR REPLACE INTO collection_topic_read_positions (topic_id, floor, updated_at) VALUES (?, ?, ?)'
const SQL_DELETE_TOPIC_READ_POSITION: string = 'DELETE FROM collection_topic_read_positions WHERE topic_id = ?'
const SQL_PRUNE_TOPIC_READ_POSITIONS: string = 'DELETE FROM collection_topic_read_positions WHERE topic_id NOT IN (SELECT topic_id FROM collection_topic_read_positions ORDER BY updated_at DESC, topic_id DESC LIMIT 200)'

const SQL_SELECT_TOPIC_READ_STATES: string = 'SELECT topic_id, touched_at, updated_at FROM collection_topic_read_states ORDER BY updated_at DESC, topic_id DESC LIMIT 500'
const SQL_UPSERT_TOPIC_READ_STATE: string = 'INSERT OR REPLACE INTO collection_topic_read_states (topic_id, touched_at, updated_at) VALUES (?, ?, ?)'
const SQL_PRUNE_TOPIC_READ_STATES: string = 'DELETE FROM collection_topic_read_states WHERE topic_id NOT IN (SELECT topic_id FROM collection_topic_read_states ORDER BY updated_at DESC, topic_id DESC LIMIT 500)'

const SQL_CLEAR_SAVED_TOPICS: string = 'DELETE FROM collection_saved_topics'
const SQL_CLEAR_SAVED_NODES: string = 'DELETE FROM collection_saved_nodes'
const SQL_CLEAR_VIEWED_TOPICS: string = 'DELETE FROM collection_viewed_topics'
const SQL_CLEAR_TOPIC_READ_POSITIONS: string = 'DELETE FROM collection_topic_read_positions'
const SQL_CLEAR_TOPIC_READ_STATES: string = 'DELETE FROM collection_topic_read_states'

export class CollectionSettings {
  static async loadSavedTopics(context: common.UIAbilityContext): Promise<SavedTopic[]> {
    try {
      const store = await LocalDataStore.open(context)
      const resultSet = await store.querySql(SQL_SELECT_SAVED_TOPICS)
      const topics = CollectionSettings.readSavedTopicsResult(resultSet)
      LocalDataPublisher.publishSavedTopicCount(topics.length)
      return topics
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read read-later items')
    }
  }

  static async saveTopic(context: common.UIAbilityContext, topic: V2exTopic): Promise<SavedTopic[]> {
    const saved: SavedTopic = {
      id: topic.id,
      title: topic.title,
      nodeName: topic.node.name,
      nodeTitle: topic.node.title,
      username: topic.member.username,
      avatar: topic.member.avatar_normal || topic.member.avatar_large || topic.member.avatar_mini,
      memberPro: topic.member.pro,
      created: topic.created,
      replies: topic.replies,
      savedAt: Math.floor(Date.now() / 1000)
    }
    try {
      const store = await LocalDataStore.open(context)
      await CollectionSettings.upsertSavedTopic(store, saved)
      await store.executeSql(SQL_PRUNE_SAVED_TOPICS)
      await CollectionSettings.publishSavedTopicCount(store)
      LocalDataPublisher.touchLocalData()
      CollectionSettings.deleteLegacyCollectionKeysBestEffort(context, [KEY_SAVED_TOPICS])
      return await CollectionSettings.loadSavedTopics(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save read-later items')
    }
  }

  static async removeTopic(context: common.UIAbilityContext, topicId: number): Promise<SavedTopic[]> {
    try {
      const store = await LocalDataStore.open(context)
      const args: relationalStore.ValueType[] = [topicId]
      await store.executeSql(SQL_DELETE_SAVED_TOPIC, args)
      await CollectionSettings.publishSavedTopicCount(store)
      LocalDataPublisher.touchLocalData()
      CollectionSettings.deleteLegacyCollectionKeysBestEffort(context, [KEY_SAVED_TOPICS])
      return await CollectionSettings.loadSavedTopics(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save read-later items')
    }
  }

  static async isTopicSaved(context: common.UIAbilityContext, topicId: number): Promise<boolean> {
    const topics = await CollectionSettings.loadSavedTopics(context)
    return topics.some((item: SavedTopic) => item.id === topicId)
  }

  static async loadSavedNodes(context: common.UIAbilityContext): Promise<SavedNode[]> {
    try {
      const store = await LocalDataStore.open(context)
      const resultSet = await store.querySql(SQL_SELECT_SAVED_NODES)
      const nodes = CollectionSettings.readSavedNodesResult(resultSet)
      LocalDataPublisher.publishSavedNodeCount(nodes.length)
      return nodes
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read followed nodes')
    }
  }

  static async saveNode(context: common.UIAbilityContext, node: SavedNode): Promise<SavedNode[]> {
    const name = (node.name || '').trim()
    if (!name) {
      return await CollectionSettings.loadSavedNodes(context)
    }
    const saved: SavedNode = {
      name: name,
      title: cleanNodeTitle(node.title, node.topics),
      topics: node.topics,
      avatarMini: node.avatarMini,
      avatarNormal: node.avatarNormal,
      avatarLarge: node.avatarLarge,
      savedAt: Math.floor(Date.now() / 1000)
    }
    if (!saved.title) {
      return await CollectionSettings.loadSavedNodes(context)
    }
    try {
      const store = await LocalDataStore.open(context)
      await CollectionSettings.upsertSavedNode(store, saved)
      await store.executeSql(SQL_PRUNE_SAVED_NODES)
      await CollectionSettings.publishSavedNodeCount(store)
      LocalDataPublisher.touchLocalData()
      CollectionSettings.deleteLegacyCollectionKeysBestEffort(context, [KEY_SAVED_NODES])
      return await CollectionSettings.loadSavedNodes(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save followed nodes')
    }
  }

  static async removeNode(context: common.UIAbilityContext, nodeName: string): Promise<SavedNode[]> {
    try {
      const store = await LocalDataStore.open(context)
      const args: relationalStore.ValueType[] = [(nodeName || '').trim()]
      await store.executeSql(SQL_DELETE_SAVED_NODE, args)
      await CollectionSettings.publishSavedNodeCount(store)
      LocalDataPublisher.touchLocalData()
      CollectionSettings.deleteLegacyCollectionKeysBestEffort(context, [KEY_SAVED_NODES])
      return await CollectionSettings.loadSavedNodes(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save followed nodes')
    }
  }

  static async updateSavedNodeMetadata(context: common.UIAbilityContext, node: SavedNode): Promise<SavedNode[]> {
    const nodes = await CollectionSettings.loadSavedNodes(context)
    let changed = false
    const next = nodes.map((item: SavedNode) => {
      if (item.name !== node.name) {
        return item
      }
      changed = true
      return {
        name: item.name,
        title: cleanNodeTitle(node.title || item.title, node.topics || item.topics),
        topics: node.topics > 0 ? node.topics : item.topics,
        avatarMini: node.avatarMini || item.avatarMini,
        avatarNormal: node.avatarNormal || item.avatarNormal,
        avatarLarge: node.avatarLarge || item.avatarLarge,
        savedAt: item.savedAt
      }
    })
    if (changed) {
      await CollectionSettings.writeSavedNodes(context, next)
    }
    return next
  }

  static async updateSavedNodesMetadata(context: common.UIAbilityContext, updates: SavedNode[]): Promise<SavedNode[]> {
    const nodes = await CollectionSettings.loadSavedNodes(context)
    const updateByName: Record<string, SavedNode> = {}
    updates.forEach((node: SavedNode) => {
      updateByName[node.name] = node
    })
    let changed = false
    const next = nodes.map((item: SavedNode) => {
      const update = updateByName[item.name]
      if (!update) {
        return item
      }
      const nextNode: SavedNode = {
        name: item.name,
        title: cleanNodeTitle(update.title || item.title, update.topics || item.topics),
        topics: update.topics > 0 ? update.topics : item.topics,
        avatarMini: update.avatarMini || item.avatarMini,
        avatarNormal: update.avatarNormal || item.avatarNormal,
        avatarLarge: update.avatarLarge || item.avatarLarge,
        savedAt: item.savedAt
      }
      changed = changed ||
        nextNode.title !== item.title ||
        nextNode.topics !== item.topics ||
        nextNode.avatarMini !== item.avatarMini ||
        nextNode.avatarNormal !== item.avatarNormal ||
        nextNode.avatarLarge !== item.avatarLarge
      return nextNode
    })
    if (changed) {
      await CollectionSettings.writeSavedNodes(context, next)
    }
    return next
  }

  static async isNodeSaved(context: common.UIAbilityContext, nodeName: string): Promise<boolean> {
    const nodes = await CollectionSettings.loadSavedNodes(context)
    return nodes.some((item: SavedNode) => item.name === nodeName)
  }

  static async loadViewedTopics(context: common.UIAbilityContext): Promise<ViewedTopic[]> {
    try {
      const store = await LocalDataStore.open(context)
      const resultSet = await store.querySql(SQL_SELECT_VIEWED_TOPICS)
      const topics = CollectionSettings.readViewedTopicsResult(resultSet)
      LocalDataPublisher.publishViewedTopicCount(topics.length)
      return topics
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read recently viewed items')
    }
  }

  static async loadLocalContentStats(context: common.UIAbilityContext): Promise<LocalContentStats> {
    try {
      const store = await LocalDataStore.open(context)
      const stats: LocalContentStats = {
        savedTopicCount: await CollectionSettings.countRows(store, SQL_COUNT_SAVED_TOPICS),
        savedNodeCount: await CollectionSettings.countRows(store, SQL_COUNT_SAVED_NODES),
        viewedTopicCount: await CollectionSettings.countRows(store, SQL_COUNT_VIEWED_TOPICS)
      }
      LocalDataPublisher.publishLocalContentStats(stats)
      return stats
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read local content statistics')
    }
  }

  static async recordViewedTopic(context: common.UIAbilityContext, topic: V2exTopic): Promise<ViewedTopic[]> {
    const viewed: ViewedTopic = {
      id: topic.id,
      title: topic.title,
      nodeName: topic.node.name,
      nodeTitle: topic.node.title,
      username: topic.member.username,
      avatar: topic.member.avatar_normal || topic.member.avatar_large || topic.member.avatar_mini,
      memberPro: topic.member.pro,
      replies: topic.replies,
      viewedAt: Math.floor(Date.now() / 1000)
    }
    try {
      const store = await LocalDataStore.open(context)
      const args: relationalStore.ValueType[] = [
        viewed.id,
        viewed.title,
        viewed.nodeName,
        viewed.nodeTitle,
        viewed.username,
        viewed.avatar || '',
        viewed.memberPro || 0,
        viewed.replies || 0,
        viewed.viewedAt
      ]
      await store.executeSql(SQL_UPSERT_VIEWED_TOPIC, args)
      await store.executeSql(SQL_PRUNE_VIEWED_TOPICS)
      await CollectionSettings.publishViewedTopicCount(store)
      LocalDataPublisher.touchLocalData()
      CollectionSettings.deleteLegacyCollectionKeysBestEffort(context, [KEY_VIEWED_TOPICS])
      return await CollectionSettings.loadViewedTopics(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save recently viewed items')
    }
  }

  static async getTopicReadFloor(context: common.UIAbilityContext, topicId: number): Promise<number> {
    if (topicId <= 0) {
      return 0
    }
    try {
      const store = await LocalDataStore.open(context)
      const args: relationalStore.ValueType[] = [topicId]
      const resultSet = await store.querySql(SQL_SELECT_TOPIC_READ_FLOOR, args)
      try {
        if (!resultSet.goToNextRow()) {
          return 0
        }
        return Math.max(0, resultSet.getLong(resultSet.getColumnIndex('floor')))
      } finally {
        resultSet.close()
      }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read reading position')
    }
  }

  static async saveTopicReadFloor(context: common.UIAbilityContext, topicId: number, floor: number): Promise<TopicReadPosition[]> {
    if (topicId <= 0) {
      return []
    }
    try {
      const store = await LocalDataStore.open(context)
      const now = Math.floor(Date.now() / 1000)
      if (floor > 0) {
        const args: relationalStore.ValueType[] = [topicId, floor, now]
        await store.executeSql(SQL_UPSERT_TOPIC_READ_POSITION, args)
        await store.executeSql(SQL_PRUNE_TOPIC_READ_POSITIONS)
      } else {
        const args: relationalStore.ValueType[] = [topicId]
        await store.executeSql(SQL_DELETE_TOPIC_READ_POSITION, args)
      }
      CollectionSettings.deleteLegacyCollectionKeysBestEffort(context, [KEY_TOPIC_READ_POSITIONS])
      return await CollectionSettings.loadTopicReadPositions(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save reading position')
    }
  }

  static async loadTopicReadPositions(context: common.UIAbilityContext): Promise<TopicReadPosition[]> {
    try {
      const store = await LocalDataStore.open(context)
      const resultSet = await store.querySql(SQL_SELECT_TOPIC_READ_POSITIONS)
      return CollectionSettings.readTopicReadPositionsResult(resultSet)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read reading position')
    }
  }

  static async syncTopicReadStates(context: common.UIAbilityContext): Promise<TopicReadState[]> {
    try {
      const states = await CollectionSettings.loadTopicReadStates(context)
      LocalDataPublisher.publishTopicReadStates(states)
      return states
    } catch (error) {
      LocalDataPublisher.clearTopicReadStates()
      return []
    }
  }

  static async markTopicRead(context: common.UIAbilityContext, topicId: number, touchedAt: number): Promise<TopicReadState[]> {
    if (topicId <= 0) {
      return []
    }
    const normalizedTouchedAt = touchedAt > 0 ? touchedAt : Math.floor(Date.now() / 1000)
    try {
      const store = await LocalDataStore.open(context)
      const state: TopicReadState = {
        id: topicId,
        touchedAt: normalizedTouchedAt,
        updatedAt: Math.floor(Date.now() / 1000)
      }
      const args: relationalStore.ValueType[] = [state.id, state.touchedAt, state.updatedAt]
      await store.executeSql(SQL_UPSERT_TOPIC_READ_STATE, args)
      await store.executeSql(SQL_PRUNE_TOPIC_READ_STATES)
      CollectionSettings.deleteLegacyCollectionKeysBestEffort(context, [KEY_TOPIC_READ_STATES])
      const next = await CollectionSettings.loadTopicReadStates(context)
      LocalDataPublisher.publishTopicReadStates(next)
      return next
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save read state')
    }
  }

  static async loadTopicReadStates(context: common.UIAbilityContext): Promise<TopicReadState[]> {
    try {
      const store = await LocalDataStore.open(context)
      const resultSet = await store.querySql(SQL_SELECT_TOPIC_READ_STATES)
      return CollectionSettings.readTopicReadStatesResult(resultSet)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read read state')
    }
  }

  static async clearAll(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await LocalDataStore.open(context)
      await store.executeSql(SQL_CLEAR_SAVED_TOPICS)
      await store.executeSql(SQL_CLEAR_SAVED_NODES)
      await store.executeSql(SQL_CLEAR_VIEWED_TOPICS)
      await store.executeSql(SQL_CLEAR_TOPIC_READ_POSITIONS)
      await store.executeSql(SQL_CLEAR_TOPIC_READ_STATES)
      LocalDataPublisher.clearTopicReadStates()
      LocalDataPublisher.publishLocalContentStats({ savedTopicCount: 0, savedNodeCount: 0, viewedTopicCount: 0 })
      LocalDataPublisher.touchLocalData()
      CollectionSettings.deleteLegacyCollectionKeysBestEffort(context, [
        KEY_SAVED_TOPICS,
        KEY_SAVED_NODES,
        KEY_VIEWED_TOPICS,
        KEY_TOPIC_READ_POSITIONS,
        KEY_TOPIC_READ_STATES
      ])
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text(AppStrings.R_COLLECTION_CLEAR_ALL_FAILED, 'Failed to clear local collection and reading records'))
    }
  }

  static async restoreBackup(context: common.UIAbilityContext, section: BackupCollectionsSection): Promise<void> {
    try {
      const store = await LocalDataStore.open(context)
      await store.executeSql(SQL_CLEAR_SAVED_TOPICS)
      await store.executeSql(SQL_CLEAR_SAVED_NODES)
      await store.executeSql(SQL_CLEAR_VIEWED_TOPICS)
      await store.executeSql(SQL_CLEAR_TOPIC_READ_POSITIONS)
      await store.executeSql(SQL_CLEAR_TOPIC_READ_STATES)
      const topics = (section.savedTopics || []) as SavedTopic[]
      for (let i = 0; i < topics.length; i++) {
        await CollectionSettings.upsertSavedTopic(store, topics[i])
      }
      const nodes = (section.savedNodes || []) as SavedNode[]
      for (let i = 0; i < nodes.length; i++) {
        await CollectionSettings.upsertSavedNode(store, nodes[i])
      }
      const viewed = (section.viewedTopics || []) as ViewedTopic[]
      for (let i = 0; i < viewed.length; i++) {
        await CollectionSettings.upsertViewedTopic(store, viewed[i])
      }
      const positions = (section.readPositions || []) as TopicReadPosition[]
      for (let i = 0; i < positions.length; i++) {
        await CollectionSettings.upsertTopicReadPosition(store, positions[i])
      }
      const states = (section.readStates || []) as TopicReadState[]
      for (let i = 0; i < states.length; i++) {
        await CollectionSettings.upsertTopicReadState(store, states[i])
      }
      await CollectionSettings.publishSavedTopicCount(store)
      await CollectionSettings.publishSavedNodeCount(store)
      await CollectionSettings.publishViewedTopicCount(store)
      await CollectionSettings.syncTopicReadStates(context)
      await CollectionSettings.loadLocalContentStats(context)
      LocalDataPublisher.touchLocalData()
      CollectionSettings.deleteLegacyCollectionKeysBestEffort(context, [
        KEY_SAVED_TOPICS,
        KEY_SAVED_NODES,
        KEY_VIEWED_TOPICS,
        KEY_TOPIC_READ_POSITIONS,
        KEY_TOPIC_READ_STATES
      ])
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to restore local collection and reading records')
    }
  }

  private static async writeSavedNodes(context: common.UIAbilityContext, nodes: SavedNode[]): Promise<void> {
    try {
      const store = await LocalDataStore.open(context)
      await store.executeSql(SQL_CLEAR_SAVED_NODES)
      const next = nodes.slice(0, MAX_SAVED_NODES)
      for (let i = 0; i < next.length; i++) {
        const node = next[i]
        await CollectionSettings.upsertSavedNode(store, node)
      }
      await CollectionSettings.publishSavedNodeCount(store)
      LocalDataPublisher.touchLocalData()
      CollectionSettings.deleteLegacyCollectionKeysBestEffort(context, [KEY_SAVED_NODES])
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save followed nodes')
    }
  }

  private static async upsertSavedTopic(store: relationalStore.RdbStore, topic: SavedTopic): Promise<void> {
    const args: relationalStore.ValueType[] = [
      topic.id,
      topic.title,
      topic.nodeName,
      topic.nodeTitle,
      topic.username,
      topic.avatar || '',
      topic.memberPro || 0,
      topic.created,
      topic.replies || 0,
      topic.savedAt
    ]
    await store.executeSql(SQL_UPSERT_SAVED_TOPIC, args)
  }

  private static async upsertSavedNode(store: relationalStore.RdbStore, node: SavedNode): Promise<void> {
    const name = (node.name || '').trim()
    const title = cleanNodeTitle(node.title || name, node.topics)
    if (!name || !title) {
      return
    }
    const args: relationalStore.ValueType[] = [
      name,
      title,
      Math.max(0, node.topics || 0),
      node.avatarMini || '',
      node.avatarNormal || '',
      node.avatarLarge || '',
      node.savedAt || Math.floor(Date.now() / 1000)
    ]
    await store.executeSql(SQL_UPSERT_SAVED_NODE, args)
  }

  private static async upsertViewedTopic(store: relationalStore.RdbStore, topic: ViewedTopic): Promise<void> {
    const args: relationalStore.ValueType[] = [
      topic.id,
      topic.title,
      topic.nodeName,
      topic.nodeTitle,
      topic.username,
      topic.avatar || '',
      topic.memberPro || 0,
      topic.replies || 0,
      topic.viewedAt
    ]
    await store.executeSql(SQL_UPSERT_VIEWED_TOPIC, args)
  }

  private static async upsertTopicReadPosition(store: relationalStore.RdbStore, position: TopicReadPosition): Promise<void> {
    if (position.id <= 0 || position.floor <= 0) {
      return
    }
    const args: relationalStore.ValueType[] = [position.id, position.floor, position.updatedAt]
    await store.executeSql(SQL_UPSERT_TOPIC_READ_POSITION, args)
  }

  private static async upsertTopicReadState(store: relationalStore.RdbStore, state: TopicReadState): Promise<void> {
    if (state.id <= 0 || state.touchedAt <= 0) {
      return
    }
    const args: relationalStore.ValueType[] = [state.id, state.touchedAt, state.updatedAt]
    await store.executeSql(SQL_UPSERT_TOPIC_READ_STATE, args)
  }

  private static readSavedTopicsResult(resultSet: relationalStore.ResultSet): SavedTopic[] {
    const topics: SavedTopic[] = []
    try {
      const idIndex = resultSet.getColumnIndex('topic_id')
      const titleIndex = resultSet.getColumnIndex('title')
      const nodeNameIndex = resultSet.getColumnIndex('node_name')
      const nodeTitleIndex = resultSet.getColumnIndex('node_title')
      const usernameIndex = resultSet.getColumnIndex('username')
      const avatarIndex = resultSet.getColumnIndex('avatar')
      const memberProIndex = resultSet.getColumnIndex('member_pro')
      const createdIndex = resultSet.getColumnIndex('created')
      const repliesIndex = resultSet.getColumnIndex('replies')
      const savedAtIndex = resultSet.getColumnIndex('saved_at')
      while (resultSet.goToNextRow()) {
        const topic: SavedTopic = {
          id: resultSet.getLong(idIndex),
          title: resultSet.getString(titleIndex),
          nodeName: resultSet.getString(nodeNameIndex),
          nodeTitle: resultSet.getString(nodeTitleIndex),
          username: resultSet.getString(usernameIndex),
          avatar: CollectionSettings.readOptionalString(resultSet, avatarIndex),
          memberPro: resultSet.getLong(memberProIndex),
          created: resultSet.getLong(createdIndex),
          replies: resultSet.getLong(repliesIndex),
          savedAt: resultSet.getLong(savedAtIndex)
        }
        if (topic.id > 0 && topic.title.length > 0) {
          topics.push(topic)
        }
      }
    } finally {
      resultSet.close()
    }
    return topics
  }

  private static readSavedNodesResult(resultSet: relationalStore.ResultSet): SavedNode[] {
    const nodes: SavedNode[] = []
    try {
      const nameIndex = resultSet.getColumnIndex('node_name')
      const titleIndex = resultSet.getColumnIndex('title')
      const topicsIndex = resultSet.getColumnIndex('topics')
      const avatarMiniIndex = resultSet.getColumnIndex('avatar_mini')
      const avatarNormalIndex = resultSet.getColumnIndex('avatar_normal')
      const avatarLargeIndex = resultSet.getColumnIndex('avatar_large')
      const savedAtIndex = resultSet.getColumnIndex('saved_at')
      while (resultSet.goToNextRow()) {
        const name = resultSet.getString(nameIndex).trim()
        const topics = Math.max(0, resultSet.getLong(topicsIndex))
        const title = cleanNodeTitle(resultSet.getString(titleIndex).trim() || name, topics)
        if (!name || !title) {
          continue
        }
        nodes.push({
          name: name,
          title: title,
          topics: topics,
          avatarMini: CollectionSettings.readOptionalString(resultSet, avatarMiniIndex),
          avatarNormal: CollectionSettings.readOptionalString(resultSet, avatarNormalIndex),
          avatarLarge: CollectionSettings.readOptionalString(resultSet, avatarLargeIndex),
          savedAt: resultSet.getLong(savedAtIndex)
        })
      }
    } finally {
      resultSet.close()
    }
    return nodes
  }

  private static readViewedTopicsResult(resultSet: relationalStore.ResultSet): ViewedTopic[] {
    const topics: ViewedTopic[] = []
    try {
      const idIndex = resultSet.getColumnIndex('topic_id')
      const titleIndex = resultSet.getColumnIndex('title')
      const nodeNameIndex = resultSet.getColumnIndex('node_name')
      const nodeTitleIndex = resultSet.getColumnIndex('node_title')
      const usernameIndex = resultSet.getColumnIndex('username')
      const avatarIndex = resultSet.getColumnIndex('avatar')
      const memberProIndex = resultSet.getColumnIndex('member_pro')
      const repliesIndex = resultSet.getColumnIndex('replies')
      const viewedAtIndex = resultSet.getColumnIndex('viewed_at')
      while (resultSet.goToNextRow()) {
        const topic: ViewedTopic = {
          id: resultSet.getLong(idIndex),
          title: resultSet.getString(titleIndex),
          nodeName: resultSet.getString(nodeNameIndex),
          nodeTitle: resultSet.getString(nodeTitleIndex),
          username: resultSet.getString(usernameIndex),
          avatar: CollectionSettings.readOptionalString(resultSet, avatarIndex),
          memberPro: resultSet.getLong(memberProIndex),
          replies: resultSet.getLong(repliesIndex),
          viewedAt: resultSet.getLong(viewedAtIndex)
        }
        if (topic.id > 0 && topic.title.length > 0) {
          topics.push(topic)
        }
      }
    } finally {
      resultSet.close()
    }
    return topics
  }

  private static readTopicReadPositionsResult(resultSet: relationalStore.ResultSet): TopicReadPosition[] {
    const positions: TopicReadPosition[] = []
    try {
      const idIndex = resultSet.getColumnIndex('topic_id')
      const floorIndex = resultSet.getColumnIndex('floor')
      const updatedAtIndex = resultSet.getColumnIndex('updated_at')
      while (resultSet.goToNextRow()) {
        const position: TopicReadPosition = {
          id: resultSet.getLong(idIndex),
          floor: resultSet.getLong(floorIndex),
          updatedAt: resultSet.getLong(updatedAtIndex)
        }
        if (position.id > 0 && position.floor > 0) {
          positions.push(position)
        }
      }
    } finally {
      resultSet.close()
    }
    return positions
  }

  private static readTopicReadStatesResult(resultSet: relationalStore.ResultSet): TopicReadState[] {
    const states: TopicReadState[] = []
    try {
      const idIndex = resultSet.getColumnIndex('topic_id')
      const touchedAtIndex = resultSet.getColumnIndex('touched_at')
      const updatedAtIndex = resultSet.getColumnIndex('updated_at')
      while (resultSet.goToNextRow()) {
        const state: TopicReadState = {
          id: resultSet.getLong(idIndex),
          touchedAt: resultSet.getLong(touchedAtIndex),
          updatedAt: resultSet.getLong(updatedAtIndex)
        }
        if (state.id > 0 && state.touchedAt > 0) {
          states.push(state)
        }
      }
    } finally {
      resultSet.close()
    }
    return states
  }

  private static async publishSavedTopicCount(store: relationalStore.RdbStore): Promise<void> {
    LocalDataPublisher.publishSavedTopicCount(await CollectionSettings.countRows(store, SQL_COUNT_SAVED_TOPICS))
  }

  private static async publishSavedNodeCount(store: relationalStore.RdbStore): Promise<void> {
    LocalDataPublisher.publishSavedNodeCount(await CollectionSettings.countRows(store, SQL_COUNT_SAVED_NODES))
  }

  private static async publishViewedTopicCount(store: relationalStore.RdbStore): Promise<void> {
    LocalDataPublisher.publishViewedTopicCount(await CollectionSettings.countRows(store, SQL_COUNT_VIEWED_TOPICS))
  }

  private static async countRows(store: relationalStore.RdbStore, sql: string): Promise<number> {
    const resultSet = await store.querySql(sql)
    try {
      if (!resultSet.goToNextRow()) {
        return 0
      }
      return Math.max(0, resultSet.getLong(resultSet.getColumnIndex('count_value')))
    } finally {
      resultSet.close()
    }
  }

  private static readOptionalString(resultSet: relationalStore.ResultSet, columnIndex: number): string | undefined {
    try {
      const value = resultSet.getString(columnIndex)
      return value && value.length > 0 ? value : undefined
    } catch (_error) {
      return undefined
    }
  }

  private static deleteLegacyCollectionKeysBestEffort(context: common.UIAbilityContext, keys: string[]): void {
    withPreferencesStore<void>(context, STORE_NAME, (store) => {
      deleteKeysAndFlush(store, keys)
    }).catch(() => {})
  }

  static cleanNodeTitle(title: string, topics: number = 0): string {
    return cleanNodeTitle(title, topics)
  }
}
