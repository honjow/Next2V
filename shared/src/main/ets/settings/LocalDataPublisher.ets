import { StorageKeys } from '../constants/StorageKeys'
import type { LocalContentStats, TopicReadState } from './CollectionTypes'
import { setAppStorageValue } from './SettingsStorage'
import { connectLocalDataSignal } from '../state/LocalDataSignalState'
import { connectTopicReadStates } from '../state/TopicReadStatesState'

export class LocalDataPublisher {
  static touchLocalData(): void {
    const updatedAt = Date.now()
    setAppStorageValue<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, updatedAt)
    // Dual-write the V2 local-data-changed signal (read via @Monitor by @ComponentV2 AccountPage).
    connectLocalDataSignal().updatedAt = updatedAt
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
    // Dual-write the V1 AppStorage key (V1 @StorageLink readers) AND the V2 mirror
    // (@ComponentV2 readers); single-writer chokepoint keeps the two stores in lockstep.
    const json = JSON.stringify(states)
    setAppStorageValue<string>(StorageKeys.TOPIC_READ_STATES, json)
    connectTopicReadStates().statesJson = json
  }

  static clearTopicReadStates(): void {
    setAppStorageValue<string>(StorageKeys.TOPIC_READ_STATES, '[]')
    connectTopicReadStates().statesJson = '[]'
  }

  private static publishLocalContentCount(key: string, count: number): void {
    setAppStorageValue<number>(key, count)
  }
}
