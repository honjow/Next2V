import { StorageKeys } from '../constants/StorageKeys'
import type { LocalContentStats, TopicReadState } from './CollectionTypes'
import { setAppStorageValue } from './SettingsStorage'
import { connectLocalContentStats, connectLocalDataSignal } from '../state/LocalDataSignalState'
import { connectTopicReadStates } from '../state/TopicReadStatesState'

export class LocalDataPublisher {
  static touchLocalData(): void {
    // Pure-V2: bump the local-data-changed signal mirror (read via @Monitor by @ComponentV2 AccountPage).
    connectLocalDataSignal().updatedAt = Date.now()
  }

  static publishLocalContentStats(stats: LocalContentStats): void {
    const holder = connectLocalContentStats()
    holder.savedTopicCount = stats.savedTopicCount
    holder.savedNodeCount = stats.savedNodeCount
    holder.viewedTopicCount = stats.viewedTopicCount
  }

  static publishSavedTopicCount(count: number): void {
    connectLocalContentStats().savedTopicCount = count
  }

  static publishSavedNodeCount(count: number): void {
    connectLocalContentStats().savedNodeCount = count
  }

  static publishViewedTopicCount(count: number): void {
    connectLocalContentStats().viewedTopicCount = count
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
}
