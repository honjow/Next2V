import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import {
  AccountMemberRow,
  ApiService,
  AppStrings,
  BlockedMemberSettings,
  CardEmptyState,
  CookieJarSettings,
  PageErrorState,
  SecondaryListScaffold,
  ThemeConstants,
  type UserProfileParams,
  type V2exAccountMemberListItem
} from 'shared'

@Component
export struct AccountBlacklistPage {
  @Consume('ns') stack: NavPathStack

  @State private members: V2exAccountMemberListItem[] = []
  @State private errorMessage: string = ''
  @State private isUnblocking: boolean = false

  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.refresh()
  }

  build() {
    Column() {
      if (this.errorMessage && this.members.length === 0) {
        PageErrorState({
          message: this.errorMessage,
          retryAction: () => {
            this.refresh()
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
                Column({ space: ThemeConstants.SPACE_SM }) {
                  AccountMemberRow({ item: item, avatarPlaceholder: item.username })
                    .onClick(() => { this.openUser(item.username) })
                  Button('取消屏蔽')
                    .width('100%')
                    .type(ButtonType.Normal)
                    .enabled(!this.isUnblocking)
                    .onClick(() => { this.unblockUser(item.username) })
                }
              }
            }, (item: V2exAccountMemberListItem) => `blocked-${item.username}`)
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

  private refresh(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    BlockedMemberSettings.loadUsernames(context)
      .then((usernames: string[]) => {
        this.members = usernames.map((username: string): V2exAccountMemberListItem => {
          return {
            username: username,
            avatar: '',
            subtitle: '本地缓存'
          }
        })
        this.errorMessage = ''
      })
      .catch((error: Error) => {
        this.members = []
        this.errorMessage = error.message || AppStrings.t(AppStrings.R_COMMON_LOAD_FAILED, 'Load failed')
      })
  }

  private unblockUser(username: string): void {
    if (this.isUnblocking) {
      return
    }
    const normalized = username.trim().toLowerCase()
    if (!normalized) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction.openToast({ message: AppStrings.t(AppStrings.R_LOGIN_TO_VIEW_BLOCKED, 'Log in to view blocked and ignored items') }).catch((_error: Error) => { })
      return
    }
    const previousMembers = this.members.slice()
    this.isUnblocking = true
    this.members = this.members.filter((item: V2exAccountMemberListItem) => item.username.trim().toLowerCase() !== normalized)
    this.api.getMemberPageSnapshot(normalized, cookie)
      .then((snapshot) => {
        if (!snapshot.actions || !snapshot.actions.blocked || !snapshot.actions.blockPath) {
          return Promise.resolve()
        }
        return this.api.executeMemberActionWithCookie(cookie, normalized, snapshot.actions.blockPath).then(() => {})
      })
      .then(() => BlockedMemberSettings.setBlocked(context, normalized, false))
      .then(() => {
        promptAction.openToast({ message: '已取消屏蔽' }).catch((_error: Error) => { })
      })
      .catch((error: Error) => {
        this.members = previousMembers
        promptAction.openToast({ message: error.message || '取消屏蔽失败' }).catch((_error: Error) => { })
      })
      .finally(() => {
        this.isUnblocking = false
      })
  }

  private openUser(username: string): void {
    const p: UserProfileParams = { username: username }
    this.stack.pushPathByName('UserProfile', p as Object)
  }
}
