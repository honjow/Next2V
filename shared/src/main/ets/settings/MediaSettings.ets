import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'

const STORE_NAME: string = 'next2v_settings'
const KEY_AUTO_LOAD_IMAGES: string = 'autoLoadImages'

export class MediaSettings {
  static apply(autoLoadImages: boolean): void {
    AppStorage.setOrCreate<boolean>(StorageKeys.MEDIA_AUTO_LOAD_IMAGES, autoLoadImages)
  }

  static async load(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const autoLoadImages = store.getSync(KEY_AUTO_LOAD_IMAGES, true) as boolean
      MediaSettings.apply(autoLoadImages)
      return autoLoadImages
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取媒体设置失败')
    }
  }

  static async save(context: common.UIAbilityContext, autoLoadImages: boolean): Promise<void> {
    MediaSettings.apply(autoLoadImages)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_AUTO_LOAD_IMAGES, autoLoadImages)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存媒体设置失败')
    }
  }
}

