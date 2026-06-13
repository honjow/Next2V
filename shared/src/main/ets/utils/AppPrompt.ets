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
    if (deviceInfo.apiAvailable('26.0.0')) {
      options.systemMaterial = AppPrompt.dialogMaterial()
    }
    uiContext.showAlertDialog(options)
  }

  private static toastMaterial(): uiMaterial.Material | undefined {
    return ImmersiveMaterialSettings.systemMaterial(
      connectImmersiveMaterialSettings().level,
      uiMaterial.ImmersiveStyle.REGULAR,
      false,
    )
  }

  private static dialogMaterial(): uiMaterial.Material | undefined {
    return ImmersiveMaterialSettings.systemMaterial(
      connectImmersiveMaterialSettings().level,
      uiMaterial.ImmersiveStyle.REGULAR,
      false,
    )
  }
}
