import { promptAction, UIContext, uiMaterial } from '@kit.ArkUI'
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

  static showAlertDialog(
    uiContext: UIContext,
    options: AlertDialogParamWithConfirm | AlertDialogParamWithButtons | AlertDialogParamWithOptions,
  ): void {
    const material = AppPrompt.surfaceSystemMaterial()
    if (material !== undefined) {
      options.systemMaterial = material
    }
    uiContext.showAlertDialog(options)
  }

  static surfaceSystemMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined
    }
    return ImmersiveMaterialSettings.systemMaterial(
      connectImmersiveMaterialSettings().level,
      uiMaterial.ImmersiveStyle.REGULAR,
      false,
    )
  }

  private static toastMaterial(): uiMaterial.Material | undefined {
    return ImmersiveMaterialSettings.systemMaterial(
      connectImmersiveMaterialSettings().level,
      uiMaterial.ImmersiveStyle.REGULAR,
      false,
    )
  }
}
