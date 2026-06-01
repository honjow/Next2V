import { common } from '@kit.AbilityKit'
import { CacheSettings } from './CacheSettings'
import { TopicDetailActionOverlaySettings } from '../cache/TopicDetailActionOverlaySettings'
import { CollectionSettings } from './CollectionSettings'
import { DraftSettings } from './DraftSettings'
import { NotificationSettings } from './NotificationSettings'
import { SearchSettings } from './SearchSettings'
import { connectLocalDataSignal } from '../state/LocalDataSignalState'

export class LocalDataSettings {
  static async clearAll(context: common.UIAbilityContext): Promise<void> {
    await Promise.all([
      CollectionSettings.clearAll(context),
      DraftSettings.clearAll(context),
      SearchSettings.clearHistory(context),
      CacheSettings.clear(context),
      TopicDetailActionOverlaySettings.clearAll(context),
      NotificationSettings.clearCache(context)
    ])
    // Pure-V2: bump the local-data-changed signal mirror (read via @Monitor by @ComponentV2 AccountPage).
    connectLocalDataSignal().updatedAt = Math.floor(Date.now() / 1000)
  }
}
