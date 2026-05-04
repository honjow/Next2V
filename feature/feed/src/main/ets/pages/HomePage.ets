import { FeedViewModel } from '../viewmodel/FeedViewModel'
import {
  V2exTopic, TopicCard, LoadingFooter, TopicDetailParams, ThemeConstants,
  StorageKeys, PullRefresh, ApiConstants, TabItem
} from 'shared'

@Component
export struct HomePage {
  @Consume('ns') ns: NavPathStack
  @State vm: FeedViewModel = new FeedViewModel()
  @StorageProp('topAvoidHeight') topH: number = 107
  @StorageProp('bottomAvoidHeight') bottomH: number = 0
  private readonly USE_SYSTEM_REFRESH: boolean = false
  private readonly TBH: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly FLOAT_H: number = ThemeConstants.FLOAT_BAR_HEIGHT
  private readonly GAP: number = ThemeConstants.SPACE_SM
  private readonly PULL_THRESHOLD: number = 40
  private readonly TAB_BAR_HEIGHT: number = ApiConstants.TAB_BAR_HEIGHT
  private scroller: Scroller = new Scroller()
  @State listScrollEnabled: boolean = true

  aboutToAppear(): void { this.vm.switchTab(this.vm.activeTab) }

  @Builder TabBar() {
    Scroll() {
      Row({ space: ThemeConstants.SPACE_XS }) {
        ForEach(ApiConstants.TAB_ITEMS, (tab: TabItem) => {
          Column({ space: 2 }) {
            Text(tab.label)
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(
                this.vm.activeTab === tab.key
                  ? ThemeConstants.BRAND_PRIMARY
                  : ThemeConstants.TEXT_SECONDARY
              )
              .fontWeight(
                this.vm.activeTab === tab.key ? FontWeight.Medium : FontWeight.Regular
              )
              .padding({
                left: ThemeConstants.SPACE_MD,
                right: ThemeConstants.SPACE_MD,
                top: ThemeConstants.SPACE_SM
              })
            if (this.vm.activeTab === tab.key) {
              Divider()
                .strokeWidth(2)
                .color(ThemeConstants.BRAND_PRIMARY)
                .width(18)
            }
          }
          .alignItems(HorizontalAlign.Center)
          .padding({ bottom: ThemeConstants.SPACE_XS })
          .onClick(() => { this.vm.switchTab(tab.key) })
        })
      }
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
    }
    .scrollBar(BarState.Off)
    .scrollable(ScrollDirection.Horizontal)
    .width('100%')
  }

  build() {
    Column() {
      // TabBar 区域（固定，title bar 下方）
      Column() {
        Blank().height(this.topH + this.TBH)  // title bar + 状态栏后方透明占位
        this.TabBar()
      }
      .width('100%')
      .height(this.topH + this.TBH + this.TAB_BAR_HEIGHT)
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))

      if (this.vm.dataSource.totalCount() > 0) {
        if (this.USE_SYSTEM_REFRESH) {
          Column() {
            Refresh({ refreshing: $$this.vm.isRefreshing }) {
              List({ space: this.GAP, scroller: this.scroller }) {
                ListItem() { Column() { Blank() } }
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
            .onRefreshing(async () => {
              await this.vm.refreshForce()
            })
          }
          .layoutWeight(1).width('100%')
        } else {
          Column() {
            PullRefresh({
              scroller: this.scroller,
              indicatorTop: this.TBH,
              threshold: this.PULL_THRESHOLD,
              onRefresh: async () => { await this.vm.refresh() },
              onScrollEnableChange: (enabled: boolean) => { this.listScrollEnabled = enabled }
            }) {
              List({ space: this.GAP, scroller: this.scroller }) {
                ListItem() { Column() { Blank() } }
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
          .layoutWeight(1).width('100%')
        }
      } else {
        Column() {
          LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE)
          Text(this.vm.errorMessage ? this.vm.errorMessage : '加载中...')
            .fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_SM })
          if (this.vm.errorMessage) Button('重试')
            .margin({ top: ThemeConstants.SPACE_LG })
            .onClick(() => this.vm.switchTab(this.vm.activeTab))
        }.justifyContent(FlexAlign.Center).layoutWeight(1).width('100%')
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
