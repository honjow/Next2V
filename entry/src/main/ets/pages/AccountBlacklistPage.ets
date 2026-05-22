import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  AccountMemberRow,
  ApiService,
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
          message: AppStrings.t(AppStrings.R_LOGIN_TO_VIEW_BLOCKED, 'Log in to view blocked and ignored items'),
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
          ListItem() { this.SectionHeader(AppStrings.t(AppStrings.R_BLOCKED_USERS, 'Blocked users')) }
          if (this.members.length === 0) {
            ListItem() { CardEmptyState({ message: AppStrings.t(AppStrings.R_NO_BLOCKED_USERS, 'No blocked users'), expand: false }) }
          } else {
            ForEach(this.members, (item: V2exAccountMemberListItem) => {
              ListItem() {
                AccountMemberRow({ item: item })
              }
                .onClick(() => { this.openUser(item.username) })
            }, (item: V2exAccountMemberListItem) => `blocked-${item.username}`)
          }

          ListItem() { this.SectionHeader(AppStrings.t(AppStrings.R_IGNORED_TOPICS, 'Ignored topics')) }
            .margin({ top: ThemeConstants.SPACE_MD })
          if (this.topics.length === 0) {
            ListItem() { CardEmptyState({ message: AppStrings.t(AppStrings.R_NO_IGNORED_TOPICS, 'No ignored topics'), expand: false }) }
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
        this.errorMessage = error.message || AppStrings.t(AppStrings.R_COMMON_LOAD_FAILED, 'Load failed')
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
