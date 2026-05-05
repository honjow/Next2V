import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { ApiDomainSettings, StorageKeys } from 'shared'

const TRANSPARENT_COLOR: string = '#00FFFFFF'
const ENTRY_PAGE: string = 'pages/Index'
const FALLBACK_TOP_AVOID: number = 107
const FALLBACK_BOTTOM_AVOID: number = 0

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {}

  onWindowStageCreate(windowStage: window.WindowStage): void {
    let win = windowStage.getMainWindowSync()
    win.setWindowLayoutFullScreen(true)
    win.setWindowSystemBarProperties({
      statusBarColor: TRANSPARENT_COLOR,
      navigationBarColor: TRANSPARENT_COLOR
    })
    ApiDomainSettings.load(this.context)
      .catch((error: Error) => {
        console.error('restore api domain failed: ' + error.message)
        ApiDomainSettings.apply(false)
      })
      .finally(() => {
        this.loadContent(windowStage, win)
      })
  }

  private loadContent(windowStage: window.WindowStage, win: window.Window): void {
    windowStage.loadContent(ENTRY_PAGE, (err) => {
      if (err.code) { console.error('loadContent failed: ' + JSON.stringify(err)) }
      try {
        let systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
        let navArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
        let uiCtx = windowStage.getMainWindowSync().getUIContext()
        AppStorage.SetOrCreate<number>(StorageKeys.TOP_AVOID_HEIGHT, uiCtx.px2vp(systemArea.topRect.height))
        AppStorage.SetOrCreate<number>(StorageKeys.BOTTOM_AVOID_HEIGHT, uiCtx.px2vp(navArea.bottomRect.height))
      } catch (e) {
        AppStorage.SetOrCreate<number>(StorageKeys.TOP_AVOID_HEIGHT, FALLBACK_TOP_AVOID)
        AppStorage.SetOrCreate<number>(StorageKeys.BOTTOM_AVOID_HEIGHT, FALLBACK_BOTTOM_AVOID)
      }
    })
  }

  onDestroy(): void {}
}
