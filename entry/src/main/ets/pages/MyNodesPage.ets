import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  CookieJarSettings,
  SecondaryListScaffold,
  ThemeConstants,
  type NodeTopicListParams,
  type V2exFavoriteNode
} from 'shared'

@Component
export struct MyNodesPage {
  @Consume('ns') stack: NavPathStack

  @State private nodes: V2exFavoriteNode[] = []
  @State private errorMessage: string = ''
  @State private isLoading: boolean = false

  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.refresh()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        if (!CookieJarSettings.getCurrentCookie()) {
          ListItem() { this.LoginRequiredView() }
        } else if (this.isLoading && this.nodes.length === 0) {
          ListItem() { this.LoadingView() }
        } else if (this.errorMessage && this.nodes.length === 0) {
          ListItem() { this.ErrorView() }
        } else {
          ForEach(this.nodes, (item: V2exFavoriteNode) => {
            ListItem() {
              this.NodeRow(item)
            }
              .onClick(() => {
                const p: NodeTopicListParams = { nodeName: item.name, nodeTitle: item.title }
                this.stack.pushPathByName('NodeTopicList', p as Object)
              })
          }, (item: V2exFavoriteNode) => `my-node-${item.name}`)

          if (this.nodes.length === 0) {
            ListItem() { this.EmptyView() }
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder private LoadingView() {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE)
        .height(ThemeConstants.LOADING_SIZE)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder private LoginRequiredView() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text('登录后可查看收藏节点')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('去登录')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .onClick(() => { this.stack.pushPathByName('V2exNativeLogin', null) })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder private ErrorView() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.errorMessage)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('重试')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .onClick(() => { this.refresh(true) })
        Button('去登录')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .onClick(() => { this.stack.pushPathByName('V2exNativeLogin', null) })
      }
      .justifyContent(FlexAlign.Center)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder private EmptyView() {
    Column() {
      Text('还没有收藏节点')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder private NodeRow(item: V2exFavoriteNode) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.title || item.name)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.name)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  private refresh(force: boolean = false): void {
    if (this.isLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.nodes = []
      this.errorMessage = ''
      return
    }
    this.isLoading = true
    this.errorMessage = ''
    this.api.getMyFavoriteNodesWithCookie(cookie)
      .then((nodes) => {
        this.nodes = nodes
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '加载失败'
        this.nodes = []
      })
      .finally(() => {
        this.isLoading = false
        if (!force && this.errorMessage) {
          promptAction.openToast({ message: this.errorMessage }).catch((_error: Error) => { })
        }
      })
  }
}

