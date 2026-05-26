import { UserViewModel } from '../viewmodel/UserViewModel'
import {
  AppStrings,
  V2exTopic,
  V2exUserReply,
  TopicCard,
  ThemeConstants,
  TopicDetailParams,
  StorageKeys,
  NodeTopicListParams,
  ImagePreviewParams,
  SecondaryListScaffold,
  UserProfileParams,
  CookieJarSettings,
  V2exRoute,
  V2exUrlRouter,
} from 'shared'
import type { TopicReadState } from 'shared'
import { promptAction, SegmentButton, SegmentButtonOptions } from '@kit.ArkUI'
import { common, Want } from '@kit.AbilityKit'
import {
  UserProfileAllActivityButton,
  UserProfileCard,
  UserProfileEmptyCard,
  UserProfileErrorState,
  UserProfileLoadingState,
  UserProfileReplyCard
} from '../components/UserProfileComponents'
import { UserProfilePageCoordinator } from '../model/UserProfilePageCoordinator'
@Component
export struct UserProfilePage {
  @Prop username: string = '';
  @Consume('ns') stack: NavPathStack;
  @State vm: UserViewModel = new UserViewModel(this.username);
  @State private activityTab: number = 0;
  @State private tabSelectedIndexes: number[] = [0];
  @State private tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [
      { text: AppStrings.text(AppStrings.R_USER_TAB_TOPICS_LABEL, 'Topics') },
      { text: AppStrings.text(AppStrings.R_USER_TAB_REPLIES_LABEL, 'Replies') }
    ],
    buttonPadding: { top: 10, bottom: 10, left: 8, right: 8 },
  });
  @State private following: boolean = false;
  @State private blocked: boolean = false;
  @StorageLink(StorageKeys.TOPIC_READ_STATES) topicReadStates: string = '[]';
  @StorageLink(StorageKeys.AUTH_SESSION_USERNAME) sessionUsername: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_ACTION)
  @Watch('onUserProfileActionCommand')
  userProfileActionCommand: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_ACTIONS_USERNAME) userProfileActionsUsername: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_ACTIONS_AVAILABLE) userProfileActionsAvailable: boolean =
    false;
  @StorageLink(StorageKeys.USER_PROFILE_FOLLOW_LABEL) userProfileFollowLabel: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_BLOCK_LABEL) userProfileBlockLabel: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_FOLLOWING) userProfileFollowing: boolean = false;
  @StorageLink(StorageKeys.USER_PROFILE_BLOCKED) userProfileBlocked: boolean = false;
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_USERNAME)
  userProfileAppbarTitleUsername: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_AVATAR_URL)
  userProfileAppbarTitleAvatarUrl: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_ROUTE_USERNAME)
  userProfileAppbarTitleRouteUsername: string = '';
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_TITLE_STATES) userProfileAppbarTitleStates: string =
    '{}';
  @StorageLink(StorageKeys.USER_PROFILE_APPBAR_AVATAR_STATES)
  userProfileAppbarAvatarStates: string = '{}';
  @StorageLink(StorageKeys.USER_PROFILE_SHOWN)
  @Watch('onUserProfileShown')
  userProfileShown: string = '';
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0;
  @State private usernameContentBottom: number = 0;
  @State private currentScrollOffset: number = 0;
  @State private isUsernameCoveredByAppbar: boolean = false;

  private readonly titleVisibilityHysteresis: number = 4;

  aboutToAppear(): void {
    this.currentScrollOffset = 0
    this.usernameContentBottom = 0
    this.isUsernameCoveredByAppbar = false
    this.publishActionMenuState()
    this.publishAppbarTitle(false)
    this.vm
      .load()
      .then(() => {
        this.syncActionState()
        this.evaluateAppbarTitleVisibility()
        this.updateTabLabels()
      })
      .catch((_error: Error) => {})
  }

  build() {
    Column() {
      if (this.vm.isLoading && this.vm.profile === null) {
        Column() {
          UserProfileLoadingState()
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .layoutWeight(1)
      } else if (this.vm.profile !== null) {
        SecondaryListScaffold({
          onDidScroll: (offset: number, _state: ScrollState) => {
            this.currentScrollOffset = Math.max(0, offset)
            this.evaluateAppbarTitleVisibility()
          },
        }) {
          ListItem() {
            this.ProfileCard()
          }
          ListItem() {
            this.ActivityTabs()
          }
          if (this.activityTab === 0) {
            if (this.vm.topicsHidden) {
              ListItem() {
                UserProfileEmptyCard({ message: AppStrings.text($r('app.string.user_topics_hidden'), 'Topic list is hidden') })
              }
            } else if (this.vm.recentTopicCount === 0 && this.vm.isLoading) {
              ListItem() {
                UserProfileLoadingState()
                  .padding(ThemeConstants.SPACE_LG)
              }
            } else if (this.vm.recentTopicCount === 0) {
              ListItem() {
                UserProfileEmptyCard({ message: AppStrings.text(AppStrings.R_USER_PROFILE_NO_TOPICS, 'No topics') })
              }
            } else {
              LazyForEach(
                this.vm.topicDataSource,
                (topic: V2exTopic) => {
                  ListItem() {
                    TopicCard({
                      item: topic,
                      isUnread: this.isTopicUnread(topic),
                      onNodeClick: () => {
                        let p: NodeTopicListParams = {
                          nodeName: topic.node.name,
                          nodeTitle: topic.node.title,
                        }
                        this.stack.pushPathByName('NodeTopicList', p as Object)
                      },
                    })
                  }
                  .onClick(() => {
                    let p: TopicDetailParams = { topicId: topic.id }
                    this.stack.pushPathByName('TopicDetail', p as Object)
                  })
                },
                (topic: V2exTopic) => topic.id.toString(),
              )
              if (this.shouldShowAllActivityButton()) {
                ListItem() {
                  this.AllActivityEntry(AppStrings.text(AppStrings.R_USER_PROFILE_VIEW_ALL_TOPICS, 'View all topics'))
                }
              }
            }
          } else {
            if (this.vm.recentReplyCount === 0 && this.vm.isLoading) {
              ListItem() {
                UserProfileLoadingState()
                  .padding(ThemeConstants.SPACE_LG)
              }
            } else if (this.vm.recentReplyCount === 0) {
              ListItem() {
                UserProfileEmptyCard({ message: AppStrings.text(AppStrings.R_USER_PROFILE_NO_REPLIES, 'No replies') })
              }
            } else {
              LazyForEach(
                this.vm.replyDataSource,
                (reply: V2exUserReply) => {
                  ListItem() {
                    this.ReplyItem(reply)
                  }
                },
                (reply: V2exUserReply) => this.replyStableKey(reply),
              )
              if (this.shouldShowAllActivityButton()) {
                ListItem() {
                  this.AllActivityEntry(AppStrings.text(AppStrings.R_USER_PROFILE_VIEW_ALL_REPLIES, 'View all replies'))
                }
              }
            }
          }
        }
      } else {
        Column() {
          UserProfileErrorState({
            message: this.vm.errorMessage || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Load failed'),
            retryAction: () => {
              this.vm.load()
            }
          })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRatio: number) => {
      if (isVisible) {
        this.republishVisibleState()
      }
    })
  }

  @Builder ProfileCard() {
    UserProfileCard({
      profile: this.vm.profile!,
      displayUsername: this.displayProfileUsername(),
      onUsernameAreaChange: (bottom: number) => {
        this.usernameContentBottom = bottom + this.currentScrollOffset
        this.evaluateAppbarTitleVisibility()
      }
    })
  }

  private updateTabLabels(): void {
    const labels = UserProfilePageCoordinator.tabLabels(this.vm.recentTopicCount, this.vm.recentReplyCount)
    this.tabOptions.buttons[0].text = labels.topicLabel
    this.tabOptions.buttons[1].text = labels.replyLabel
  }

  @Builder ActivityTabs() {
    Row() {
      SegmentButton({
        options: this.tabOptions,
        selectedIndexes: $tabSelectedIndexes,
        onItemClicked: (index: number) => {
          this.activityTab = index
        },
      })
        .constraintSize({ maxWidth: 448 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding(ThemeConstants.SPACE_SM)
  }

  @Builder AllActivityEntry(label: string) {
    UserProfileAllActivityButton({
      label,
      openAction: () => {
        let p: UserProfileParams = { username: this.username }
        this.stack.pushPathByName(
          this.activityTab === 0 ? 'UserTopics' : 'UserReplies',
          p as Object,
        )
      }
    })
  }

  @Builder ReplyItem(reply: V2exUserReply) {
    UserProfileReplyCard({
      reply,
      fallbackUsername: this.vm.profile!.username,
      openTopic: () => {
        this.openReplyTopic(reply)
      },
      openLink: (url: string) => {
        this.openContentLink(url)
      },
      openImage: (url: string) => {
        this.openImagePreview(url)
      },
      openMention: (username: string) => {
        this.openUserProfile(username)
      }
    })
  }

  private openReplyTopic(reply: V2exUserReply): void {
    if (!reply || reply.topic_id <= 0) {
      return
    }
    const p: TopicDetailParams = reply.target_floor && reply.target_floor > 0
      ? { topicId: reply.topic_id, targetFloor: reply.target_floor }
      : { topicId: reply.topic_id }
    this.stack.pushPathByName('TopicDetail', p as Object)
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

  private openImagePreview(url: string): void {
    const normalized = (url || '').trim()
    if (!normalized) {
      return
    }
    let p: ImagePreviewParams = { url: normalized }
    this.stack.pushPathByName('ImagePreview', p as Object)
  }

  private replyStableKey(reply: V2exUserReply): string {
    const parsedKey = (reply.reply_key || '').trim()
    if (parsedKey) {
      return parsedKey
    }
    return `${reply.topic_id}-${reply.target_floor}-${reply.created}-${reply.created_text || ''}-${reply.topic_title}-${reply.content}`
  }

  private openV2exRoute(route: V2exRoute): void {
    if (route.kind === 'topic' && route.topicId && route.topicId > 0) {
      const p: TopicDetailParams =
        route.targetFloor && route.targetFloor > 0
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
      AppStorage.setOrCreate<string>(
        StorageKeys.PENDING_SEARCH_QUERY,
        `${Date.now()}:${route.query}`,
      )
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
    context.startAbility(want).catch((_error: Error) => {})
  }

  private toggleFollow(): void {
    if (this.vm.isActionLoading) {
      return
    }
    const previousFollowing = this.following
    const nextFollowing = !this.following
    this.following = nextFollowing
    this.publishActionMenuState()
    this.vm
      .toggleFollow()
      .then(() => {
        this.syncActionState()
        this.showActionToast(AppStrings.text(nextFollowing ? $r('app.string.followed') : $r('app.string.unfollowed'), nextFollowing ? 'Followed' : 'Unfollowed'))
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
    this.vm
      .toggleBlock()
      .then(() => {
        this.syncActionState()
        this.showActionToast(AppStrings.text(nextBlocked ? $r('app.string.blocked') : $r('app.string.unblocked'), nextBlocked ? 'Blocked' : 'Unblocked'))
        this.refreshActionStateLater()
      })
      .catch((error: Error) => {
        this.blocked = previousBlocked
        this.publishActionMenuState()
        this.showActionToast(this.actionFailureToast(error))
        this.reloadActionStateAfterFailure()
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
    return UserProfilePageCoordinator.displayUsername(this.vm.profile?.username || '', this.username)
  }

  private evaluateAppbarTitleVisibility(): void {
    const displayUsername = this.displayProfileUsername()
    const shouldShowTitle = UserProfilePageCoordinator.shouldShowAppbarTitle(
      displayUsername,
      this.usernameContentBottom,
      this.currentScrollOffset,
      this.topH,
      ThemeConstants.TITLE_BAR_HEIGHT,
      this.isUsernameCoveredByAppbar,
      this.titleVisibilityHysteresis
    )
    if (shouldShowTitle === this.isUsernameCoveredByAppbar) {
      return
    }
    this.isUsernameCoveredByAppbar = shouldShowTitle
    this.publishAppbarTitle(shouldShowTitle)
  }

  private publishAppbarTitle(visible: boolean): void {
    const next = UserProfilePageCoordinator.appbarIdentity(
      visible,
      this.username,
      this.displayProfileUsername(),
      this.profileAvatarUrl()
    )
    this.publishAppbarIdentityState(next.titleUsername, next.avatarUrl)
    if (this.userProfileAppbarTitleRouteUsername !== next.routeUsername) {
      this.userProfileAppbarTitleRouteUsername = next.routeUsername
    }
    if (this.userProfileAppbarTitleUsername !== next.titleUsername) {
      this.userProfileAppbarTitleUsername = next.titleUsername
    }
    if (this.userProfileAppbarTitleAvatarUrl !== next.avatarUrl) {
      this.userProfileAppbarTitleAvatarUrl = next.avatarUrl
    }
  }

  private publishAppbarIdentityState(titleUsername: string, avatarUrl: string): void {
    const routeUsername = (this.username || '').trim().toLowerCase()
    if (!routeUsername) {
      return
    }
    this.userProfileAppbarTitleStates =
      UserProfilePageCoordinator.nextStringState(this.userProfileAppbarTitleStates, routeUsername, titleUsername)
    this.userProfileAppbarAvatarStates =
      UserProfilePageCoordinator.nextStringState(this.userProfileAppbarAvatarStates, routeUsername, avatarUrl)
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
    const state = UserProfilePageCoordinator.actionMenuState(
      this.vm.actions,
      this.isCurrentSessionUser(),
      !!CookieJarSettings.getCurrentCookie(),
      this.username,
      this.following,
      this.blocked
    )
    this.userProfileActionsUsername = state.username
    this.userProfileActionsAvailable = state.available
    this.userProfileFollowLabel = state.followLabel
    this.userProfileBlockLabel = state.blockLabel
    this.userProfileFollowing = state.following
    this.userProfileBlocked = state.blocked
  }

  private showActionToast(message: string): void {
    promptAction.openToast({ message: message }).catch((_e: Error) => {})
  }

  private actionFailureToast(error: Error): string {
    const message = (error?.message || '').trim()
    // Web session expired is reported by the API layer; pass it through.
    if (message === 'Web session expired' || message === AppStrings.text(AppStrings.R_API_ERROR_WEB_SESSION_EXPIRED, 'Web session expired, please log in again')) {
      return message
    }
    return AppStrings.text(AppStrings.R_USER_PROFILE_ACTION_FAILED, 'Action failed')
  }

  private reloadActionStateAfterFailure(): void {
    this.vm
      .load()
      .then(() => {
        this.syncActionState()
        this.updateTabLabels()
      })
      .catch((_error: Error) => {})
  }

  private refreshActionStateLater(): void {
    setTimeout(() => {
      this.vm
        .load()
        .then(() => {
          this.syncActionState()
          this.updateTabLabels()
        })
        .catch((_error: Error) => {})
    }, 1200)
  }

  private shouldShowAllActivityButton(): boolean {
    return UserProfilePageCoordinator.shouldShowAllActivityButton(
      this.activityTab,
      this.vm.recentTopicCount,
      this.vm.topicsHidden,
      this.vm.recentReplyCount
    )
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
    if (
      !raw ||
      !this.userProfileActionsAvailable ||
      this.userProfileActionsUsername !== this.username ||
      this.vm.isActionLoading
    ) {
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
    return UserProfilePageCoordinator.sameUsername(a, b)
  }
}
