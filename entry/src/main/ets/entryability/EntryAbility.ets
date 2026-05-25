import { UIAbility, Want, AbilityConstant, EnvironmentCallback } from '@kit.AbilityKit'
import { Configuration } from '@ohos.app.ability.Configuration'
import { window } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import {
  AppStrings,
  DiagnosticLogger,
  FoldScreenUtil,
  LanguageSettings,
  SettingsBootstrap,
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
  private environmentCallbackId: number = -1

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // Must snapshot the real system colorMode into AppStorage BEFORE any
    // setColorMode or SettingsBootstrap, otherwise the app override masks
    // the real system value (auto mode detection breaks).
    ThemeSettings.seedSystemColorMode(this.context)
    AppStrings.init(this.context)
    LanguageSettings.applyStoredPreferredLanguage(this.context).catch((error: Error) => {
      console.error('restore preferred app language failed: ' + error.message)
      LanguageSettings.apply(LanguageSettings.MODE_SYSTEM)
    })
    DiagnosticLogger.initializePersistentSink(this.context)
    DiagnosticLogger.info('app', 'diagnostics_session_start', { source: 'EntryAbility.onCreate' })
    try {
      webview.WebviewController.initializeWebEngine()
    } catch (error) {
      const e = error as Error
      console.error('initialize web engine failed: ' + e.message)
    }
    this.captureIncomingUrl(want)

    // Initialize foldable screen state listener
    FoldScreenUtil.getInstance().init()

    // Register application-level Environment callback for follow-system
    // language/colorMode changes. This callback path is outside the
    // Configuration rebuild call chain, so calling set APIs is safe.
    try {
      const ctx = this.context
      const envCallback: EnvironmentCallback = {
        onConfigurationUpdated: (config: Configuration) => {
          LanguageSettings.reapplyForFollowSystem()
          ThemeSettings.reapplyForFollowSystem(ctx, config.colorMode)
        },
        onMemoryLevel: (_: AbilityConstant.MemoryLevel) => {},
      }
      this.environmentCallbackId = ctx.getApplicationContext().on('environment', envCallback)
    } catch (error) {
      const e = error as Error
      console.error('register environment callback failed: ' + e.message)
    }
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
    SettingsBootstrap.loadAll(this.context).finally(() => {
      this.loadContent(windowStage, win)
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
    DiagnosticLogger.info('app', 'diagnostics_session_end', { source: 'EntryAbility.onDestroy' })
    if (this.environmentCallbackId !== -1) {
      try {
        this.context.getApplicationContext().off('environment', this.environmentCallbackId)
      } catch (error) {
        const e = error as Error
        console.error('unregister environment callback failed: ' + e.message)
      }
      this.environmentCallbackId = -1
    }
    if (this.mainWindow && this.keyboardHeightCallback) {
      try {
        this.mainWindow.off('keyboardHeightChange', this.keyboardHeightCallback)
      } catch (error) {
        const e = error as Error
        console.error('remove keyboard height listener failed: ' + e.message)
      }
    }
    DiagnosticLogger.closePersistentSink()
  }
}
