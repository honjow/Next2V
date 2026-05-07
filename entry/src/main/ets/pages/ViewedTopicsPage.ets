import { common } from '@kit.AbilityKit'
import {
  CollectionSettings,
  DateUtils,
  EmptyState,
  SecondaryListScaffold,
  ThemeConstants,
  type TopicDetailParams,
  type ViewedTopic
} from 'shared'

@Component
export struct ViewedTopicsPage {
  @Consume('ns') stack: NavPathStack
  @State private topics: ViewedTopic[] = []

  aboutToAppear(): void {
    this.loadTopics()
  }

  build() {
    SecondaryListScaffold() {
      if (this.topics.length === 0) {
        ListItem() {
          EmptyState({ message: '还没有最近浏览记录', stateHeight: 220 })
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
      } else {
        ForEach(this.topics, (item: ViewedTopic) => {
          ListItem() {
            ViewedTopicRow({
              title: item.title,
              nodeTitle: item.nodeTitle,
              nodeName: item.nodeName,
              username: item.username,
              timestamp: item.viewedAt
            })
          }
          .onClick(() => {
            let p: TopicDetailParams = { topicId: item.id }
            this.stack.pushPathByName('TopicDetail', p as Object)
          })
        }, (item: ViewedTopic) => `viewed-${item.id}`)
      }
    }
  }

  private loadTopics(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadViewedTopics(context)
      .then((items: ViewedTopic[]) => {
        this.topics = items
      })
      .catch((error: Error) => {
        console.error('load viewed topics failed: ' + error.message)
      })
  }
}

@Component
struct ViewedTopicRow {
  @Prop title: string
  @Prop nodeTitle: string
  @Prop nodeName: string
  @Prop username: string
  @Prop timestamp: number

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(this.nodeTitle || this.nodeName)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.ohos_id_color_activated'))
          .padding({
            left: ThemeConstants.SPACE_SM,
            right: ThemeConstants.SPACE_SM,
            top: 2,
            bottom: 2
          })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        Text(this.username)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`浏览于 ${DateUtils.toDateString(this.timestamp)}`)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
