import { webview } from '@kit.ArkWeb'

@Component
export struct V2exWebView {
  controller: webview.WebviewController = new webview.WebviewController()
  onControllerAttached?: () => void
  onPageBegin?: (event?: OnPageBeginEvent) => void
  onPageEnd?: (event?: OnPageEndEvent) => void
  onLoadFinished?: (event?: OnLoadFinishedEvent) => void
  onErrorReceive?: (event: OnErrorReceiveEvent) => void

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
