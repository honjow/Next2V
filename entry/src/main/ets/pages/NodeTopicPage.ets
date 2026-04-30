import {
  V2exTopic, TopicCard, ThemeConstants, ApiService, TopicDetailParams
} from 'shared'

@Component
export struct NodeTopicPage {
  @Prop nodeName: string = ''
  @Prop nodeTitle: string = ''
  @Consume('ns') stack: NavPathStack
  @StorageProp('topAvoidHeight') topH: number = 107
  @State topics: V2exTopic[] = []
  @State loading: boolean = false
  private api: ApiService = new ApiService()

  aboutToAppear(): void { this.load() }
  async load(): Promise<void> {
    this.loading = true
    try { this.topics = await this.api.getTopicsByNode(this.nodeName) } catch (e) {}
    this.loading = false
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingProgress().width(32).height(32).margin({ top: 100 })
      } else {
        List({ space: ThemeConstants.SPACE_XS }) {
          ListItem() { Column() { Blank().height(this.topH + 56) } }
          ForEach(this.topics, (topic: V2exTopic) => {
            ListItem() { TopicCard({ item: topic }) }
              .onClick(() => {
                let p: TopicDetailParams = { topicId: topic.id }
                this.stack.pushPathByName('TopicDetail', p as Object)
              })
          })
        }
          .scrollBar(BarState.Off)
          .width('100%').height('100%')
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
