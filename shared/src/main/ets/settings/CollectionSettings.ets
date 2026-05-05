import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { V2exTopic } from '../network/NetworkTypes'

const STORE_NAME: string = 'next2v_collections'
const KEY_SAVED_TOPICS: string = 'savedTopics'
const MAX_SAVED_TOPICS: number = 100

export interface SavedTopic {
  id: number
  title: string
  nodeName: string
  nodeTitle: string
  username: string
  created: number
  savedAt: number
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

  private static async writeSavedTopics(context: common.UIAbilityContext, topics: SavedTopic[]): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_SAVED_TOPICS, JSON.stringify(topics))
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存稍后读失败')
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
}
