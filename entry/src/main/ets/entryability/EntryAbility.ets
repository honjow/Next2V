import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {}

  onWindowStageCreate(windowStage: window.WindowStage): void {
    let win = windowStage.getMainWindowSync()
    win.setWindowLayoutFullScreen(true)
    win.setWindowSystemBarProperties({
      statusBarColor: '#00FFFFFF',
      navigationBarColor: '#00FFFFFF'
    })
    // 获取系统安全区高度（px → vp）
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) { console.error('loadContent failed: ' + JSON.stringify(err)) }
      // 页面加载后获取安全区高度
      try {
        let systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
        let navArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
        let uiCtx = windowStage.getMainWindowSync().getUIContext()
        AppStorage.SetOrCreate<number>('topAvoidHeight', uiCtx.px2vp(systemArea.topRect.height))
        AppStorage.SetOrCreate<number>('bottomAvoidHeight', uiCtx.px2vp(navArea.bottomRect.height))
      } catch (e) {
        // 降级默认值
        AppStorage.SetOrCreate<number>('topAvoidHeight', 107)
        AppStorage.SetOrCreate<number>('bottomAvoidHeight', 0)
      }
    })
  }

  onDestroy(): void {}
}
