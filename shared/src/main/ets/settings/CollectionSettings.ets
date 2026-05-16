import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { V2exTopic } from '../network/NetworkTypes'
import { setAppStorageValue } from './SettingsStorage'

const STORE_NAME: string = 'next2v_collections'
const KEY_SAVED_TOPICS: string = 'savedTopics'
const KEY_SAVED_NODES: string = 'savedNodes'
const KEY_VIEWED_TOPICS: string = 'viewedTopics'
const KEY_TOPIC_READ_POSITIONS: string = 'topicReadPositions'
const KEY_TOPIC_READ_STATES: string = StorageKeys.TOPIC_READ_STATES
const MAX_SAVED_TOPICS: number = 100
const MAX_SAVED_NODES: number = 80
const MAX_VIEWED_TOPICS: number = 100
const MAX_READ_POSITIONS: number = 200
const MAX_READ_STATES: number = 500

export interface SavedTopic {
  id: number
  title: string
  nodeName: string
  nodeTitle: string
  username: string
  avatar?: string
  memberPro?: number
  created: number
  replies?: number
  savedAt: number
}

export interface SavedNode {
  name: string
  title: string
  topics: number
  avatarMini?: string
  avatarNormal?: string
  avatarLarge?: string
  savedAt: number
}

export interface ViewedTopic {
  id: number
  title: string
  nodeName: string
  nodeTitle: string
  username: string
  avatar?: string
  memberPro?: number
  replies?: number
  viewedAt: number
}

export interface TopicReadPosition {
  id: number
  floor: number
  updatedAt: number
}

export interface TopicReadState {
  id: number
  touchedAt: number
  updatedAt: number
}

export interface LocalContentStats {
  savedTopicCount: number
  savedNodeCount: number
  viewedTopicCount: number
}

