import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { ApiDomainSettings, MediaSettings, ReadingSettings, StorageKeys, WriteActionSettings } from 'shared'

const TRANSPARENT_COLOR: string = '#00FFFFFF'
const ENTRY_PAGE: string = 'pages/Index'
const FALLBACK_TOP_AVOID: number = 107
const FALLBACK_BOTTOM_AVOID: number = 0

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {}

  onWindowStageCreate(windowStage: window.WindowStage): void {
    let win: window.Window | null = null
    try {
      win = windowStage.getMainWindowSync()
      win.setWindowLayoutFullScreen(true)
      win.setWindowSystemBarProperties({
        statusBarColor: TRANSPARENT_COLOR,
        navigationBarColor: TRANSPARENT_COLOR
      })
    } catch (error) {
      const e = error as Error
      console.error('configure window failed: ' + e.message)
    }
    ApiDomainSettings.load(this.context)
      .catch((error: Error) => {
        console.error('restore api domain failed: ' + error.message)
        ApiDomainSettings.apply(false)
      })
      .finally(() => {
        MediaSettings.load(this.context)
          .catch((error: Error) => {
            console.error('restore media settings failed: ' + error.message)
            MediaSettings.apply(true, false)
          })
          .finally(() => {
            ReadingSettings.load(this.context)
              .catch((error: Error) => {
                console.error('restore reading settings failed: ' + error.message)
                ReadingSettings.apply(14, 20, ReadingSettings.DENSITY_STANDARD)
              })
              .finally(() => {
                WriteActionSettings.load(this.context)
                  .catch((error: Error) => {
                    console.error('restore write settings failed: ' + error.message)
                    WriteActionSettings.apply(false)
                  })
                  .finally(() => {
                    this.loadContent(windowStage, win)
                  })
              })
          })
      })
  }

  private loadContent(windowStage: window.WindowStage, win: window.Window | null): void {
    windowStage.loadContent(ENTRY_PAGE, (err) => {
      if (err.code) { console.error('loadContent failed: ' + JSON.stringify(err)) }
      try {
        if (!win) {
          win = windowStage.getMainWindowSync()
        }
        let systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
        let navArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
        let uiCtx = windowStage.getMainWindowSync().getUIContext()
        AppStorage.setOrCreate<number>(StorageKeys.TOP_AVOID_HEIGHT, uiCtx.px2vp(systemArea.topRect.height))
        AppStorage.setOrCreate<number>(StorageKeys.BOTTOM_AVOID_HEIGHT, uiCtx.px2vp(navArea.bottomRect.height))
      } catch (e) {
        AppStorage.setOrCreate<number>(StorageKeys.TOP_AVOID_HEIGHT, FALLBACK_TOP_AVOID)
        AppStorage.setOrCreate<number>(StorageKeys.BOTTOM_AVOID_HEIGHT, FALLBACK_BOTTOM_AVOID)
      }
    })
  }

  onDestroy(): void {}
}
