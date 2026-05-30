import { webview } from '@kit.ArkWeb'

@ComponentV2
export struct V2exWebView {
  @Param controller: webview.WebviewController = new webview.WebviewController()
  @Event onControllerAttached?: () => void
  @Event onPageBegin?: (event?: OnPageBeginEvent) => void
  @Event onPageEnd?: (event?: OnPageEndEvent) => void
  @Event onLoadFinished?: (event?: OnLoadFinishedEvent) => void
  @Event onErrorReceive?: (event: OnErrorReceiveEvent) => void

  build() {
    ListItem() {
      Web({ src: '', controller: this.controller })
        .nestedScroll({
          scrollUp: NestedScrollMode.PARENT_FIRST,
          scrollDown: NestedScrollMode.PARENT_FIRST,
        })
        .overScrollMode(OverScrollMode.NEVER)
        .darkMode(WebDarkMode.Off)
        .backgroundColor(Color.White)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onlineImageAccess(true)
        .width('100%')
        .height('100%')
        .onControllerAttached(() => {
          if (this.onControllerAttached) {
            this.onControllerAttached()
          }
        })
        .onPageBegin((event: OnPageBeginEvent) => {
          if (this.onPageBegin) {
            this.onPageBegin(event)
          }
        })
        .onPageEnd((event: OnPageEndEvent) => {
          if (this.onPageEnd) {
            this.onPageEnd(event)
          }
        })
        .onLoadFinished((event: OnLoadFinishedEvent) => {
          if (this.onLoadFinished) {
            this.onLoadFinished(event)
          }
        })
        .onErrorReceive((event: OnErrorReceiveEvent) => {
          if (this.onErrorReceive) {
            this.onErrorReceive(event)
          }
        })
    }
    .height('100%')
    .clip(false)
  }
}
