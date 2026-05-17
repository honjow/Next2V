import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import {
  ApiService,
  Avatar,
  BlockedMemberSettings,
  CardEmptyState,
  CookieJarSettings,
  PageErrorState,
  PageLoadingState,
  PageLoginRequiredState,
  SecondaryListScaffold,
  ThemeConstants,
  TopicCard,
  type TopicDetailParams,
  type UserProfileParams,
  type V2exAccountMemberListItem,
  type V2exTopic
} from 'shared'

@Component
export struct AccountBlacklistPage {
  @Consume('ns') stack: NavPathStack

  @State private members: V2exAccountMemberListItem[] = []
  @State private topics: V2exTopic[] = []
  @State private errorMessage: string = ''
  @State private isLoading: boolean = false

  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.refresh()
  }

  build() {
    Column() {
      if (!CookieJarSettings.getCurrentCookie()) {
        PageLoginRequiredState({
          message: '登录后可查看屏蔽与忽略',
          action: () => {
            this.stack.pushPathByName('V2exNativeLogin', null)
          }
        })
      } else if (this.isLoading && this.members.length === 0 && this.topics.length === 0) {
        PageLoadingState()
      } else if (this.errorMessage && this.members.length === 0 && this.topics.length === 0) {
        PageErrorState({
          message: this.errorMessage,
          retryAction: () => {
            this.refresh(true)
          }
        })
      } else {
        SecondaryListScaffold() {
          ListItem() { this.SectionHeader('屏蔽用户') }
          if (this.members.length === 0) {
            ListItem() { CardEmptyState({ message: '暂无屏蔽用户', expand: false }) }
          } else {
            ForEach(this.members, (item: V2exAccountMemberListItem) => {
              ListItem() { this.MemberRow(item) }
                .onClick(() => { this.openUser(item.username) })
            }, (item: V2exAccountMemberListItem) => `blocked-${item.username}`)
          }

          ListItem() { this.SectionHeader('忽略主题') }
            .margin({ top: ThemeConstants.SPACE_MD })
          if (this.topics.length === 0) {
            ListItem() { CardEmptyState({ message: '暂无忽略主题', expand: false }) }
          } else {
            ForEach(this.topics, (item: V2exTopic) => {
              ListItem() { TopicCard({ item: item }) }
                .onClick(() => { this.openTopic(item.id) })
            }, (item: V2exTopic) => `ignored-${item.id}`)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder private SectionHeader(title: string) {
    Text(title)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_XS })
  }

  @Builder private MemberRow(item: V2exAccountMemberListItem) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Avatar({ url: item.avatar, avatarSize: 42 })
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.username)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  private refresh(force: boolean = false): void {
    if (this.isLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.members = []
      this.topics = []
      this.errorMessage = ''
      return
    }
    this.isLoading = true
    this.errorMessage = ''
    Promise.all([
      this.api.getBlockedMembersWithCookie(cookie),
      this.api.getIgnoredTopicsWithCookie(cookie)
    ])
      .then((result) => {
        this.members = result[0]
        this.topics = result[1]
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext
        BlockedMemberSettings.saveUsernames(context, this.members.map(item => item.username)).catch((error: Error) => {
          console.error('save blocked members failed: ' + error.message)
        })
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '加载失败'
        this.members = []
        this.topics = []
      })
      .finally(() => {
        this.isLoading = false
        if (!force && this.errorMessage) {
          promptAction.openToast({ message: this.errorMessage }).catch((_error: Error) => { })
        }
      })
  }

  private openUser(username: string): void {
    const p: UserProfileParams = { username: username }
    this.stack.pushPathByName('UserProfile', p as Object)
  }

  private openTopic(topicId: number): void {
    const p: TopicDetailParams = { topicId: topicId }
    this.stack.pushPathByName('TopicDetail', p as Object)
  }
}
