import { FeedViewModel } from '../viewmodel/FeedViewModel'
import {
  V2exTopic, TopicCard, LoadingFooter, TopicDetailParams, ThemeConstants,
  StorageKeys, PullRefresh, ApiConstants
} from 'shared'

@Component
export struct HomePage {
  @Consume('ns') ns: NavPathStack
  @StorageProp('feedTab') @Watch('onFeedTabChange') feedTab: string = 'tech'
  @State vm: FeedViewModel = new FeedViewModel()
  @StorageProp('topAvoidHeight') topH: number = 107
  @StorageProp('bottomAvoidHeight') bottomH: number = 0
  private readonly USE_SYSTEM_REFRESH: boolean = false
  private readonly TBH: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly FLOAT_H: number = ThemeConstants.FLOAT_BAR_HEIGHT
  private readonly GAP: number = ThemeConstants.SPACE_SM
  private readonly PULL_THRESHOLD: number = 40
  private readonly BB_H: number = ApiConstants.TAB_BAR_HEIGHT
  private scroller: Scroller = new Scroller()
  @State listScrollEnabled: boolean = true
  private _ready: boolean = false

  aboutToAppear(): void {
    this.vm.switchTab(this.feedTab)
    this._ready = true
  }

  onFeedTabChange(): void {
    if (this._ready) { this.vm.switchTab(this.feedTab) }
  }

  build() {
    Column() {
      if (this.vm.dataSource.totalCount() > 0) {
        if (this.USE_SYSTEM_REFRESH) {
          Refresh({ refreshing: $$this.vm.isRefreshing }) {
            List({ space: this.GAP, scroller: this.scroller }) {
              ListItem() { Column() { Blank().height(this.topH + this.TBH + this.BB_H) } }
                .clip(false)
              LazyForEach(this.vm.dataSource, (item: V2exTopic) => {
                ListItem() { TopicCard({ item: item }) }
                  .onClick(() => {
                    let p: TopicDetailParams = { topicId: item.id }
                    this.ns.pushPathByName('TopicDetail', p as Object)
                  })
              }, (item: V2exTopic) => item.id.toString())
              ListItem() { Column() { Blank().height(this.bottomH + this.FLOAT_H) } }
            }
            .scrollBar(BarState.Off)
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
            .width('100%').height('100%')
            .padding({ left: this.GAP, right: this.GAP })
            .clip(false)
            .edgeEffect(EdgeEffect.None)
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
          }
          .onRefreshing(async () => { await this.vm.refreshForce() })
        } else {
          PullRefresh({
            scroller: this.scroller,
            indicatorTop: this.TBH + this.BB_H,
            threshold: this.PULL_THRESHOLD,
            onRefresh: async () => { await this.vm.refresh() },
            onScrollEnableChange: (enabled: boolean) => { this.listScrollEnabled = enabled }
          }) {
            List({ space: this.GAP, scroller: this.scroller }) {
              ListItem() { Column() { Blank().height(this.topH + this.TBH + this.BB_H) } }
                .clip(false)
              LazyForEach(this.vm.dataSource, (item: V2exTopic) => {
                ListItem() { TopicCard({ item: item }) }
                  .onClick(() => {
                    let p: TopicDetailParams = { topicId: item.id }
                    this.ns.pushPathByName('TopicDetail', p as Object)
                  })
              }, (item: V2exTopic) => item.id.toString())
              ListItem() { Column() { Blank().height(this.bottomH + this.FLOAT_H) } }
            }
            .enableScrollInteraction(this.listScrollEnabled)
            .scrollBar(BarState.Off)
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
            .width('100%').height('100%')
            .padding({ left: this.GAP, right: this.GAP })
            .clip(false)
            .edgeEffect(EdgeEffect.None)
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
          }
        }
      } else {
        Column() {
          LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE)
          Text(this.vm.errorMessage ? this.vm.errorMessage : '加载中...')
            .fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_SM })
          if (this.vm.errorMessage) Button('重试')
            .margin({ top: ThemeConstants.SPACE_LG })
            .onClick(() => this.vm.switchTab(this.vm.activeTab))
        }.justifyContent(FlexAlign.Center).width('100%').height('100%')
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
