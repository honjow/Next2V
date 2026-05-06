import { NodeViewModel } from '../viewmodel/NodeViewModel'
import {
  ApiService, V2exNode, V2exTopic, NodeTopicListParams, TopicDetailParams, ThemeConstants
} from 'shared'

type DiscoverTopicMode = 'hot' | 'latest'

@Component
export struct DiscoverPage {
  @Consume('ns') ns: NavPathStack
  @State vm: NodeViewModel = new NodeViewModel()
  @State private topicMode: DiscoverTopicMode = 'hot'
  @State private hotTopics: V2exTopic[] = []
  @State private latestTopics: V2exTopic[] = []
  @State private hotError: string = ''
  @State private isHotLoading: boolean = false
  @StorageProp('topAvoidHeight') topH: number = 0
  @StorageProp('bottomAvoidHeight') bottomH: number = 0
  private readonly TBH: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly FLOAT_H: number = ThemeConstants.FLOAT_BAR_HEIGHT
  private readonly GAP: number = ThemeConstants.SPACE_MD
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.vm.loadAllNodes()
    this.loadTopicSurface()
  }

  build() {
    Column() {
      if (this.vm.isLoading && this.vm.nodeDataSource.totalCount() === 0) {
        LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE)
      } else if (this.vm.errorMessage && this.vm.nodeDataSource.totalCount() === 0) {
        this.ErrorView()
      } else {
        this.SearchBar()
        Scroll() {
          Column({ space: ThemeConstants.SPACE_MD }) {
            this.HotTopicsSection()
            if (this.vm.nodeDataSource.totalCount() === 0) {
              this.EmptyView()
            } else {
              this.SectionTitle('节点')
              GridRow({ columns: { sm: 2, md: 4, lg: 6 }, gutter: { x: ThemeConstants.SPACE_SM, y: ThemeConstants.SPACE_SM } }) {
                LazyForEach(this.vm.nodeDataSource, (node: V2exNode) => {
                  GridCol({ span: { sm: 1, md: 2, lg: 2 } }) {
                    Column() {
                      Text(node.title).fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_primary')).maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(`${node.topics} 主题`).fontSize(ThemeConstants.FONT_SIZE_TINY).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_XS })
                    }
                      .alignItems(HorizontalAlign.Center).padding(ThemeConstants.SPACE_MD).width('100%').borderRadius(ThemeConstants.RADIUS_MD)
                      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
                      .onClick(() => {
                        let p: NodeTopicListParams = { nodeName: node.name, nodeTitle: node.title }
                        this.ns.pushPathByName('NodeTopicList', p as Object)
                      })
                  }
                }, (node: V2exNode) => node.id.toString())
              }
            }
          }
            .padding({
              left: this.GAP, right: this.GAP,
              bottom: this.bottomH + this.FLOAT_H
            })
            .width('100%')
        }
          .scrollBar(BarState.Off)
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder SearchBar() {
    Row() {
      TextInput({ placeholder: '搜索节点', text: this.vm.keyword })
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .height(44)
        .borderRadius(ThemeConstants.RADIUS_MD)
        .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        .onChange((value: string) => {
          this.vm.setNodeFilter(value)
        })
    }
    .width('100%')
    .padding({
      left: this.GAP,
      right: this.GAP,
      top: this.topH + this.TBH,
      bottom: this.GAP
    })
  }

  @Builder HotTopicsSection() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.TopicModeButton('hot', '热议')
        this.TopicModeButton('latest', '最新')
        Blank()
        Button('刷新')
          .type(ButtonType.Normal)
          .height(32)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .enabled(!this.isHotLoading)
          .onClick(() => { this.reloadTopicSurface() })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.topicMode === 'hot' ? '今日热议' : '最新主题')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')

      if (this.isHotLoading && this.topicSurfaceItems().length === 0) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE)
          .height(ThemeConstants.LOADING_SIZE)
          .margin({ top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_MD })
      } else if (this.hotError && this.topicSurfaceItems().length === 0) {
        Text(this.hotError)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .padding(ThemeConstants.SPACE_MD)
          .width('100%')
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      } else {
        ForEach(this.topicSurfaceItems().slice(0, 6), (topic: V2exTopic) => {
          this.HotTopicRow(topic)
        }, (topic: V2exTopic) => `${this.topicMode}-${topic.id}`)
      }
    }
    .width('100%')
  }

  @Builder TopicModeButton(mode: DiscoverTopicMode, label: string) {
    Button(label)
      .type(ButtonType.Normal)
      .height(32)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor(this.topicMode === mode ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_secondary'))
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor(this.topicMode === mode ? '#EAF2FF' : $r('sys.color.ohos_id_color_button_normal'))
      .onClick(() => { this.setTopicMode(mode) })
  }

  @Builder HotTopicRow(topic: V2exTopic) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(topic.title)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: ThemeConstants.SPACE_XS }) {
          Text(topic.node.title)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('·')
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
          Text(topic.member.username)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`${topic.replies}`)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 4, bottom: 4 })
        .borderRadius(ThemeConstants.RADIUS_SM)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .onClick(() => {
      let p: TopicDetailParams = { topicId: topic.id }
      this.ns.pushPathByName('TopicDetail', p as Object)
    })
  }

  @Builder SectionTitle(title: string) {
    Text(title)
      .fontSize(ThemeConstants.FONT_SIZE_TITLE)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .width('100%')
  }

  @Builder EmptyView() {
    Column() {
      Text('没有匹配的节点')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder ErrorView() {
    Column() {
      Text(this.vm.errorMessage)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.vm.loadAllNodes() })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ top: this.topH + this.TBH, bottom: this.bottomH + this.FLOAT_H })
  }

  private topicSurfaceItems(): V2exTopic[] {
    return this.topicMode === 'hot' ? this.hotTopics : this.latestTopics
  }

  private setTopicMode(mode: DiscoverTopicMode): void {
    if (this.topicMode === mode) {
      return
    }
    this.topicMode = mode
    this.loadTopicSurface()
  }

  private reloadTopicSurface(): void {
    if (this.topicMode === 'hot') {
      this.hotTopics = []
    } else {
      this.latestTopics = []
    }
    this.loadTopicSurface()
  }

  private loadTopicSurface(): void {
    if (this.isHotLoading) {
      return
    }
    if (this.topicSurfaceItems().length > 0) {
      return
    }
    this.isHotLoading = true
    this.hotError = ''
    const requestedMode = this.topicMode
    const request = requestedMode === 'hot' ? this.api.getHotTopics() : this.api.getLatestTopics()
    request
      .then((topics: V2exTopic[]) => {
        if (requestedMode === 'hot') {
          this.hotTopics = topics || []
        } else {
          this.latestTopics = topics || []
        }
      })
      .catch((error: Error) => {
        this.hotError = error.message || '主题加载失败'
      })
      .finally(() => {
        this.isHotLoading = false
        if (this.topicMode !== requestedMode && this.topicSurfaceItems().length === 0) {
          this.loadTopicSurface()
        }
      })
  }
}
