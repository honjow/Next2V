import { FeedViewModel } from '../viewmodel/FeedViewModel'
import {
  V2exTopic, TopicCard, LoadingFooter, TopicDetailParams
} from 'shared'

@Component
export struct HomePage {
  @Consume('ns') ns: NavPathStack
  @State vm: FeedViewModel = new FeedViewModel()
  @StorageProp('topAvoidHeight') topH: number = 107
  @StorageProp('bottomAvoidHeight') bottomH: number = 0
  private readonly TBH: number = 56
  private readonly FLOAT_H: number = 76
  private readonly GAP: number = 8

  aboutToAppear(): void { this.vm.loadData() }

  build() {
    Column() {
      if (this.vm.dataSource.totalCount() > 0) {
        Refresh({ refreshing: $$this.vm.isRefreshing, builder: this.RefreshBuilder }) {
          List({ space: this.GAP }) {
            ListItem() { Column() { Blank().height(this.topH + this.TBH) } }
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
        }.onRefreshing(() => this.vm.refresh())
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
  }

  /** 自定义刷新动画，顶部留白使其出现在 titleBar 下方 */
  @Builder RefreshBuilder() {
    Column() {
      Blank().height(this.topH + this.TBH)
      LoadingProgress()
        .width(32).height(32)
        .color($r('sys.color.ohos_id_color_activated'))
    }
      .justifyContent(FlexAlign.Center)
      .width('100%')
  }
}
