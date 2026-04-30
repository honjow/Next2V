import { FeedViewModel } from '../viewmodel/FeedViewModel'
import {
  V2exTopic, TopicCard, LoadingFooter, TopicDetailParams
} from 'shared'
import { PullRefresh } from '../components/PullRefresh'

@Component
export struct HomePage {
  @Consume('ns') ns: NavPathStack
  @State vm: FeedViewModel = new FeedViewModel()
  @StorageProp('topAvoidHeight') topH: number = 107
  @StorageProp('bottomAvoidHeight') bottomH: number = 0
  // 🔧 Feature Flag: true=系统Refresh, false=自定义PullRefresh
  private readonly USE_SYSTEM_REFRESH: boolean = false
  private readonly TBH: number = 56
  private readonly FLOAT_H: number = 76
  private readonly GAP: number = 8
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void { this.vm.loadData() }

  build() {
    Column() {
      if (this.vm.dataSource.totalCount() > 0) {
        if (this.USE_SYSTEM_REFRESH) {
          // --- 系统 Refresh 组件 ---
          Refresh({ refreshing: $$this.vm.isRefreshing }) {
            List({ space: this.GAP, scroller: this.scroller }) {
              ListItem() { Column() { Blank().height(this.topH + this.TBH) } }
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
        } else {
          // --- 自定义 PullRefresh 组件 ---
          PullRefresh({
            scroller: this.scroller,
            indicatorTop: this.topH + this.TBH,
            threshold: 40,
            onRefresh: async () => { await this.vm.refresh() }
          }) {
            List({ space: this.GAP, scroller: this.scroller }) {
              ListItem() { Column() { Blank().height(this.topH + this.TBH) } }
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
        }
      } else {
        Column() {
          LoadingProgress().width(32).height(32)
          Text(this.vm.errorMessage ? '加载失败' : '加载中...')
            .fontSize(14).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
          if (this.vm.errorMessage) Button('重试')
            .margin({ top: 16 })
            .onClick(() => this.vm.loadData())
        }.justifyContent(FlexAlign.Center).width('100%').height('100%')
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
