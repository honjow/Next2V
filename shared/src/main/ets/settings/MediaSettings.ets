import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'
import { STORE_NAME_SETTINGS, SettingsPreferencesStore, setAppStorageValue } from './SettingsStorage'
import { connectMediaSettings } from '../state/MediaSettingsState'

const STORE_NAME: string = STORE_NAME_SETTINGS
// Legacy preferences keys differ from StorageKeys.MEDIA_* AppStorage keys; keep them for compatibility.
const KEY_AUTO_LOAD_IMAGES: string = 'autoLoadImages'
const KEY_ONLY_LOAD_IMAGES_ON_WIFI: string = 'onlyLoadImagesOnWifi'

export interface MediaSettingsSnapshot {
  autoLoadImages: boolean
  onlyLoadImagesOnWifi: boolean
}

export class MediaSettings {
  static apply(autoLoadImages: boolean, onlyLoadImagesOnWifi: boolean = false): void {
    setAppStorageValue<boolean>(StorageKeys.MEDIA_AUTO_LOAD_IMAGES, autoLoadImages)
    setAppStorageValue<boolean>(StorageKeys.MEDIA_ONLY_LOAD_IMAGES_ON_WIFI, onlyLoadImagesOnWifi)
    // V2 mirror dual-write: keeps @ComponentV2 readers (MarkdownContent's MarkdownAutoImage,
    // which @Monitors the policy) in sync with the V1 AppStorage keys read by @StorageLink.
    const mediaState = connectMediaSettings()
    mediaState.autoLoadImages = autoLoadImages
    mediaState.onlyLoadImagesOnWifi = onlyLoadImagesOnWifi
  }

  static async load(context: common.UIAbilityContext): Promise<MediaSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      return MediaSettings.loadFromStore(store)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to read media settings')
    }
  }

  static async loadFromStore(store: SettingsPreferencesStore): Promise<MediaSettingsSnapshot> {
    const autoLoadImages = store.getSync(KEY_AUTO_LOAD_IMAGES, true) as boolean
    const onlyLoadImagesOnWifi = store.getSync(KEY_ONLY_LOAD_IMAGES_ON_WIFI, false) as boolean
    MediaSettings.apply(autoLoadImages, onlyLoadImagesOnWifi)
    return {
      autoLoadImages: autoLoadImages,
      onlyLoadImagesOnWifi: onlyLoadImagesOnWifi
    }
  }

  static async save(context: common.UIAbilityContext, autoLoadImages: boolean, onlyLoadImagesOnWifi: boolean): Promise<void> {
    MediaSettings.apply(autoLoadImages, onlyLoadImagesOnWifi)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_AUTO_LOAD_IMAGES, autoLoadImages)
      store.putSync(KEY_ONLY_LOAD_IMAGES_ON_WIFI, onlyLoadImagesOnWifi)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || 'Failed to save media settings')
    }
  }
}
