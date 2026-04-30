import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {}

  /**
   * 窗口初始化：
   * - setWindowLayoutFullScreen(true)：窗口全屏，内容可延伸至系统栏后方
   * - 状态栏/导航栏透明：视觉上融入 HdsNavigation 的沉浸光感
   * - 顶部安全区由系统自动留出（不使用 expandSafeArea(TOP)）
   * - 底部由 Index.ets 中 expandSafeArea(BOTTOM) 控制延伸至手势条下方
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    let win = windowStage.getMainWindowSync()
    win.setWindowLayoutFullScreen(true)
    win.setWindowSystemBarProperties({
      statusBarColor: '#00FFFFFF',
      navigationBarColor: '#00FFFFFF'
    })
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) { console.error('loadContent failed: ' + JSON.stringify(err)) }
    })
  }

  onDestroy(): void {}
}
