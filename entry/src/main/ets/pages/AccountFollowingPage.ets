import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  Avatar,
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
          message: '登录后可查看关注用户',
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
          ListItem() { this.SectionHeader('关注用户') }
          if (this.members.length === 0) {
            ListItem() { CardEmptyState({ message: '暂无关注用户', expand: false }) }
          } else {
            ForEach(this.members, (item: V2exAccountMemberListItem) => {
              ListItem() { this.MemberRow(item) }
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

  @Builder private SectionHeader(title: string) {
    Text(title)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_XS })
  }

  @Builder private MemberRow(item: V2exAccountMemberListItem) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Avatar({ url: item.avatar, avatarSize: 42, placeholder: item.username })
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
      this.errorMessage = e.message || '加载失败'
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
