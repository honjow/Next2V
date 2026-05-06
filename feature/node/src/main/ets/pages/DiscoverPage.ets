import { NodeViewModel } from '../viewmodel/NodeViewModel'
import {
  ApiService, V2exNode, V2exTopic, NodeTopicListParams, TopicDetailParams, ThemeConstants
} from 'shared'

@Component
export struct DiscoverPage {
  @Consume('ns') ns: NavPathStack
  @State vm: NodeViewModel = new NodeViewModel()
  @State private hotTopics: V2exTopic[] = []
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
    this.loadHotTopics()
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
      Row() {
        Text('今日热议')
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Button('刷新')
          .type(ButtonType.Normal)
          .height(32)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .enabled(!this.isHotLoading)
          .onClick(() => { this.loadHotTopics() })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.isHotLoading && this.hotTopics.length === 0) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE)
          .height(ThemeConstants.LOADING_SIZE)
          .margin({ top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_MD })
      } else if (this.hotError && this.hotTopics.length === 0) {
        Text(this.hotError)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .padding(ThemeConstants.SPACE_MD)
          .width('100%')
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      } else {
        ForEach(this.hotTopics.slice(0, 6), (topic: V2exTopic) => {
          this.HotTopicRow(topic)
        }, (topic: V2exTopic) => `hot-${topic.id}`)
      }
    }
    .width('100%')
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

  private loadHotTopics(): void {
    if (this.isHotLoading) {
      return
    }
    this.isHotLoading = true
    this.hotError = ''
    this.api.getHotTopics()
      .then((topics: V2exTopic[]) => {
        this.hotTopics = topics || []
      })
      .catch((error: Error) => {
        this.hotError = error.message || '热议加载失败'
      })
      .finally(() => {
        this.isHotLoading = false
      })
  }
}
