import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  CollectionSettings,
  ConciseListRow,
  CookieJarSettings,
  EmptyState,
  GroupedListSection,
  SecondaryListScaffold,
  ThemeConstants,
  type NodeTopicListParams,
  type V2exFavoriteNode,
  type V2exNode
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
      if (!CookieJarSettings.getCurrentCookie()) {
        this.LoginRequiredView()
      } else if (this.isLoading && this.nodes.length === 0) {
        this.LoadingView()
      } else if (this.errorMessage && this.nodes.length === 0) {
        this.ErrorView()
      } else if (this.nodes.length === 0) {
        this.EmptyView()
      } else {
        SecondaryListScaffold() {
          ForEach(this.nodes, (item: V2exFavoriteNode) => {
            ListItem() {
              GroupedListSection() {
                ConciseListRow({
                  title: item.title || item.name,
                  subtitle: this.nodeSubtitle(item),
                  leadingImageUrl: this.nodeIcon(item),
                  action: () => { this.openNode(item) }
                })
              }
            }
              .onClick(() => { this.openNode(item) })
          }, (item: V2exFavoriteNode) => `my-node-${item.name}`)
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
    .layoutWeight(1)
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
    .layoutWeight(1)
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
    .layoutWeight(1)
  }

  @Builder private EmptyView() {
    Column() {
      EmptyState({ message: '还没有收藏节点' })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(1)
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
        this.loadNodesWithIcons(nodes, () => {
          this.isLoading = false
          if (!force && this.errorMessage) {
            promptAction.openToast({ message: this.errorMessage }).catch((_error: Error) => { })
          }
        })
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '加载失败'
        this.nodes = []
        this.isLoading = false
        if (!force && this.errorMessage) {
          promptAction.openToast({ message: this.errorMessage }).catch((_error: Error) => { })
        }
      })
  }

  private openNode(item: V2exFavoriteNode): void {
    const p: NodeTopicListParams = { nodeName: item.name, nodeTitle: item.title || item.name }
    this.stack.pushPathByName('NodeTopicList', p as Object)
  }

  private nodeSubtitle(item: V2exFavoriteNode): string {
    const parts: string[] = [item.name]
    if ((item.topics || 0) > 0) {
      parts.push(`${item.topics} 个主题`)
    }
    return parts.join(' · ')
  }

  private nodeIcon(item: V2exFavoriteNode): string {
    return item.avatarNormal || item.avatarMini || item.avatarLarge || ''
  }

  private loadNodesWithIcons(favorites: V2exFavoriteNode[], onDone: () => void): void {
    // 所有节点都已有 icon，直接赋值
    if (favorites.every((item: V2exFavoriteNode) => this.nodeIcon(item))) {
      this.nodes = favorites
      onDone()
      return
    }
    // 部分节点缺 icon，先拉全量节点数据，合并后再赋值
    this.api.getAllNodes()
      .then((allNodes: V2exNode[]) => {
        const nodeByName: Record<string, V2exNode> = {}
        allNodes.forEach((node: V2exNode) => {
          nodeByName[node.name] = node
        })
        this.nodes = favorites.map((node: V2exFavoriteNode) => {
          const detail = nodeByName[node.name]
          if (!detail) {
            return node
          }
          return {
            name: node.name,
            title: CollectionSettings.cleanNodeTitle(
              detail.title || node.title, detail.topics || node.topics || 0),
            topics: detail.topics || node.topics,
            avatarMini: node.avatarMini || detail.avatar_mini,
            avatarNormal: node.avatarNormal || detail.avatar_normal,
            avatarLarge: node.avatarLarge || detail.avatar_large
          }
        })
      })
      .catch((error: Error) => {
        console.error('enrich favorite node icons failed: ' + error.message)
        // 降级：用不带 icon 的数据
        this.nodes = favorites
      })
      .finally(() => {
        onDone()
      })
  }
}
