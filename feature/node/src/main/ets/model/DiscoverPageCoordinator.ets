import { AppStrings } from 'shared'
import { V2exTopic } from 'shared'
import type { SavedNode, ViewedTopic } from 'shared'
import { DiscoverTopicMode } from '../components/DiscoverPageComponents'

export interface DiscoverTopicBuckets {
  hot: V2exTopic[]
  rank: V2exTopic[]
  latest: V2exTopic[]
  recent: V2exTopic[]
}

export class DiscoverPageCoordinator {
  static hasNodeSearchQuery(keyword: string): boolean {
    return (keyword || '').trim().length > 0
  }

  static topicModeLabel(mode: DiscoverTopicMode): string {
    if (mode === 'hot') {
      return AppStrings.text($r('app.string.discover_today_hot'), 'Today’s hot topics')
    }
    if (mode === 'rank') {
      return AppStrings.text(AppStrings.R_DISCOVER_SITE_RANK, 'Site-wide hot')
    }
    if (mode === 'recent') {
      return AppStrings.text(AppStrings.R_DISCOVER_RECENT_UPDATES, 'Recently updated')
    }
    return AppStrings.text(AppStrings.R_DISCOVER_LATEST_TOPICS, 'Latest topics')
  }

  static topicItems(mode: DiscoverTopicMode, buckets: DiscoverTopicBuckets): V2exTopic[] {
    if (mode === 'hot') {
      return buckets.hot
    }
    if (mode === 'rank') {
      return buckets.rank
    }
    if (mode === 'recent') {
      return buckets.recent
    }
    return buckets.latest
  }

  static shouldLoadTopicSurface(mode: DiscoverTopicMode, buckets: DiscoverTopicBuckets, isLoading: boolean): boolean {
    if (isLoading) {
      return false
    }
    return DiscoverPageCoordinator.topicItems(mode, buckets).length === 0
  }

  static withTopics(mode: DiscoverTopicMode, buckets: DiscoverTopicBuckets, topics: V2exTopic[]): DiscoverTopicBuckets {
    const nextTopics = topics || []
    return {
      hot: mode === 'hot' ? nextTopics : buckets.hot,
      rank: mode === 'rank' ? nextTopics : buckets.rank,
      latest: mode === 'latest' ? nextTopics : buckets.latest,
      recent: mode === 'recent' ? nextTopics : buckets.recent,
    }
  }

  static withoutTopics(mode: DiscoverTopicMode, buckets: DiscoverTopicBuckets): DiscoverTopicBuckets {
    return DiscoverPageCoordinator.withTopics(mode, buckets, [])
  }

  static recentNodesFromViewedTopics(viewedTopics: ViewedTopic[], savedNodes: SavedNode[], limit: number = 12): SavedNode[] {
    const saved = new Set(savedNodes.map((node: SavedNode) => node.name))
    const seen: Set<string> = new Set()
    const nodes: SavedNode[] = []
    for (const topic of viewedTopics) {
      const name = (topic.nodeName || '').trim()
      if (!name || seen.has(name) || saved.has(name)) {
        continue
      }
      nodes.push({
        name: name,
        title: topic.nodeTitle || name,
        topics: 0,
        savedAt: topic.viewedAt || 0
      })
      seen.add(name)
      if (nodes.length >= limit) {
        break
      }
    }
    return nodes
  }
}
