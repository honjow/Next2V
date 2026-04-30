import {
  V2exMemberProfile, V2exTopic, TopicCard,
  ThemeConstants, ApiService, TopicDetailParams
} from 'shared'

@Component
export struct UserProfilePage {
  @Prop username: string = ''
  @Consume('ns') stack: NavPathStack
  @StorageProp('topAvoidHeight') topH: number = 107
  @State profile: V2exMemberProfile | null = null
  @State topics: V2exTopic[] = []
  @State loading: boolean = false
  private api: ApiService = new ApiService()

  aboutToAppear(): void { this.load() }
  async load(): Promise<void> {
    this.loading = true
    try {
      this.profile = await this.api.getMember(this.username)
      this.topics = await this.api.getTopicsByUsername(this.username)
    } catch (e) {}
    this.loading = false
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingProgress().width(32).height(32).margin({ top: 100 })
      } else if (this.profile !== null) {
        List({ space: ThemeConstants.SPACE_XS }) {
          ListItem() { Column() { Blank().height(this.topH + 56) } }
          ListItem() {
            Column() {
              Text(this.profile!.username).fontSize(20).fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
              if (this.profile!.bio)
                Text(this.profile!.bio).fontSize(14).fontColor($r('sys.color.font_secondary')).margin({ top: 12 })
            }.padding(16).width('100%').alignItems(HorizontalAlign.Center)
          }
          ListItem() { Text('最近主题').fontSize(14).fontColor($r('sys.color.font_secondary')).padding(8) }
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
      } else {
        Text('加载失败').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({ top: 100 })
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
