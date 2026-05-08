import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { V2exTopic } from '../network/NetworkTypes'

const STORE_NAME: string = 'next2v_collections'
const KEY_SAVED_TOPICS: string = 'savedTopics'
const KEY_SAVED_NODES: string = 'savedNodes'
const KEY_VIEWED_TOPICS: string = 'viewedTopics'
const KEY_TOPIC_READ_POSITIONS: string = 'topicReadPositions'
const KEY_TOPIC_READ_STATES: string = 'topicReadStates'
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
  created: number
  savedAt: number
}

export interface SavedNode {
  name: string
  title: string
  topics: number
  savedAt: number
}

export interface ViewedTopic {
  id: number
  title: string
  nodeName: string
  nodeTitle: string
  username: string
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

export class CollectionSettings {
  static async loadSavedTopics(context: common.UIAbilityContext): Promise<SavedTopic[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_SAVED_TOPICS, '[]') as string
      return CollectionSettings.parseTopics(raw)
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
      created: topic.created,
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
      return CollectionSettings.parseNodes(raw)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取关注节点失败')
    }
  }

  static async saveNode(context: common.UIAbilityContext, node: SavedNode): Promise<SavedNode[]> {
    const nodes = await CollectionSettings.loadSavedNodes(context)
    const saved: SavedNode = {
      name: node.name,
      title: node.title,
      topics: node.topics,
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

  static async isNodeSaved(context: common.UIAbilityContext, nodeName: string): Promise<boolean> {
    const nodes = await CollectionSettings.loadSavedNodes(context)
    return nodes.some((item: SavedNode) => item.name === nodeName)
  }

  static async loadViewedTopics(context: common.UIAbilityContext): Promise<ViewedTopic[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_VIEWED_TOPICS, '[]') as string
      return CollectionSettings.parseViewedTopics(raw)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取最近浏览失败')
    }
  }

  static async recordViewedTopic(context: common.UIAbilityContext, topic: V2exTopic): Promise<ViewedTopic[]> {
    const topics = await CollectionSettings.loadViewedTopics(context)
    const viewed: ViewedTopic = {
      id: topic.id,
      title: topic.title,
      nodeName: topic.node.name,
      nodeTitle: topic.node.title,
      username: topic.member.username,
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
      AppStorage.setOrCreate<string>(StorageKeys.TOPIC_READ_STATES, JSON.stringify(states))
      return states
    } catch (error) {
      AppStorage.setOrCreate<string>(StorageKeys.TOPIC_READ_STATES, '[]')
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
    AppStorage.setOrCreate<string>(StorageKeys.TOPIC_READ_STATES, JSON.stringify(next))
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
      AppStorage.setOrCreate<string>(StorageKeys.TOPIC_READ_STATES, '[]')
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
    if (!AppStorage.set<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, updatedAt)) {
      AppStorage.setOrCreate<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, updatedAt)
    }
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
      return parsed.filter((item: SavedNode) => item.name.length > 0 && item.title.length > 0)
    } catch (error) {
      return []
    }
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
