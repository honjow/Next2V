import { UserViewModel } from '../viewmodel/UserViewModel'
import {
  V2exTopic, TopicCard, ThemeConstants, TopicDetailParams
} from 'shared'

@Component
export struct UserProfilePage {
  @Prop username: string = ''
  @Consume('ns') stack: NavPathStack
  @State vm: UserViewModel = new UserViewModel(this.username)
  @StorageProp('topAvoidHeight') topH: number = 107

  aboutToAppear(): void { this.vm.load() }

  build() {
    Column() {
      if (this.vm.isLoading && this.vm.profile === null) {
        LoadingProgress().width(32).height(32).margin({ top: 100 })
      } else if (this.vm.profile !== null) {
        List({ space: ThemeConstants.SPACE_XS }) {
          ListItem() { Column() { Blank().height(this.topH + 56) } }
          ListItem() {
            Column() {
              Text(this.vm.profile!.username).fontSize(20).fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
              if (this.vm.profile!.bio)
                Text(this.vm.profile!.bio).fontSize(14).fontColor($r('sys.color.font_secondary')).margin({ top: 12 })
            }.padding(16).width('100%').alignItems(HorizontalAlign.Center)
          }
          ListItem() { Text('最近主题').fontSize(14).fontColor($r('sys.color.font_secondary')).padding(8) }
          LazyForEach(this.vm.topicDataSource, (topic: V2exTopic) => {
            ListItem() { TopicCard({ item: topic }) }
              .onClick(() => {
                let p: TopicDetailParams = { topicId: topic.id }
                this.stack.pushPathByName('TopicDetail', p as Object)
              })
          }, (topic: V2exTopic) => topic.id.toString())
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
