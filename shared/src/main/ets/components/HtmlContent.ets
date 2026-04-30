import { webview } from '@kit.ArkWeb'

/**
 * HTML 内容渲染组件
 * 将 V2EX 返回的 content_rendered（HTML）以 Web 组件渲染
 */
@Component
export struct HtmlContent {
  @Prop html: string = ''
  @Prop maxHeight: number = -1
  controller: webview.WebviewController = new webview.WebviewController()

  build() {
    Web({ src: this.html, controller: this.controller })
      .width('100%')
      .height(this.maxHeight > 0 ? this.maxHeight : 'auto')
      .darkMode(WebDarkMode.Auto)
      .padding(0)
      .margin(0)
  }
}
