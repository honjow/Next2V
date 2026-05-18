import { common } from '@kit.AbilityKit'
import {
  CollectionSettings,
  LocalContentStats,
  SavedNode,
  SavedTopic,
  ViewedTopic
} from 'shared'

export interface AccountSavedTopicsResult {
  items: SavedTopic[]
  count: number
}

export interface AccountSavedNodesResult {
  items: SavedNode[]
  count: number
}

export interface AccountViewedTopicsResult {
  items: ViewedTopic[]
  count: number
}

export class AccountLocalContentCoordinator {
  static async loadSavedTopics(context: common.UIAbilityContext): Promise<AccountSavedTopicsResult> {
    const items = await CollectionSettings.loadSavedTopics(context)
    return {
      items,
      count: items.length
    }
  }

  static async loadSavedNodes(context: common.UIAbilityContext): Promise<AccountSavedNodesResult> {
    const items = await CollectionSettings.loadSavedNodes(context)
    return {
      items,
      count: items.length
    }
  }

  static async loadViewedTopics(context: common.UIAbilityContext): Promise<AccountViewedTopicsResult> {
    const items = await CollectionSettings.loadViewedTopics(context)
    return {
      items,
      count: items.length
    }
  }

  static async loadLocalContentStats(context: common.UIAbilityContext): Promise<LocalContentStats> {
    return await CollectionSettings.loadLocalContentStats(context)
  }

  static async syncTopicReadStates(context: common.UIAbilityContext): Promise<void> {
    await CollectionSettings.syncTopicReadStates(context)
  }
}
