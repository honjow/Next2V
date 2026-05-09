import { UserViewModel } from '../viewmodel/UserViewModel'
import {
  V2exTopic, V2exUserReply, TopicCard, ThemeConstants, TopicDetailParams, StorageKeys, NodeTopicListParams,
  Avatar, DateUtils, SecondaryListScaffold, MarkdownContent, UserProfileParams, CookieJarSettings,
  V2exRoute, V2exUrlRouter, BlockedMemberSettings
} from 'shared'
import type { TopicReadState } from 'shared'
import { promptAction } from '@kit.ArkUI'
import { common, Want } from '@kit.AbilityKit'

@Component
export struct UserProfilePage {
  @Prop username: string = ''
  @Consume('ns') stack: NavPathStack
  @State vm: UserViewModel = new UserViewModel(this.username)
  @State private activityTab: number = 0
  @State private following: boolean = false
  @State private blocked: boolean = false
  @StorageLink(StorageKeys.TOPIC_READ_STATES) topicReadStates: string = '[]'
  @StorageLink(StorageKeys.AUTH_SESSION_USERNAME) sessionUsername: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_ACTION) @Watch('onUserProfileActionCommand') userProfileActionCommand: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_ACTIONS_USERNAME) userProfileActionsUsername: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_ACTIONS_AVAILABLE) userProfileActionsAvailable: boolean = false
  @StorageLink(StorageKeys.USER_PROFILE_FOLLOW_LABEL) userProfileFollowLabel: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_BLOCK_LABEL) userProfileBlockLabel: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_FOLLOWING) userProfileFollowing: boolean = false
  @StorageLink(StorageKeys.USER_PROFILE_BLOCKED) userProfileBlocked: boolean = false
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_USERNAME) userProfileAppbarTitleUsername: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_AVATAR_URL) userProfileAppbarTitleAvatarUrl: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_ROUTE_USERNAME) userProfileAppbarTitleRouteUsername: string = ''
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_STATES) userProfileAppbarTitleStates: string = '{}'
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_AVATAR_STATES) userProfileAppbarAvatarStates: string = '{}'
  @StorageLink(StorageKeys.USER_PROFILE_SHOWN) @Watch('onUserProfileShown') userProfileShown: string = ''
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @State private usernameContentBottom: number = 0
  @State private currentScrollOffset: number = 0
  @State private isUsernameCoveredByAppbar: boolean = false

  private readonly titleVisibilityHysteresis: number = 4

  aboutToAppear(): void {
    this.currentScrollOffset = 0
    this.usernameContentBottom = 0
    this.isUsernameCoveredByAppbar = false
    this.publishActionMenuState()
    this.publishAppbarTitle(false)
    this.vm.load()
      .then(() => {
        this.syncActionState()
        this.evaluateAppbarTitleVisibility()
      })
      .catch((_error: Error) => {
      })
  }

  build() {
    Column() {
      SecondaryListScaffold({
        onDidScroll: (offset: number, _state: ScrollState) => {
          this.currentScrollOffset = Math.max(0, offset)
          this.evaluateAppbarTitleVisibility()
        }
      }) {
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
              if (this.shouldShowAllActivityButton()) {
                ListItem() {
                  this.AllActivityEntry('查看全部主题')
                }
              }
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
              if (this.shouldShowAllActivityButton()) {
                ListItem() {
                  this.AllActivityEntry('查看全部回复')
                }
              }
            }
          }
        } else {
          ListItem() { this.ErrorView() }
        }
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRatio: number) => {
        if (isVisible) {
          this.republishVisibleState()
        }
      })
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
          Text(this.displayProfileUsername())
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onAreaChange((_oldValue: Area, newValue: Area) => {
              const measuredGlobalBottom = this.areaY(newValue?.globalPosition?.y) + this.areaLength(newValue?.height)
              this.usernameContentBottom = measuredGlobalBottom + this.currentScrollOffset
              this.evaluateAppbarTitleVisibility()
            })
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

  @Builder ActivityTabs() {
    Row() {
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.ActivityTabButton('主题', 0, this.vm.recentTopicCount)
        this.ActivityTabButton('回复', 1, this.vm.recentReplyCount)
      }
      Blank()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(ThemeConstants.SPACE_SM)
  }

  @Builder ActivityTabButton(label: string, tab: number, count: number) {
    Button(`${label}${count > 0 ? ` ${count}` : ''}`)
      .type(ButtonType.Capsule)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .height(30)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .fontColor(this.activityTab === tab ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_primary'))
      .onClick(() => {
        this.activityTab = tab
      })
  }

  @Builder AllActivityEntry(label: string) {
    Button(label)
      .type(ButtonType.Capsule)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontColor($r('sys.color.font_primary'))
      .height(40)
      .width('100%')
      .onClick(() => {
        let p: UserProfileParams = { username: this.username }
        this.stack.pushPathByName(this.activityTab === 0 ? 'UserTopics' : 'UserReplies', p as Object)
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
    const route = V2exUrlRouter.parse(clean)
    if (route) {
      this.openV2exRoute(route)
      return
    }
    this.openInSystemBrowser(clean)
  }

  private openV2exRoute(route: V2exRoute): void {
    if (route.kind === 'topic' && route.topicId && route.topicId > 0) {
      const p: TopicDetailParams = route.targetFloor && route.targetFloor > 0
        ? { topicId: route.topicId, targetFloor: route.targetFloor }
        : { topicId: route.topicId }
      this.stack.pushPathByName('TopicDetail', p as Object)
      return
    }
    if (route.kind === 'member' && route.username) {
      this.openUserProfile(route.username)
      return
    }
    if (route.kind === 'node' && route.nodeName) {
      const p: NodeTopicListParams = { nodeName: route.nodeName, nodeTitle: route.nodeName }
      this.stack.pushPathByName('NodeTopicList', p as Object)
      return
    }
    if (route.kind === 'search' && route.query) {
      AppStorage.setOrCreate<string>(StorageKeys.PENDING_SEARCH_QUERY, `${Date.now()}:${route.query}`)
      this.stack.pushPathByName('Search', null)
    }
  }

  private openInSystemBrowser(url: string): void {
    const target = (url || '').trim()
    if (!target) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const want: Want = { action: 'ohos.want.action.viewData', uri: target }
    context.startAbility(want).catch((_error: Error) => { })
  }

  private toggleFollow(): void {
    if (this.vm.isActionLoading) {
      return
    }
    const previousFollowing = this.following
    const nextFollowing = !this.following
    this.following = nextFollowing
    this.publishActionMenuState()
    this.vm.toggleFollow()
      .then(() => {
        this.syncActionState()
        this.showActionToast(nextFollowing ? '已关注' : '已取消关注')
        this.refreshActionStateLater()
      })
      .catch((error: Error) => {
        this.following = previousFollowing
        this.publishActionMenuState()
        this.showActionToast(this.actionFailureToast(error))
        this.reloadActionStateAfterFailure()
      })
  }

  private toggleBlock(): void {
    if (this.vm.isActionLoading) {
      return
    }
    const previousBlocked = this.blocked
    const nextBlocked = !this.blocked
    this.blocked = nextBlocked
    this.publishActionMenuState()
    this.vm.toggleBlock()
      .then(() => {
        this.syncActionState()
        this.persistBlockedMemberState(this.blocked)
        this.showActionToast(nextBlocked ? '已屏蔽' : '已取消屏蔽')
        this.refreshActionStateLater()
      })
      .catch((error: Error) => {
        this.blocked = previousBlocked
        this.publishActionMenuState()
        this.showActionToast(this.actionFailureToast(error))
        this.reloadActionStateAfterFailure()
      })
  }

  private persistBlockedMemberState(blocked: boolean): void {
    const username = this.displayProfileUsername()
    if (!username) {
      BlockedMemberSettings.publishUpdatedAt()
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    BlockedMemberSettings.setBlocked(context, username, blocked)
      .catch((error: Error) => {
        console.error('persist blocked member failed: ' + error.message)
        BlockedMemberSettings.publishUpdatedAt()
      })
  }

  private syncActionState(): void {
    if (this.vm.actions === null) {
      this.publishActionMenuState()
      return
    }
    this.following = this.vm.actions.following
    this.blocked = this.vm.actions.blocked
    this.publishActionMenuState()
  }

  private isCurrentSessionUser(): boolean {
    const current = (this.sessionUsername || '').trim().toLowerCase()
    const target = (this.username || this.vm.profile?.username || '').trim().toLowerCase()
    return !!current && !!target && current === target
  }

  private displayProfileUsername(): string {
    return (this.vm.profile?.username || this.username || '').trim()
  }

  private evaluateAppbarTitleVisibility(): void {
    const displayUsername = this.displayProfileUsername()
    if (!displayUsername || this.usernameContentBottom <= 0) {
      this.isUsernameCoveredByAppbar = false
      this.publishAppbarTitle(false)
      return
    }
    const currentUsernameBottom = this.usernameContentBottom - this.currentScrollOffset
    const appbarBottom = this.topH + ThemeConstants.TITLE_BAR_HEIGHT
    const shouldShowTitle = this.isUsernameCoveredByAppbar
      ? currentUsernameBottom <= appbarBottom + this.titleVisibilityHysteresis
      : currentUsernameBottom <= appbarBottom
    if (shouldShowTitle === this.isUsernameCoveredByAppbar) {
      return
    }
    this.isUsernameCoveredByAppbar = shouldShowTitle
    this.publishAppbarTitle(shouldShowTitle)
  }

  private publishAppbarTitle(visible: boolean): void {
    const nextRouteUsername = visible ? this.username : ''
    const nextTitleUsername = visible ? this.displayProfileUsername() : ''
    const nextAvatarUrl = visible ? this.profileAvatarUrl() : ''
    this.publishAppbarIdentityState(nextTitleUsername, nextAvatarUrl)
    if (this.userProfileAppbarTitleRouteUsername !== nextRouteUsername) {
      this.userProfileAppbarTitleRouteUsername = nextRouteUsername
    }
    if (this.userProfileAppbarTitleUsername !== nextTitleUsername) {
      this.userProfileAppbarTitleUsername = nextTitleUsername
    }
    if (this.userProfileAppbarTitleAvatarUrl !== nextAvatarUrl) {
      this.userProfileAppbarTitleAvatarUrl = nextAvatarUrl
    }
  }

  private publishAppbarIdentityState(titleUsername: string, avatarUrl: string): void {
    const routeUsername = (this.username || '').trim().toLowerCase()
    if (!routeUsername) {
      return
    }
    let titleStates: Record<string, string> = {}
    let avatarStates: Record<string, string> = {}
    try {
      const parsed = JSON.parse(this.userProfileAppbarTitleStates || '{}') as Record<string, string>
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        titleStates = parsed
      }
    } catch (_e) {
    }
    try {
      const parsed = JSON.parse(this.userProfileAppbarAvatarStates || '{}') as Record<string, string>
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        avatarStates = parsed
      }
    } catch (_e) {
    }
    titleStates[routeUsername] = titleUsername
    avatarStates[routeUsername] = avatarUrl
    this.userProfileAppbarTitleStates = JSON.stringify(titleStates)
    this.userProfileAppbarAvatarStates = JSON.stringify(avatarStates)
  }

  private profileAvatarUrl(): string {
    return (this.vm.profile?.avatar_large || this.vm.profile?.avatar_normal || '').trim()
  }

  private areaY(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }

  private areaLength(value: Length | undefined): number {
    return this.areaY(value)
  }

  private republishVisibleState(): void {
    this.publishActionMenuState()
    this.evaluateAppbarTitleVisibility()
    this.publishAppbarTitle(this.isUsernameCoveredByAppbar)
  }

  private publishActionMenuState(): void {
    const canShowActions = this.vm.actions !== null && !this.isCurrentSessionUser() && !!CookieJarSettings.getCurrentCookie()
    const hasFollowAction = canShowActions && !!this.vm.actions?.followPath
    const hasBlockAction = canShowActions && !!this.vm.actions?.blockPath
    const available = hasFollowAction || hasBlockAction
    this.userProfileActionsUsername = this.username
    this.userProfileActionsAvailable = available
    this.userProfileFollowLabel = hasFollowAction ? (this.following ? '取消关注' : '关注') : ''
    this.userProfileBlockLabel = hasBlockAction ? (this.blocked ? '取消屏蔽' : '屏蔽') : ''
    this.userProfileFollowing = hasFollowAction && this.following
    this.userProfileBlocked = hasBlockAction && this.blocked
  }

  private showActionToast(message: string): void {
    promptAction.openToast({ message: message }).catch((_e: Error) => {})
  }

  private actionFailureToast(error: Error): string {
    const message = (error?.message || '').trim()
    if (message === 'Web 会话已失效，请重新登录') {
      return message
    }
    return '操作失败'
  }

  private reloadActionStateAfterFailure(): void {
    this.vm.load()
      .then(() => {
        this.syncActionState()
      })
      .catch((_error: Error) => {
      })
  }

  private refreshActionStateLater(): void {
    setTimeout(() => {
      this.vm.load()
        .then(() => {
          this.syncActionState()
        })
        .catch((_error: Error) => {
        })
    }, 1200)
  }

  private shouldShowAllActivityButton(): boolean {
    if (this.activityTab === 0) {
      return this.vm.recentTopicCount > 0 && !this.vm.topicsHidden
    }
    return this.vm.recentReplyCount > 0
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

  onUserProfileActionCommand(_propName: string): void {
    const raw = (this.userProfileActionCommand || '').trim()
    if (!raw || !this.userProfileActionsAvailable || this.userProfileActionsUsername !== this.username ||
      this.vm.isActionLoading) {
      return
    }
    const action = raw.split(':').pop() || ''
    if (action === 'follow' && this.vm.actions?.followPath) {
      this.toggleFollow()
      return
    }
    if (action === 'block' && this.vm.actions?.blockPath) {
      this.toggleBlock()
    }
  }

  onUserProfileShown(_propName: string): void {
    const raw = (this.userProfileShown || '').trim()
    const shownUsername = raw.split(':').pop() || ''
    if (this.sameUsername(shownUsername, this.username)) {
      this.republishVisibleState()
    }
  }

  private sameUsername(a: string, b: string): boolean {
    return !!a && !!b && a.trim().toLowerCase() === b.trim().toLowerCase()
  }
}
