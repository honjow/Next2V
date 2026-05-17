import { StorageKeys } from '../constants/StorageKeys'
import type { LocalContentStats, TopicReadState } from './CollectionTypes'
import { setAppStorageValue } from './SettingsStorage'

export class LocalDataPublisher {
  static touchLocalData(): void {
    const updatedAt = Date.now()
    setAppStorageValue<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, updatedAt)
  }

  static publishLocalContentStats(stats: LocalContentStats): void {
    LocalDataPublisher.publishLocalContentCount(StorageKeys.LOCAL_SAVED_TOPIC_COUNT, stats.savedTopicCount)
    LocalDataPublisher.publishLocalContentCount(StorageKeys.LOCAL_SAVED_NODE_COUNT, stats.savedNodeCount)
    LocalDataPublisher.publishLocalContentCount(StorageKeys.LOCAL_VIEWED_TOPIC_COUNT, stats.viewedTopicCount)
  }

  static publishSavedTopicCount(count: number): void {
    LocalDataPublisher.publishLocalContentCount(StorageKeys.LOCAL_SAVED_TOPIC_COUNT, count)
  }

  static publishSavedNodeCount(count: number): void {
    LocalDataPublisher.publishLocalContentCount(StorageKeys.LOCAL_SAVED_NODE_COUNT, count)
  }

  static publishViewedTopicCount(count: number): void {
    LocalDataPublisher.publishLocalContentCount(StorageKeys.LOCAL_VIEWED_TOPIC_COUNT, count)
  }

  static publishTopicReadStates(states: TopicReadState[]): void {
    setAppStorageValue<string>(StorageKeys.TOPIC_READ_STATES, JSON.stringify(states))
  }

  static clearTopicReadStates(): void {
    setAppStorageValue<string>(StorageKeys.TOPIC_READ_STATES, '[]')
  }

  private static publishLocalContentCount(key: string, count: number): void {
    setAppStorageValue<number>(key, count)
  }
}
