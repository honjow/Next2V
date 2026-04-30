import { UserViewModel } from '../viewmodel/UserViewModel'
import {
  V2exTopic, TopicCard, ThemeConstants, TopicDetailParams, StorageKeys
} from 'shared'

@Component
export struct UserProfilePage {
  @Prop username: string = ''
  @Consume(StorageKeys.NAV_PATH_STACK) stack: NavPathStack
  @State vm: UserViewModel = new UserViewModel(this.username)
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0

  aboutToAppear(): void { this.vm.load() }

  build() {
    Column() {
      if (this.vm.isLoading && this.vm.profile === null) {
        LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE).margin({ top: ThemeConstants.MARGIN_LOADING_TOP })
      } else if (this.vm.profile !== null) {
        List({ space: ThemeConstants.SPACE_XS }) {
          ListItem() { Column() { Blank().height(this.topH + ThemeConstants.TITLE_BAR_HEIGHT) } }
          ListItem() {
            Column() {
              Text(this.vm.profile!.username).fontSize(ThemeConstants.FONT_SIZE_HEADING + 2).fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
              if (this.vm.profile!.bio)
                Text(this.vm.profile!.bio).fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_MD })
            }.padding(ThemeConstants.SPACE_LG).width('100%').alignItems(HorizontalAlign.Center)
          }
          ListItem() { Text('最近主题').fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_secondary')).padding(ThemeConstants.SPACE_SM) }
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
        Text('加载失败').fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.MARGIN_LOADING_TOP })
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
