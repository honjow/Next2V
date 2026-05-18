import { common } from '@kit.AbilityKit'
import {
  ApiService,
  CacheSettings,
  type CacheKeyIndex,
  CollectionSettings,
  NodeSearchUtils,
  type SavedNode,
  type SavedTopic,
  type V2exNode,
  type ViewedTopic,
} from 'shared'
import type {
  SearchTopicItem,
} from '../components/SearchPageComponents'

export interface SearchLocalCollections {
  savedTopics: SavedTopic[]
  viewedTopics: ViewedTopic[]
  savedNodes: SavedNode[]
}

export interface SearchCacheCollections {
  cacheTopicLists: SearchTopicItem[]
  cacheTopicDetails: SearchTopicItem[]
}

export class SearchLocalDataCoordinator {
  static async loadLocalCollections(context: common.UIAbilityContext): Promise<SearchLocalCollections> {
    const results = await Promise.all([
      CollectionSettings.loadSavedTopics(context),
      CollectionSettings.loadViewedTopics(context),
      CollectionSettings.loadSavedNodes(context),
    ])
    return {
      savedTopics: results[0] || [],
      viewedTopics: results[1] || [],
      savedNodes: results[2] || [],
    }
  }

  static async loadCacheCollections(context: common.UIAbilityContext): Promise<SearchCacheCollections> {
    const index = await CacheSettings.loadKeyIndex(context)
    const listTopics = await SearchLocalDataCoordinator.loadCachedTopicLists(context, index)
    const detailTopics = await SearchLocalDataCoordinator.loadCachedTopicDetails(context, index)
    return {
      cacheTopicLists: listTopics,
      cacheTopicDetails: detailTopics,
    }
  }

  static async loadNodeIndex(api: ApiService): Promise<V2exNode[]> {
    const nodes = await api.getAllNodes()
    return NodeSearchUtils.sortByPopularity(nodes)
  }

  private static async loadCachedTopicLists(
    context: common.UIAbilityContext,
    index: CacheKeyIndex,
  ): Promise<SearchTopicItem[]> {
    const listTopics = new Map<number, SearchTopicItem>()
    for (const key of index.topicLists) {
      const topics = await CacheSettings.loadTopicList(context, key)
      for (const topic of topics) {
        const item: SearchTopicItem = {
          id: topic.id,
          title: topic.title,
          nodeName: topic.node.name,
          nodeTitle: topic.node.title,
          username: topic.member.username,
          source: '缓存(列表)',
          updatedAt: index.updatedAt,
        }
        listTopics.set(item.id, item)
      }
    }
    return Array.from(listTopics.values())
  }

  private static async loadCachedTopicDetails(
    context: common.UIAbilityContext,
    index: CacheKeyIndex,
  ): Promise<SearchTopicItem[]> {
    const detailTopics = new Map<number, SearchTopicItem>()
    for (const topicId of index.topicDetails) {
      const detail = await CacheSettings.loadTopicDetail(context, topicId)
      if (!detail || !detail.topic) {
        continue
      }
      const topic = detail.topic
      const item: SearchTopicItem = {
        id: topic.id,
        title: topic.title,
        nodeName: topic.node.name,
        nodeTitle: topic.node.title,
        username: topic.member.username,
        source: '缓存(详情)',
        updatedAt: detail.cachedAt || index.updatedAt,
      }
      detailTopics.set(item.id, item)
    }
    return Array.from(detailTopics.values())
  }
}
