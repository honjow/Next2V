import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { V2exReply, V2exTopic } from '../network/NetworkTypes'

const STORE_NAME: string = 'next2v_cache'
const KEY_PREFIX_TOPIC_LIST: string = 'topicList:'
const KEY_PREFIX_TOPIC_DETAIL: string = 'topicDetail:'
const KEY_CACHE_INDEX: string = 'cacheIndex'

export interface TopicDetailCache {
  topic: V2exTopic | null
  replies: V2exReply[]
  cachedAt: number
}

export interface CacheStats {
  topicListCount: number
  topicDetailCount: number
  updatedAt: number
}

export interface CacheKeyIndex {
  topicLists: string[]
  topicDetails: number[]
  updatedAt: number
}

interface CacheIndex {
  topicLists: string[]
  topicDetails: string[]
  updatedAt: number
}

export class CacheSettings {
  static async loadKeyIndex(context: common.UIAbilityContext): Promise<CacheKeyIndex> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const index = CacheSettings.readIndex(store)
      return {
        topicLists: index.topicLists.slice(),
        topicDetails: index.topicDetails
          .map((key: string) => parseInt(key, 10))
          .filter((id: number) => Number.isFinite(id) && id > 0),
        updatedAt: index.updatedAt
      }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取缓存索引失败')
    }
  }
  static async loadTopicList(context: common.UIAbilityContext, cacheKey: string): Promise<V2exTopic[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_PREFIX_TOPIC_LIST + cacheKey, '[]') as string
      return CacheSettings.parseTopicList(raw)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取列表缓存失败')
    }
  }

  static async saveTopicList(context: common.UIAbilityContext, cacheKey: string, topics: V2exTopic[]): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const next = topics.slice(0, 50)
      store.putSync(KEY_PREFIX_TOPIC_LIST + cacheKey, JSON.stringify(next))
      CacheSettings.writeIndex(store, (index: CacheIndex) => {
        if (index.topicLists.indexOf(cacheKey) < 0) {
          index.topicLists.push(cacheKey)
        }
      })
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存列表缓存失败')
    }
  }

  static async loadTopicDetail(context: common.UIAbilityContext, topicId: number): Promise<TopicDetailCache | null> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_PREFIX_TOPIC_DETAIL + topicId.toString(), '') as string
      if (!raw) {
        return null
      }
      return CacheSettings.parseTopicDetail(raw)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取详情缓存失败')
    }
  }

  static async saveTopicDetail(
    context: common.UIAbilityContext,
    topicId: number,
    topic: V2exTopic | null,
    replies: V2exReply[]
  ): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const payload: TopicDetailCache = {
        topic: topic,
        replies: replies,
        cachedAt: Math.floor(Date.now() / 1000)
      }
      store.putSync(KEY_PREFIX_TOPIC_DETAIL + topicId.toString(), JSON.stringify(payload))
      CacheSettings.writeIndex(store, (index: CacheIndex) => {
        const key = topicId.toString()
        if (index.topicDetails.indexOf(key) < 0) {
          index.topicDetails.push(key)
        }
      })
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存详情缓存失败')
    }
  }

  static async loadStats(context: common.UIAbilityContext): Promise<CacheStats> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const index = CacheSettings.readIndex(store)
      return {
        topicListCount: index.topicLists.length,
        topicDetailCount: index.topicDetails.length,
        updatedAt: index.updatedAt
      }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取缓存状态失败')
    }
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const index = CacheSettings.readIndex(store)
      index.topicLists.forEach((key: string) => {
        store.deleteSync(KEY_PREFIX_TOPIC_LIST + key)
      })
      index.topicDetails.forEach((key: string) => {
        store.deleteSync(KEY_PREFIX_TOPIC_DETAIL + key)
      })
      store.deleteSync(KEY_CACHE_INDEX)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '清理缓存失败')
    }
  }

  private static parseTopicList(raw: string): V2exTopic[] {
    try {
      const parsed = JSON.parse(raw) as V2exTopic[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return parsed.filter((item: V2exTopic) => item.id > 0 && item.title.length > 0)
    } catch (error) {
      return []
    }
  }

  private static parseTopicDetail(raw: string): TopicDetailCache | null {
    try {
      const parsed = JSON.parse(raw) as TopicDetailCache
      if (!parsed || !Array.isArray(parsed.replies)) {
        return null
      }
      return parsed
    } catch (error) {
      return null
    }
  }

  private static readIndex(store: preferences.Preferences): CacheIndex {
    try {
      const raw = store.getSync(KEY_CACHE_INDEX, '{"topicLists":[],"topicDetails":[],"updatedAt":0}') as string
      const parsed = JSON.parse(raw) as CacheIndex
      return {
        topicLists: Array.isArray(parsed.topicLists) ? parsed.topicLists : [],
        topicDetails: Array.isArray(parsed.topicDetails) ? parsed.topicDetails : [],
        updatedAt: parsed.updatedAt || 0
      }
    } catch (error) {
      return { topicLists: [], topicDetails: [], updatedAt: 0 }
    }
  }

  private static writeIndex(store: preferences.Preferences, update: (index: CacheIndex) => void): void {
    const index = CacheSettings.readIndex(store)
    update(index)
    index.updatedAt = Math.floor(Date.now() / 1000)
    try {
      store.putSync(KEY_CACHE_INDEX, JSON.stringify(index))
    } catch (error) {
      throw new Error('写入缓存索引失败')
    }
  }
}
