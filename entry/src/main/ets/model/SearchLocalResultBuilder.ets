import {
  NodeSearchUtils,
  type SavedNode,
  type SavedTopic,
  type V2exNode,
  type ViewedTopic,
} from 'shared'
import { AppStrings } from 'shared'
import type {
  SearchNodeItem,
  SearchResultFilter,
  SearchTopicItem,
} from '../components/SearchPageComponents'

export interface SearchLocalResultInput {
  keyword: string
  resultFilter: SearchResultFilter
  includeTopics: boolean
  includeNodes: boolean
  usesNodeIndex: boolean
  savedTopics: SavedTopic[]
  viewedTopics: ViewedTopic[]
  savedNodes: SavedNode[]
  allNodes: V2exNode[]
  cacheTopicLists: SearchTopicItem[]
  cacheTopicDetails: SearchTopicItem[]
}

export interface SearchLocalResult {
  topicResults: SearchTopicItem[]
  nodeResults: SearchNodeItem[]
}

export class SearchLocalResultBuilder {
  static build(input: SearchLocalResultInput): SearchLocalResult {
    const q = input.keyword.trim().toLowerCase()
    if (!q) {
      return { topicResults: [], nodeResults: [] }
    }
    const topicResults = input.includeTopics ? SearchLocalResultBuilder.buildTopicResults(input, q) : []
    const nodeResults = input.includeNodes ? SearchLocalResultBuilder.buildNodeResults(input, q) : []
    return { topicResults, nodeResults }
  }

  private static buildTopicResults(input: SearchLocalResultInput, q: string): SearchTopicItem[] {
    const bag = new Map<number, SearchTopicItem>()

    for (const item of input.savedTopics) {
      const topic: SearchTopicItem = {
        id: item.id,
        title: item.title,
        nodeName: item.nodeName,
        nodeTitle: item.nodeTitle,
        username: item.username,
        source: AppStrings.text($r('app.string.search_source_favorite'), 'Saved'),
        updatedAt: item.savedAt || 0,
      }
      if (SearchLocalResultBuilder.topicMatches(topic, q, input.resultFilter)) {
        bag.set(topic.id, topic)
      }
    }

    for (const item of input.viewedTopics) {
      const existing = bag.get(item.id)
      const topic: SearchTopicItem = existing ? existing : {
        id: item.id,
        title: item.title,
        nodeName: item.nodeName,
        nodeTitle: item.nodeTitle,
        username: item.username,
        source: AppStrings.text($r('app.string.search_source_recent'), 'Recent'),
        updatedAt: item.viewedAt || 0,
      }
      if (!SearchLocalResultBuilder.topicMatches(topic, q, input.resultFilter)) {
        continue
      }
      if (!existing) {
        bag.set(topic.id, topic)
      } else {
        existing.source = SearchLocalResultBuilder.mergeSource(existing.source, AppStrings.text($r('app.string.search_source_recent'), 'Recent'))
        existing.updatedAt = Math.max(existing.updatedAt, item.viewedAt || 0)
      }
    }

    SearchLocalResultBuilder.mergeCachedTopics(bag, input.cacheTopicDetails, q, input.resultFilter)
    SearchLocalResultBuilder.mergeCachedTopics(bag, input.cacheTopicLists, q, input.resultFilter)

    return Array.from(bag.values())
      .sort((left: SearchTopicItem, right: SearchTopicItem) => right.updatedAt - left.updatedAt)
  }

  private static mergeCachedTopics(
    bag: Map<number, SearchTopicItem>,
    items: SearchTopicItem[],
    q: string,
    resultFilter: SearchResultFilter,
  ): void {
    for (const item of items) {
      if (!SearchLocalResultBuilder.topicMatches(item, q, resultFilter)) {
        continue
      }
      const existing = bag.get(item.id)
      if (!existing) {
        bag.set(item.id, item)
      } else {
        existing.source = SearchLocalResultBuilder.mergeSource(existing.source, item.source)
        existing.updatedAt = Math.max(existing.updatedAt, item.updatedAt)
      }
    }
  }

  private static buildNodeResults(input: SearchLocalResultInput, q: string): SearchNodeItem[] {
    const nodeBag = new Map<string, SearchNodeItem>()

    for (const item of input.savedNodes) {
      const node = SearchLocalResultBuilder.savedNodeToV2exNode(item)
      const score = NodeSearchUtils.scoreNode(node, q)
      if (score <= 0) {
        continue
      }
      nodeBag.set(item.name, {
        name: item.name,
        title: item.title,
        topics: item.topics,
        source: AppStrings.text($r('app.string.search_source_followed'), 'Followed'),
        updatedAt: item.savedAt || 0,
        score: score + 1200,
      })
    }

    if (input.usesNodeIndex) {
      for (const match of NodeSearchUtils.search(input.allNodes, q).slice(0, 120)) {
        const node = match.node
        const existing = nodeBag.get(node.name)
        if (!existing) {
          nodeBag.set(node.name, {
            name: node.name,
            title: node.title,
            topics: node.topics,
            source: AppStrings.text($r('app.string.search_source_nodes_library'), 'Node library'),
            updatedAt: 0,
            score: match.score,
          })
        } else {
          existing.title = existing.title || node.title
          existing.topics = Math.max(existing.topics, node.topics)
          existing.source = SearchLocalResultBuilder.mergeSource(existing.source, AppStrings.text($r('app.string.search_source_nodes_library'), 'Node library'))
          existing.score = Math.max(existing.score, match.score + 1200)
        }
      }
    }

    return Array.from(nodeBag.values())
      .sort((left: SearchNodeItem, right: SearchNodeItem) => {
        if (right.score !== left.score) {
          return right.score - left.score
        }
        if (right.updatedAt !== left.updatedAt) {
          return right.updatedAt - left.updatedAt
        }
        return right.topics - left.topics
      })
  }

  private static topicMatches(item: SearchTopicItem, q: string, filter: SearchResultFilter): boolean {
    if (filter === 'users') {
      return item.username.toLowerCase().includes(q)
    }
    if (item.id.toString().includes(q)) {
      return true
    }
    if (item.title.toLowerCase().includes(q)) {
      return true
    }
    if (item.nodeName.toLowerCase().includes(q)) {
      return true
    }
    if (item.nodeTitle.toLowerCase().includes(q)) {
      return true
    }
    return item.username.toLowerCase().includes(q)
  }

  private static mergeSource(existing: string, incoming: string): string {
    const parts = existing.split(' · ').map((source: string) => source.trim()).filter((source: string) => source.length > 0)
    if (parts.indexOf(incoming) >= 0) {
      return existing
    }
    parts.push(incoming)
    return parts.join(' · ')
  }

  private static savedNodeToV2exNode(item: SavedNode): V2exNode {
    return {
      id: 0,
      name: item.name,
      title: item.title,
      title_alternative: '',
      url: '',
      topics: item.topics,
      avatar_mini: item.avatarMini || '',
      avatar_normal: item.avatarNormal || '',
      avatar_large: item.avatarLarge || '',
    }
  }
}
