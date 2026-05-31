import { common } from '@kit.AbilityKit'
import { StorageKeys } from '../constants/StorageKeys'
import { CacheSettings } from './CacheSettings'
import { TopicDetailActionOverlaySettings } from '../cache/TopicDetailActionOverlaySettings'
import { CollectionSettings } from './CollectionSettings'
import { DraftSettings } from './DraftSettings'
import { NotificationSettings } from './NotificationSettings'
import { SearchSettings } from './SearchSettings'
import { setAppStorageValue } from './SettingsStorage'
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
    const updatedAt = Math.floor(Date.now() / 1000)
    setAppStorageValue<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, updatedAt)
    // Dual-write the V2 local-data-changed signal (read via @Monitor by @ComponentV2 AccountPage).
    connectLocalDataSignal().updatedAt = updatedAt
  }
}
