import {
  V2exTopic,
  V2exMemberProfile,
  Avatar,
  UserName,
  TopicCard,
  DateUtils,
  ThemeConstants,
  TopicDetailParams
} from 'shared'
import { UserViewModel } from '../viewmodel/UserViewModel'

@Component
export struct UserProfilePage {
  @Prop username: string = ''
  @State viewModel: UserViewModel = new UserViewModel(this.username)
  @Consume('pageStack') pageStack: NavPathStack

  aboutToAppear(): void {
    this.viewModel.load()
  }

  build() {
    NavDestination() {
      if (this.viewModel.isLoading && !this.viewModel.profile) {
        Column() {
          LoadingProgress()
            .width(32).height(32)
          Text('加载用户信息...')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: ThemeConstants.SPACE_MD })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%').height('100%')
      } else {
        List({ space: ThemeConstants.SPACE_XS }) {
          ListItem() {
            ProfileSection({ profile: this.viewModel.profile! })
          }

          if (this.viewModel.topics.length > 0) {
            ListItem() {
              Text('最近主题')
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor($r('sys.color.font_secondary'))
                .padding({
                  left: ThemeConstants.SPACE_LG,
                  right: ThemeConstants.SPACE_LG,
                  top: ThemeConstants.SPACE_MD
                })
            }
          }

          ForEach(this.viewModel.topics, (topic: V2exTopic) => {
            ListItem() {
              TopicCard({ item: topic })
                .onClick(() => {
                  let p: TopicDetailParams = { topicId: topic.id }
                  this.pageStack.pushPathByName('TopicDetail', p)
                })
            }
          })
        }
        .width('100%').height('100%')
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      }
    }
    .hideTitleBar(false)
    .title(this.username)
  }
}

@Component
struct ProfileSection {
  @Prop profile: V2exMemberProfile

  build() {
    Column() {
      Avatar({ url: this.profile.avatar_large, avatarSize: 72 })

      Text(this.profile.username)
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor($r('sys.color.font_primary'))
        .fontWeight(FontWeight.Medium)
        .margin({ top: ThemeConstants.SPACE_MD })

      if (this.profile.tagline) {
        Text(this.profile.tagline)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_secondary'))
          .margin({ top: ThemeConstants.SPACE_XS })
      }

      if (this.profile.bio) {
        Text(this.profile.bio)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: ThemeConstants.SPACE_SM })
      }

      Row({ space: ThemeConstants.SPACE_MD }) {
        if (this.profile.github) {
          Text(`GitHub: ${this.profile.github}`)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
        if (this.profile.website) {
          Text(this.profile.website)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
        if (this.profile.location) {
          Text(this.profile.location)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .width('100%')
      .margin({ top: ThemeConstants.SPACE_MD })

      Text(`加入于 ${DateUtils.toDateString(this.profile.created)}`)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: ThemeConstants.SPACE_SM })
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
