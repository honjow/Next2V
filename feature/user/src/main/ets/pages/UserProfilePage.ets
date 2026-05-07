import { UserViewModel } from '../viewmodel/UserViewModel'
import {
  V2exTopic, V2exUserReply, TopicCard, ThemeConstants, TopicDetailParams, StorageKeys, NodeTopicListParams,
  Avatar, DateUtils, SecondaryListScaffold, MarkdownContent, UserProfileParams
} from 'shared'
import type { TopicReadState } from 'shared'
import { promptAction } from '@kit.ArkUI'

@Component
export struct UserProfilePage {
  @Prop username: string = ''
  @Consume('ns') stack: NavPathStack
  @State vm: UserViewModel = new UserViewModel(this.username)
  @State private activityTab: number = 0
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
            this.ActivityTabs()
          }
          if (this.activityTab === 0) {
            if (this.vm.topicsHidden) {
              ListItem() {
                this.EmptyText('主题列表已隐藏')
              }
            } else if (this.vm.recentTopicCount === 0) {
              ListItem() {
                this.EmptyText('暂无主题')
              }
            } else {
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
            }
          } else {
            if (this.vm.recentReplyCount === 0) {
              ListItem() {
                this.EmptyText('暂无回复')
              }
            } else {
              LazyForEach(this.vm.replyDataSource, (reply: V2exUserReply) => {
                ListItem() {
                  this.ReplyItem(reply)
                }
                .onClick(() => {
                  let p: TopicDetailParams = { topicId: reply.topic_id, targetFloor: reply.target_floor }
                  this.stack.pushPathByName('TopicDetail', p as Object)
                })
              }, (reply: V2exUserReply) => `${reply.topic_id}-${reply.target_floor}-${reply.created}`)
            }
          }
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

      if (this.vm.actions !== null) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          Button(this.vm.actions!.following ? '取消关注' : '关注')
            .type(ButtonType.Capsule)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .enabled(!this.vm.isActionLoading)
            .onClick(() => { this.toggleFollow() })
          Button(this.vm.actions!.blocked ? '取消屏蔽' : '屏蔽')
            .type(ButtonType.Capsule)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(this.vm.actions!.blocked ? $r('sys.color.font_primary') : Color.Red)
            .enabled(!this.vm.isActionLoading)
            .onClick(() => { this.toggleBlock() })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder ActivityTabs() {
    Row() {
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.ActivityTabButton('主题', 0, this.vm.recentTopicCount)
        this.ActivityTabButton('回复', 1, this.vm.recentReplyCount)
      }
      Blank()
      if (this.shouldShowAllActivityButton()) {
        Button('全部')
          .type(ButtonType.Capsule)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .height(32)
          .onClick(() => {
            let p: UserProfileParams = { username: this.username }
            this.stack.pushPathByName(this.activityTab === 0 ? 'UserTopics' : 'UserReplies', p as Object)
          })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(ThemeConstants.SPACE_SM)
  }

  @Builder ActivityTabButton(label: string, tab: number, count: number) {
    Button(`${label}${count > 0 ? ` ${count}` : ''}`)
      .type(ButtonType.Capsule)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .height(32)
      .fontColor(this.activityTab === tab ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
      .backgroundColor(this.activityTab === tab ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.ohos_id_color_card_bg'))
      .onClick(() => {
        this.activityTab = tab
      })
  }

  @Builder EmptyText(text: string) {
    Text(text)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding(ThemeConstants.SPACE_LG)
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder ReplyItem(reply: V2exUserReply) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_XS }) {
        Text(reply.topic_author || this.vm.profile!.username)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        Text('›')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        Text(reply.node_title || reply.node_name)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        if (reply.created > 0) {
          Text(DateUtils.toDateString(reply.created))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .width('100%')

      Text(reply.topic_title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (reply.content) {
        MarkdownContent({
          source: reply.content,
          topMargin: 0,
          onLinkClick: (url: string) => { this.openContentLink(url) },
          onMentionClick: (username: string) => { this.openUserProfile(username) }
        })
      }
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_CARD)
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

  private openUserProfile(username: string): void {
    const clean = (username || '').trim()
    if (!clean) {
      return
    }
    let p: UserProfileParams = { username: clean }
    this.stack.pushPathByName('UserProfile', p as Object)
  }

  private openContentLink(url: string): void {
    const clean = (url || '').trim()
    const memberMatch = clean.match(/^https?:\/\/(?:www\.)?v2ex\.(?:com|co)\/member\/([0-9A-Za-z_]+)$/i) ||
      clean.match(/^\/member\/([0-9A-Za-z_]+)$/i)
    if (memberMatch && memberMatch[1]) {
      this.openUserProfile(memberMatch[1])
    }
  }

  private shouldShowAllActivityButton(): boolean {
    if (this.activityTab === 0) {
      return this.vm.recentTopicCount > 0 && !this.vm.topicsHidden
    }
    return this.vm.recentReplyCount > 0
  }

  private toggleFollow(): void {
    this.vm.toggleFollow()
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '操作失败' }).catch((_e: Error) => {})
      })
  }

  private toggleBlock(): void {
    this.vm.toggleBlock()
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '操作失败' }).catch((_e: Error) => {})
      })
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
