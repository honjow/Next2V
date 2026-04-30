import { V2exTopic, TopicCard, LoadingFooter, ThemeConstants } from 'shared'
import { FeedViewModel } from '../viewmodel/FeedViewModel'

@Component
export struct FeedList {
  @Prop viewModel: FeedViewModel
  onTopicClick: (topic: V2exTopic) => void = () => {}

  build() {
    // 错误提示
    if (this.viewModel.errorMessage && this.viewModel.dataSource.totalCount() === 0) {
      Column() {
        Text(this.viewModel.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_secondary'))
        Button('重试')
          .margin({ top: ThemeConstants.SPACE_LG })
          .onClick(() => this.viewModel.loadData())
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height('80%')
    } else {
      Refresh({ refreshing: $$this.viewModel.isRefreshing }) {
        List({ space: ThemeConstants.SPACE_XS }) {
          LazyForEach(this.viewModel.dataSource, (item: V2exTopic, index: number) => {
            ListItem() {
              TopicCard({ item: item })
                .onClick(() => this.onTopicClick(item))
            }
          }, (item: V2exTopic) => item.id.toString())

          ListItem() {
            LoadingFooter({
              isLoading: this.viewModel.isLoading,
              hasMore: this.viewModel.hasMore
            })
          }
        }
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .onReachEnd(() => {
          // V1 API 不支持分页，触底暂不加载更多
          // 后续改用加载节点下的主题
        })
        .width('100%')
        .height('100%')
      }
      .onRefreshing(() => this.viewModel.refresh())
    }
  }
}
