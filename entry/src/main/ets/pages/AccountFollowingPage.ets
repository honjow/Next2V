import { promptAction } from '@kit.ArkUI'
import {
  AppStrings,
  AccountMemberRow,
  ApiService,
  CardEmptyState,
  CookieJarSettings,
  PageErrorState,
  PageLoadingState,
  PageLoginRequiredState,
  PullRefreshListScaffold,
  ThemeConstants,
  type UserProfileParams,
  type V2exAccountMemberListItem
} from 'shared'

@Component
export struct AccountFollowingPage {
  @Consume('ns') stack: NavPathStack

  @State private members: V2exAccountMemberListItem[] = []
  @State private errorMessage: string = ''
  @State private isLoading: boolean = false
  @State private scrollEnabled: boolean = true

  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.refresh()
  }

  build() {
    Column() {
      if (!CookieJarSettings.getCurrentCookie()) {
        PageLoginRequiredState({
          message: AppStrings.R_LOGIN_TO_VIEW_FOLLOWING,
          action: () => {
            this.stack.pushPathByName('V2exNativeLogin', null)
          }
        })
      } else if (this.isLoading && this.members.length === 0) {
        PageLoadingState()
      } else if (this.errorMessage && this.members.length === 0) {
        PageErrorState({
          message: this.errorMessage,
          retryAction: () => {
            this.refresh(true)
          }
        })
      } else {
        PullRefreshListScaffold({
          scrollEnabled: this.scrollEnabled,
          onRefresh: async () => {
            await this.refresh(true)
          },
          onScrollEnableChange: (enabled: boolean) => {
            this.scrollEnabled = enabled
          }
        }) {
          ListItem() { this.SectionHeader(AppStrings.R_NAV_FOLLOWING) }
          if (this.members.length === 0) {
            ListItem() { CardEmptyState({ message: AppStrings.R_NO_FOLLOWING_USERS, expand: false }) }
          } else {
            ForEach(this.members, (item: V2exAccountMemberListItem) => {
              ListItem() {
                AccountMemberRow({ item: item, avatarPlaceholder: item.username })
              }
                .onClick(() => { this.openUser(item.username) })
            }, (item: V2exAccountMemberListItem) => `following-${item.username}`)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder private SectionHeader(title: ResourceStr) {
    Text(title)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_XS })
  }

  private async refresh(force: boolean = false): Promise<void> {
    if (this.isLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.members = []
      this.errorMessage = ''
      return
    }
    this.isLoading = true
    this.errorMessage = ''
    try {
      const result = await this.api.getFollowingMembersWithCookie(cookie)
      this.members = result
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Load failed')
      this.members = []
    } finally {
      this.isLoading = false
      if (!force && this.errorMessage) {
        promptAction.openToast({ message: this.errorMessage }).catch((_error: Error) => { })
      }
    }
  }

  private openUser(username: string): void {
    const p: UserProfileParams = { username: username }
    this.stack.pushPathByName('UserProfile', p as Object)
  }
}
