import { UserViewModel } from '../viewmodel/UserViewModel'
import {
  V2exTopic, TopicCard, ThemeConstants, TopicDetailParams, StorageKeys, NodeTopicListParams,
  Avatar, DateUtils, SecondaryListScaffold
} from 'shared'
import type { TopicReadState } from 'shared'

@Component
export struct UserProfilePage {
  @Prop username: string = ''
  @Consume('ns') stack: NavPathStack
  @State vm: UserViewModel = new UserViewModel(this.username)
  @StorageLink(StorageKeys.TOPIC_READ_STATES) topicReadStates: string = '[]'

  aboutToAppear(): void { this.vm.load() }

  build() {
    Column() {
      SecondaryListScaffold() {
        if (this.vm.isLoading && this.vm.profile === null) {
          ListItem() { this.LoadingView() }
        } else if (this.vm.profile !== null) {
          ListItem() {
            this.ProfileCard()
          }
          ListItem() {
            Text('最近主题')
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor($r('sys.color.font_secondary'))
              .padding(ThemeConstants.SPACE_SM)
          }
          LazyForEach(this.vm.topicDataSource, (topic: V2exTopic) => {
            ListItem() {
              TopicCard({
                item: topic,
                isUnread: this.isTopicUnread(topic),
                onNodeClick: () => {
                  let p: NodeTopicListParams = { nodeName: topic.node.name, nodeTitle: topic.node.title }
                  this.stack.pushPathByName('NodeTopicList', p as Object)
                }
              })
            }
              .onClick(() => {
                let p: TopicDetailParams = { topicId: topic.id }
                this.stack.pushPathByName('TopicDetail', p as Object)
              })
          }, (topic: V2exTopic) => topic.id.toString())
        } else {
          ListItem() { this.ErrorView() }
        }
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder LoadingView() {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE)
        .height(ThemeConstants.LOADING_SIZE)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder ProfileCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Avatar({ url: this.vm.profile!.avatar_large || this.vm.profile!.avatar_normal, avatarSize: 72 })
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(this.vm.profile!.username)
            .fontSize(ThemeConstants.FONT_SIZE_HEADING + 2)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.vm.profile!.tagline) {
            Text(this.vm.profile!.tagline)
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Text(`第 ${this.vm.profile!.id} 号会员 · ${DateUtils.toDateString(this.vm.profile!.created)}`)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.vm.profile!.bio) {
        Text(this.vm.profile!.bio)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY + 2)
          .width('100%')
      }

      this.ProfileMeta()
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder ProfileMeta() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      if (this.vm.profile!.location) {
        this.MetaRow('位置', this.vm.profile!.location)
      }
      if (this.vm.profile!.website) {
        this.MetaRow('网站', this.vm.profile!.website)
      }
      if (this.vm.profile!.github) {
        this.MetaRow('GitHub', this.vm.profile!.github)
      }
      if (this.vm.profile!.twitter) {
        this.MetaRow('Twitter', this.vm.profile!.twitter)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder MetaRow(label: string, value: string) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Text(label)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .width(56)
      Text(value)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder ErrorView() {
    Column() {
      Text(this.vm.errorMessage || '加载失败')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.vm.load() })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  private isTopicUnread(topic: V2exTopic): boolean {
    if (topic.id <= 0) {
      return false
    }
    const lastTouched = topic.last_touched || topic.last_modified || topic.created
    const state = this.findReadState(topic.id)
    if (!state) {
      return true
    }
    return lastTouched > state.touchedAt
  }

  private findReadState(topicId: number): TopicReadState | null {
    try {
      const parsed = JSON.parse(this.topicReadStates || '[]') as TopicReadState[]
      if (!Array.isArray(parsed)) {
        return null
      }
      for (let i = 0; i < parsed.length; i++) {
        if (parsed[i].id === topicId) {
          return parsed[i]
        }
      }
      return null
    } catch (_e) {
      return null
    }
  }
}