export class CollectionSettings {
  static async loadSavedTopics(context: common.UIAbilityContext): Promise<SavedTopic[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_SAVED_TOPICS, '[]') as string
      const topics = CollectionSettings.parseTopics(raw)
      CollectionSettings.publishLocalContentCount(StorageKeys.LOCAL_SAVED_TOPIC_COUNT, topics.length)
      return topics
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取稍后读失败')
    }
  }

  static async saveTopic(context: common.UIAbilityContext, topic: V2exTopic): Promise<SavedTopic[]> {
    const topics = await CollectionSettings.loadSavedTopics(context)
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
    const next = [saved].concat(topics.filter((item: SavedTopic) => item.id !== topic.id)).slice(0, MAX_SAVED_TOPICS)
    await CollectionSettings.writeSavedTopics(context, next)
    return next
  }

  static async removeTopic(context: common.UIAbilityContext, topicId: number): Promise<SavedTopic[]> {
    const topics = await CollectionSettings.loadSavedTopics(context)
    const next = topics.filter((item: SavedTopic) => item.id !== topicId)
    await CollectionSettings.writeSavedTopics(context, next)
    return next
  }

  static async isTopicSaved(context: common.UIAbilityContext, topicId: number): Promise<boolean> {
    const topics = await CollectionSettings.loadSavedTopics(context)
    return topics.some((item: SavedTopic) => item.id === topicId)
  }

  static async loadSavedNodes(context: common.UIAbilityContext): Promise<SavedNode[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_SAVED_NODES, '[]') as string
      const nodes = CollectionSettings.parseNodes(raw)
      CollectionSettings.publishLocalContentCount(StorageKeys.LOCAL_SAVED_NODE_COUNT, nodes.length)
      return nodes
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取关注节点失败')
    }
  }

  static async saveNode(context: common.UIAbilityContext, node: SavedNode): Promise<SavedNode[]> {
    const nodes = await CollectionSettings.loadSavedNodes(context)
    const saved: SavedNode = {
      name: node.name,
      title: CollectionSettings.cleanNodeTitle(node.title, node.topics),
      topics: node.topics,
      avatarMini: node.avatarMini,
      avatarNormal: node.avatarNormal,
      avatarLarge: node.avatarLarge,
      savedAt: Math.floor(Date.now() / 1000)
    }
    const next = [saved].concat(nodes.filter((item: SavedNode) => item.name !== node.name)).slice(0, MAX_SAVED_NODES)
    await CollectionSettings.writeSavedNodes(context, next)
    return next
  }

  static async removeNode(context: common.UIAbilityContext, nodeName: string): Promise<SavedNode[]> {
    const nodes = await CollectionSettings.loadSavedNodes(context)
    const next = nodes.filter((item: SavedNode) => item.name !== nodeName)
    await CollectionSettings.writeSavedNodes(context, next)
    return next
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
        title: CollectionSettings.cleanNodeTitle(node.title || item.title, node.topics || item.topics),
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
        title: CollectionSettings.cleanNodeTitle(update.title || item.title, update.topics || item.topics),
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
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_VIEWED_TOPICS, '[]') as string
      const topics = CollectionSettings.parseViewedTopics(raw)
      CollectionSettings.publishLocalContentCount(StorageKeys.LOCAL_VIEWED_TOPIC_COUNT, topics.length)
      return topics
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取最近浏览失败')
    }
  }

  static async loadLocalContentStats(context: common.UIAbilityContext): Promise<LocalContentStats> {
    const savedTopics = await CollectionSettings.loadSavedTopics(context)
    const savedNodes = await CollectionSettings.loadSavedNodes(context)
    const viewedTopics = await CollectionSettings.loadViewedTopics(context)
    const stats: LocalContentStats = {
      savedTopicCount: savedTopics.length,
      savedNodeCount: savedNodes.length,
      viewedTopicCount: viewedTopics.length
    }
    CollectionSettings.publishLocalContentStats(stats)
    return stats
  }

  static async recordViewedTopic(context: common.UIAbilityContext, topic: V2exTopic): Promise<ViewedTopic[]> {
    const topics = await CollectionSettings.loadViewedTopics(context)
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
    const next = [viewed].concat(topics.filter((item: ViewedTopic) => item.id !== topic.id)).slice(0, MAX_VIEWED_TOPICS)
    await CollectionSettings.writeViewedTopics(context, next)
    return next
  }

  static async getTopicReadFloor(context: common.UIAbilityContext, topicId: number): Promise<number> {
    if (topicId <= 0) {
      return 0
    }
    const positions = await CollectionSettings.loadTopicReadPositions(context)
    const match = positions.find((item: TopicReadPosition) => item.id === topicId)
    return match ? match.floor : 0
  }

  static async saveTopicReadFloor(context: common.UIAbilityContext, topicId: number, floor: number): Promise<TopicReadPosition[]> {
    if (topicId <= 0) {
      return []
    }
    const positions = await CollectionSettings.loadTopicReadPositions(context)
    let next: TopicReadPosition[]
    if (floor > 0) {
      const pos: TopicReadPosition = { id: topicId, floor: floor, updatedAt: Math.floor(Date.now() / 1000) }
      next = [pos].concat(positions.filter((item: TopicReadPosition) => item.id !== topicId)).slice(0, MAX_READ_POSITIONS)
    } else {
      next = positions.filter((item: TopicReadPosition) => item.id !== topicId)
    }
    await CollectionSettings.writeTopicReadPositions(context, next)
    return next
  }

  static async loadTopicReadPositions(context: common.UIAbilityContext): Promise<TopicReadPosition[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_TOPIC_READ_POSITIONS, '[]') as string
      return CollectionSettings.parseTopicReadPositions(raw)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取阅读位置失败')
    }
  }

  static async syncTopicReadStates(context: common.UIAbilityContext): Promise<TopicReadState[]> {
    try {
      const states = await CollectionSettings.loadTopicReadStates(context)
      setAppStorageValue<string>(StorageKeys.TOPIC_READ_STATES, JSON.stringify(states))
      return states
    } catch (error) {
      setAppStorageValue<string>(StorageKeys.TOPIC_READ_STATES, '[]')
      return []
    }
  }

  static async markTopicRead(context: common.UIAbilityContext, topicId: number, touchedAt: number): Promise<TopicReadState[]> {
    if (topicId <= 0) {
      return []
    }
    const normalizedTouchedAt = touchedAt > 0 ? touchedAt : Math.floor(Date.now() / 1000)
    const states = await CollectionSettings.loadTopicReadStates(context)
    const state: TopicReadState = { id: topicId, touchedAt: normalizedTouchedAt, updatedAt: Math.floor(Date.now() / 1000) }
    const next = [state].concat(states.filter((item: TopicReadState) => item.id !== topicId)).slice(0, MAX_READ_STATES)
    await CollectionSettings.writeTopicReadStates(context, next)
    setAppStorageValue<string>(StorageKeys.TOPIC_READ_STATES, JSON.stringify(next))
    return next
  }

  static async loadTopicReadStates(context: common.UIAbilityContext): Promise<TopicReadState[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_TOPIC_READ_STATES, '[]') as string
      return CollectionSettings.parseTopicReadStates(raw)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取已读状态失败')
    }
  }

  static async clearAll(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_SAVED_TOPICS)
      store.deleteSync(KEY_SAVED_NODES)
      store.deleteSync(KEY_VIEWED_TOPICS)
      store.deleteSync(KEY_TOPIC_READ_POSITIONS)
      store.deleteSync(KEY_TOPIC_READ_STATES)
      store.flushSync()
      setAppStorageValue<string>(StorageKeys.TOPIC_READ_STATES, '[]')
      CollectionSettings.publishLocalContentStats({ savedTopicCount: 0, savedNodeCount: 0, viewedTopicCount: 0 })
      CollectionSettings.touchLocalData()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '清理本地收藏与阅读记录失败')
    }
  }

  private static async writeSavedTopics(context: common.UIAbilityContext, topics: SavedTopic[]): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_SAVED_TOPICS, JSON.stringify(topics))
      store.flushSync()
      CollectionSettings.publishLocalContentCount(StorageKeys.LOCAL_SAVED_TOPIC_COUNT, topics.length)
      CollectionSettings.touchLocalData()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存稍后读失败')
    }
  }

  private static async writeSavedNodes(context: common.UIAbilityContext, nodes: SavedNode[]): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_SAVED_NODES, JSON.stringify(nodes))
      store.flushSync()
      CollectionSettings.publishLocalContentCount(StorageKeys.LOCAL_SAVED_NODE_COUNT, nodes.length)
      CollectionSettings.touchLocalData()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存关注节点失败')
    }
  }

  private static async writeViewedTopics(context: common.UIAbilityContext, topics: ViewedTopic[]): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_VIEWED_TOPICS, JSON.stringify(topics))
      store.flushSync()
      CollectionSettings.publishLocalContentCount(StorageKeys.LOCAL_VIEWED_TOPIC_COUNT, topics.length)
      CollectionSettings.touchLocalData()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存最近浏览失败')
    }
  }

  private static async writeTopicReadPositions(context: common.UIAbilityContext, positions: TopicReadPosition[]): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_TOPIC_READ_POSITIONS, JSON.stringify(positions))
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存阅读位置失败')
    }
  }

  private static async writeTopicReadStates(context: common.UIAbilityContext, states: TopicReadState[]): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_TOPIC_READ_STATES, JSON.stringify(states))
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存已读状态失败')
    }
  }

  private static touchLocalData(): void {
    const updatedAt = Date.now()
    setAppStorageValue<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, updatedAt)
  }

  private static publishLocalContentStats(stats: LocalContentStats): void {
    CollectionSettings.publishLocalContentCount(StorageKeys.LOCAL_SAVED_TOPIC_COUNT, stats.savedTopicCount)
    CollectionSettings.publishLocalContentCount(StorageKeys.LOCAL_SAVED_NODE_COUNT, stats.savedNodeCount)
    CollectionSettings.publishLocalContentCount(StorageKeys.LOCAL_VIEWED_TOPIC_COUNT, stats.viewedTopicCount)
  }

  private static publishLocalContentCount(key: string, count: number): void {
    setAppStorageValue<number>(key, count)
  }

  private static parseTopics(raw: string): SavedTopic[] {
    try {
      const parsed = JSON.parse(raw) as SavedTopic[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return parsed.filter((item: SavedTopic) => item.id > 0 && item.title.length > 0)
    } catch (error) {
      return []
    }
  }

  private static parseNodes(raw: string): SavedNode[] {
    try {
      const parsed = JSON.parse(raw) as SavedNode[]
      if (!Array.isArray(parsed)) {
        return []
      }
      const nodes: SavedNode[] = []
      parsed.forEach((item: SavedNode) => {
        const node = CollectionSettings.normalizeSavedNode(item)
        if (node) {
          nodes.push(node)
        }
      })
      return nodes
    } catch (error) {
      return []
    }
  }

  private static normalizeSavedNode(item: SavedNode): SavedNode | null {
    const name = ((item?.name || '') as string).trim()
    const topics = Math.max(0, item?.topics || 0)
    const title = CollectionSettings.cleanNodeTitle(((item?.title || name) as string).trim(), topics)
    if (!name || !title) {
      return null
    }
    return {
      name: name,
      title: title,
      topics: topics,
      avatarMini: ((item?.avatarMini || '') as string).trim() || undefined,
      avatarNormal: ((item?.avatarNormal || '') as string).trim() || undefined,
      avatarLarge: ((item?.avatarLarge || '') as string).trim() || undefined,
      savedAt: item?.savedAt || 0
    }
  }

  static cleanNodeTitle(title: string, topics: number = 0): string {
    let clean = (title || '')
      .replace(/\s*[·｜|]\s*\d+\s*个主题\s*$/g, '')
      .replace(/\s+\d+\s*个主题\s*$/g, '')
      .trim()
    if (topics > 0) {
      const topicSuffix = `${topics}`
      if (clean.endsWith(` ${topicSuffix}`)) {
        clean = clean.substring(0, clean.length - topicSuffix.length).trim()
      }
    }
    return clean.replace(/\s+\d{2,}\s*$/g, '').trim()
  }

  private static parseViewedTopics(raw: string): ViewedTopic[] {
    try {
      const parsed = JSON.parse(raw) as ViewedTopic[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return parsed.filter((item: ViewedTopic) => item.id > 0 && item.title.length > 0)
    } catch (error) {
      return []
    }
  }

  private static parseTopicReadPositions(raw: string): TopicReadPosition[] {
    try {
      const parsed = JSON.parse(raw) as TopicReadPosition[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return parsed.filter((item: TopicReadPosition) => item.id > 0 && item.floor > 0)
    } catch (error) {
      return []
    }
  }

  private static parseTopicReadStates(raw: string): TopicReadState[] {
    try {
      const parsed = JSON.parse(raw) as TopicReadState[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return parsed.filter((item: TopicReadState) => item.id > 0 && item.touchedAt > 0)
    } catch (error) {
      return []
    }
  }
}
