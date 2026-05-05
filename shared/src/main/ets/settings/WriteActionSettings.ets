import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { StorageKeys } from '../constants/StorageKeys'

const STORE_NAME: string = 'next2v_settings'
const KEY_ACCOUNT_WRITE_ENABLED: string = 'accountWriteEnabled'

export class WriteActionSettings {
  static apply(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(StorageKeys.ACCOUNT_WRITE_ENABLED, enabled)
  }

  static async load(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const enabled = store.getSync(KEY_ACCOUNT_WRITE_ENABLED, false) as boolean
      WriteActionSettings.apply(enabled)
      return enabled
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取写入设置失败')
    }
  }

  static async save(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    WriteActionSettings.apply(enabled)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_ACCOUNT_WRITE_ENABLED, enabled)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存写入设置失败')
    }
  }
}

