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
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) { console.error('loadContent failed: ' + JSON.stringify(err)) }
    })
  }

  onDestroy(): void {}
}
