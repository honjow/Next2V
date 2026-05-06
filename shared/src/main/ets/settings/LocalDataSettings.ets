import { common } from '@kit.AbilityKit'
import { StorageKeys } from '../constants/StorageKeys'
import { CacheSettings } from './CacheSettings'
import { CollectionSettings } from './CollectionSettings'
import { DraftSettings } from './DraftSettings'
import { NotificationSettings } from './NotificationSettings'
import { SearchSettings } from './SearchSettings'

export class LocalDataSettings {
  static async clearAll(context: common.UIAbilityContext): Promise<void> {
    await Promise.all([
      CollectionSettings.clearAll(context),
      DraftSettings.clearAll(context),
      SearchSettings.clearHistory(context),
      CacheSettings.clear(context),
      NotificationSettings.clearCache(context)
    ])
    AppStorage.setOrCreate<number>(StorageKeys.LOCAL_DATA_UPDATED_AT, Math.floor(Date.now() / 1000))
  }
}
