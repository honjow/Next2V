import { webview } from '@kit.ArkWeb'

/**
 * HTML content rendering component
 * Renders V2EX content_rendered (HTML) via Web component
 */
@ComponentV2
export struct HtmlContent {
  @Param html: string = ''
  @Param maxHeight: number = -1
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
