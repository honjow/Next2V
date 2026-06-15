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
    options:
      | AlertDialogParamWithConfirm
      | AlertDialogParamWithButtons
      | AlertDialogParamWithOptions,
  ): void {
    // An AlertDialog is a 弹出框: HarmonyOS's immersive-material guidance puts dialog boxes in the
    // ULTRA_THICK tier so the blurred backdrop stays opaque enough to read the dialog body over the page
    // behind it (the default REGULAR read as "too transparent" once API 26 started rendering the material).
    const material = AppPrompt.modalSystemMaterial()
    if (material !== undefined) {
      options.systemMaterial = material
    }
    uiContext.showAlertDialog(options)
  }

  // Menus / popups / context menus that are non-resident and pop at an arbitrary anchor position. The
  // immersive-material guidance recommends THICK for this class so their short option labels stay legible
  // over whatever content sits behind them.
  static surfaceSystemMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined
    }
    return ImmersiveMaterialSettings.systemMaterial(
      connectImmersiveMaterialSettings().level,
      uiMaterial.ImmersiveStyle.THICK,
      false,
    )
  }

  // Semi-modal sheets and dialog boxes (半模态 / 弹出框) cover a large area with rich content; the guidance
  // recommends the thickest ULTRA_THICK tier so the blurred backdrop never lets the page behind bleed
  // through and hurt readability.
  static modalSystemMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined
    }
    return ImmersiveMaterialSettings.systemMaterial(
      connectImmersiveMaterialSettings().level,
      uiMaterial.ImmersiveStyle.ULTRA_THICK,
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
