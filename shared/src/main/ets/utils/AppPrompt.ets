import { promptAction, uiMaterial } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'
import { ImmersiveMaterialSettings } from '../settings/ImmersiveMaterialSettings'
import { connectImmersiveMaterialSettings } from '../state/ImmersiveMaterialSettingsState'

export class AppPrompt {
  static openToast(options: promptAction.ShowToastOptions): Promise<number> {
    if (deviceInfo.apiAvailable('26.0.0')) {
      options.systemMaterial = AppPrompt.toastMaterial()
    }
    return promptAction.openToast(options)
  }

  private static toastMaterial(): uiMaterial.Material | undefined {
    return ImmersiveMaterialSettings.systemMaterial(
      connectImmersiveMaterialSettings().level,
      uiMaterial.ImmersiveStyle.REGULAR,
      false,
    )
  }
}
