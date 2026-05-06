import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'

const STORE_NAME: string = 'next2v_settings'
const KEY_AUTO_LOAD_IMAGES: string = 'autoLoadImages'
const KEY_ONLY_LOAD_IMAGES_ON_WIFI: string = 'onlyLoadImagesOnWifi'

export interface MediaSettingsSnapshot {
  autoLoadImages: boolean
  onlyLoadImagesOnWifi: boolean
}

export class MediaSettings {
  static apply(autoLoadImages: boolean, onlyLoadImagesOnWifi: boolean = false): void {
    AppStorage.setOrCreate<boolean>(StorageKeys.MEDIA_AUTO_LOAD_IMAGES, autoLoadImages)
    AppStorage.setOrCreate<boolean>(StorageKeys.MEDIA_ONLY_LOAD_IMAGES_ON_WIFI, onlyLoadImagesOnWifi)
  }

  static async load(context: common.UIAbilityContext): Promise<MediaSettingsSnapshot> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const autoLoadImages = store.getSync(KEY_AUTO_LOAD_IMAGES, true) as boolean
      const onlyLoadImagesOnWifi = store.getSync(KEY_ONLY_LOAD_IMAGES_ON_WIFI, false) as boolean
      MediaSettings.apply(autoLoadImages, onlyLoadImagesOnWifi)
      return {
        autoLoadImages: autoLoadImages,
        onlyLoadImagesOnWifi: onlyLoadImagesOnWifi
      }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取媒体设置失败')
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
      throw new Error(e.message || '保存媒体设置失败')
    }
  }
}
