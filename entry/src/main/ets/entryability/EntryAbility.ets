import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { Configuration } from '@ohos.app.ability.Configuration'
import { window } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import {
  ApiDomainSettings,
  AutoDailyCheckinService,
  AutoDailyCheckinSettings,
  CookieJarSettings,
  FeedTabSettings,
  FoldScreenUtil,
  MediaSettings,
  ReadingSettings,
  ReplyActionAlignmentSettings,
  ReplyDisplaySettings,
  ReplyCardStyleSettings,
  StorageKeys,
  ThemeSettings,
  V2exUrlRouter,
} from 'shared'

const TRANSPARENT_COLOR: string = '#00FFFFFF'
const ENTRY_PAGE: string = 'pages/Index'
const FALLBACK_TOP_AVOID: number = 107
const FALLBACK_BOTTOM_AVOID: number = 0

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null
  private keyboardHeightCallback: ((height: number) => void) | null = null

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      webview.WebviewController.initializeWebEngine()
    } catch (error) {
      const e = error as Error
      console.error('initialize web engine failed: ' + e.message)
    }
    this.captureIncomingUrl(want)

    // 初始化折叠屏状态监听
    FoldScreenUtil.getInstance().init()
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.captureIncomingUrl(want)
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    let win: window.Window | null = null
    try {
      win = windowStage.getMainWindowSync()
      win.setWindowLayoutFullScreen(true)
      win.setWindowSystemBarProperties({
        statusBarColor: TRANSPARENT_COLOR,
        navigationBarColor: TRANSPARENT_COLOR,
      })
      this.configureWideGamut(win)
      this.mainWindow = win
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
        ThemeSettings.load(this.context)
          .catch((error: Error) => {
            console.error('restore theme settings failed: ' + error.message)
            ThemeSettings.apply(this.context, ThemeSettings.MODE_AUTO)
          })
          .finally(() => {
            MediaSettings.load(this.context)
              .catch((error: Error) => {
                console.error('restore media settings failed: ' + error.message)
                MediaSettings.apply(true, false)
              })
              .finally(() => {
                ReplyDisplaySettings.load(this.context)
                  .catch((error: Error) => {
                    console.error('restore reply display settings failed: ' + error.message)
                    ReplyDisplaySettings.apply(ReplyDisplaySettings.MODE_THREAD)
                  })
                  .finally(() => {
                    ReadingSettings.load(this.context)
                      .catch((error: Error) => {
                        console.error('restore reading settings failed: ' + error.message)
                        ReadingSettings.apply(14, 20, ReadingSettings.DENSITY_STANDARD)
                      })
                      .finally(() => {
                        FeedTabSettings.load(this.context)
                          .catch((error: Error) => {
                            console.error('restore feed tab settings failed: ' + error.message)
                            FeedTabSettings.apply(FeedTabSettings.defaultKeysJson())
                          })
                          .finally(() => {
                            CookieJarSettings.load(this.context)
                              .catch((error: Error) => {
                                console.error('restore cookie jar failed: ' + error.message)
                                CookieJarSettings.apply({
                                  comCookie: '',
                                  coCookie: '',
                                  updatedAt: 0,
                                })
                              })
                              .finally(() => {
                                AutoDailyCheckinSettings.load(this.context)
                                  .catch((error: Error) => {
                                    console.error('restore auto daily check-in setting failed: ' + error.message)
                                    AutoDailyCheckinSettings.apply(true)
                                  })
                                  .finally(() => {
                                    AutoDailyCheckinService.tryCheckin(
                                      this.context,
                                      CookieJarSettings.getCurrentCookie(),
                                      'startup',
                                    ).catch((error: Error) => {
                                      console.info('auto daily check-in startup trigger failed: ' + error.message)
                                    })
                                    ReplyCardStyleSettings.load(this.context)
                                      .catch((error: Error) => {
                                        console.error(
                                          'restore reply card style failed: ' + error.message,
                                        )
                                        ReplyCardStyleSettings.apply(
                                          ReplyCardStyleSettings.STYLE_STANDARD,
                                        )
                                      })
                                      .finally(() => {
                                        ReplyActionAlignmentSettings.load(this.context)
                                          .catch((error: Error) => {
                                            console.error(
                                              'restore reply action alignment failed: ' + error.message,
                                            )
                                            ReplyActionAlignmentSettings.apply(
                                              ReplyActionAlignmentSettings.MODE_UNSET,
                                            )
                                          })
                                          .finally(() => {
                                            this.loadContent(windowStage, win)
                                          })
                                      })
                                  })
                              })
                          })
                      })
                  })
              })
          })
      })
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    ThemeSettings.refreshEffectiveDark(this.context, newConfig.colorMode)
  }

  private loadContent(windowStage: window.WindowStage, win: window.Window | null): void {
    windowStage.loadContent(ENTRY_PAGE, (err) => {
      if (err.code) {
        console.error('loadContent failed: ' + JSON.stringify(err))
      }
      try {
        if (!win) {
          win = windowStage.getMainWindowSync()
          this.mainWindow = win
        }
        let systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
        let navArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
        let uiCtx = windowStage.getMainWindowSync().getUIContext()
        AppStorage.setOrCreate<number>(
          StorageKeys.TOP_AVOID_HEIGHT,
          uiCtx.px2vp(systemArea.topRect.height),
        )
        AppStorage.setOrCreate<number>(
          StorageKeys.BOTTOM_AVOID_HEIGHT,
          uiCtx.px2vp(navArea.bottomRect.height),
        )
        AppStorage.setOrCreate<number>(StorageKeys.KEYBOARD_HEIGHT, 0)
        this.watchKeyboardHeight(win, uiCtx)
      } catch (e) {
        AppStorage.setOrCreate<number>(StorageKeys.TOP_AVOID_HEIGHT, FALLBACK_TOP_AVOID)
        AppStorage.setOrCreate<number>(StorageKeys.BOTTOM_AVOID_HEIGHT, FALLBACK_BOTTOM_AVOID)
        AppStorage.setOrCreate<number>(StorageKeys.KEYBOARD_HEIGHT, 0)
      }
    })
  }

  private captureIncomingUrl(want: Want): void {
    const uri = (want?.uri || '').trim()
    if (!uri || !V2exUrlRouter.parse(uri)) {
      return
    }
    AppStorage.setOrCreate<string>(StorageKeys.PENDING_V2EX_URL, `${Date.now()}:${uri}`)
  }

  private async configureWideGamut(win: window.Window): Promise<void> {
    try {
      const supported = await win.isWindowSupportWideGamut()
      if (!supported) {
        console.info('wide gamut window color space is not supported')
        return
      }
      await win.setWindowColorSpace(window.ColorSpace.WIDE_GAMUT)
      console.info('wide gamut window color space enabled')
    } catch (error) {
      const e = error as Error
      console.error('configure wide gamut failed: ' + e.message)
    }
  }

  private watchKeyboardHeight(win: window.Window, uiCtx: UIContext): void {
    if (this.keyboardHeightCallback) {
      try {
        win.off('keyboardHeightChange', this.keyboardHeightCallback)
      } catch (error) {
        const e = error as Error
        console.error('remove keyboard height listener failed: ' + e.message)
      }
    }
    this.keyboardHeightCallback = (height: number) => {
      AppStorage.setOrCreate<number>(StorageKeys.KEYBOARD_HEIGHT, uiCtx.px2vp(Math.max(0, height)))
    }
    try {
      win.on('keyboardHeightChange', this.keyboardHeightCallback)
    } catch (error) {
      const e = error as Error
      console.error('watch keyboard height failed: ' + e.message)
    }
  }

  onDestroy(): void {
    if (this.mainWindow && this.keyboardHeightCallback) {
      try {
        this.mainWindow.off('keyboardHeightChange', this.keyboardHeightCallback)
      } catch (error) {
        const e = error as Error
        console.error('remove keyboard height listener failed: ' + e.message)
      }
    }
  }
}
