import { UserViewModel } from '../viewmodel/UserViewModel'
import { connectImageHero, heroIdForUrl, MediaUrlUtils } from 'shared'
import {
  AppStrings,
  AppActionButton,
  AppModalScaffold,
  AppTextField,
  ConciseListRow,
  V2exTopic,
  V2exUserReply,
  GroupedListSection,
  TopicCard,
  ThemeConstants,
  TopicDetailParams,
  publishUserProfileActionsAvailable, publishUserProfileActionsUsername, publishUserProfileFollowLabel,
  publishUserProfileBlockLabel, publishUserProfileFollowing, publishUserProfileBlocked, publishUserProfileMarkLabel,
  publishUserProfileAppbarTitleUsername, publishUserProfileAppbarTitleAvatarUrl,
  publishUserProfileAppbarTitleRouteUsername, publishUserProfileAppbarTitleStates,
  publishUserProfileAppbarAvatarStates,
  connectUserProfileAppbar,
  connectAuthSessionSignal,
  connectLanguageState,
  NodeTopicListParams,
  ImagePreviewParams,
  SecondaryListScaffold,
  UserProfileParams,
  CookieJarSettings,
  V2exRoute,
  V2exUrlRouter,
  BlockedListSettings,
  DiagnosticLogger,
  SearchQueryBus,
  connectLayoutSafeArea,
  connectNavStack,
  connectTopicReadStates,
  connectUserProfileAction,
  connectUserMarks,
  defaultSheetOptions,
  LayoutSafeAreaState,
  LanguageState,
  TopicReadStatesState,
  UserProfileActionState,
  UserMarkSettings,
  UserMarkState,
} from 'shared'
import type { TopicReadState, UserMarkLabel } from 'shared'
import { promptAction } from '@kit.ArkUI'
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
import { UserProfileActivityTabs } from '../components/UserProfileActivityTabs'
@ComponentV2
export struct UserProfilePage {
  @Param username: string = '';
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private stack: NavPathStack = connectNavStack().stack;
  @Local vm: UserViewModel = new UserViewModel(this.username);
  @Local private activityTab: number = 0;
  @Local private language: LanguageState = connectLanguageState();
  // Count-bearing tab labels (e.g. "Topics 12" / "Replies 3") passed one-way to the @ComponentV2
  // segmented control (UserProfileActivityTabs); refreshed after vm.load() via updateTabLabels().
  @Local private topicTabLabel: string = '';
  @Local private replyTabLabel: string = '';
  @Local private following: boolean = false;
  @Local private blocked: boolean = false;
  // Per-topic read-state ledger (V2 mirror; LocalDataPublisher dual-writes). Read in build() via
  // isTopicUnread -> subscribes this page to unread-dot refreshes.
  private readStates: TopicReadStatesState = connectTopicReadStates();
  // Window safe-area metrics (AppStorageV2 mirror; EntryAbility publishes V2-only).
  // Only read in logic (evaluateAppbarTitleVisibility), never in build().
  private layout: LayoutSafeAreaState = connectLayoutSafeArea();
  // V2 mirror of the one-directional USER_PROFILE_ACTION + USER_PROFILE_SHOWN appbar buses
  // (Index dual-writes). Reacted to via @Monitor below; never read in build().
  @Local private actionState: UserProfileActionState = connectUserProfileAction();
  @Local private usernameContentBottom: number = 0;
  @Local private currentScrollOffset: number = 0;
  @Local private isUsernameCoveredByAppbar: boolean = false;
  @Local private userMarkSheetVisible: boolean = false;
  @Local private userMarkInput: string = '';
  @Local private selectedUserMarkColor: string = UserMarkSettings.DEFAULT_COLOR;
  @Local private userMarkSaving: boolean = false;
  @Local private pendingUserMarkLabelId: string = '';
  @Local private userMarks: UserMarkState = connectUserMarks();

  private readonly titleVisibilityHysteresis: number = 4;

  aboutToAppear(): void {
    this.currentScrollOffset = 0
    this.usernameContentBottom = 0
    this.isUsernameCoveredByAppbar = false
    this.publishActionMenuState()
    this.publishAppbarTitle(false)
    this.restoreUserMarks()
    this.updateTabLabels()
    this.vm
      .load()
      .then(() => {
        this.syncActionState()
        this.evaluateAppbarTitleVisibility()
        this.updateTabLabels()
      })
      .catch((_error: Error) => {})
  }

  @Monitor('language.effectiveLocale')
  onLocaleChanged(): void {
    this.updateTabLabels()
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
                UserProfileEmptyCard({ message: AppStrings.text($r('app.string.user_profile_no_topics'), 'No topics') })
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
                  this.AllActivityEntry(AppStrings.text($r('app.string.user_profile_view_all_topics'), 'View all topics'))
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
                UserProfileEmptyCard({ message: AppStrings.text($r('app.string.user_profile_no_replies'), 'No replies') })
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
                  this.AllActivityEntry(AppStrings.text($r('app.string.user_profile_view_all_replies'), 'View all replies'))
                }
              }
            }
          }
        }
      } else {
        Column() {
          UserProfileErrorState({
            message: this.vm.errorMessage || AppStrings.text($r('app.string.common_load_failed'), 'Load failed'),
            retryAction: () => {
              this.vm.load()
            }
          })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .layoutWeight(1)
      }
      this.UserMarkSheetHost()
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
    // Assigning these @Local strings re-renders the page and pushes the new one-way @Param labels into
    // the segmented control, which updates its @Trace item text — the V2-safe way to update the labels.
    this.topicTabLabel = labels.topicLabel
    this.replyTabLabel = labels.replyLabel
  }

  @Builder ActivityTabs() {
    UserProfileActivityTabs({
      topicLabel: this.topicTabLabel,
      replyLabel: this.replyTabLabel,
      selectedIndex: this.activityTab,
      onTabClicked: (index: number) => {
        this.activityTab = index
      },
    })
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

  @Builder UserMarkSheetHost() {
    Blank()
      .width(1)
      .height(1)
      .bindSheet(
        $$this.userMarkSheetVisible,
        this.UserMarkSheet(),
        defaultSheetOptions(
          SheetSize.LARGE,
          () => {
            this.closeUserMarkSheet()
          },
          [SheetSize.LARGE],
        ),
      )
  }

  @Builder UserMarkSheet() {
    AppModalScaffold({
      title: $r('app.string.user_mark_sheet_title'),
      includeKeyboardPadding: true,
      contentBackgroundColor: $r('sys.color.ohos_id_color_sub_background'),
      closeAction: () => {
        this.closeUserMarkSheet()
      },
    }) {
      ListItem() {
        this.UserMarkCreateSection()
      }
      this.UserMarkExistingItems()
      ListItem() {
        this.UserMarkDisplayLimitSection()
      }
    }
  }

  @Builder UserMarkCreateSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.UserMarkSectionLabel($r('app.string.user_mark_create_section'))
      GroupedListSection({ inset: ThemeConstants.SPACE_XL, radius: ThemeConstants.RADIUS_CARD }) {
        Column({ space: ThemeConstants.SPACE_MD }) {
          AppTextField({
            text: this.userMarkInput,
            placeholder: $r('app.string.user_mark_name_placeholder'),
            onTextChange: (value: string) => {
              this.userMarkInput = value
            }
          })
            .width('100%')
          this.UserMarkColorPalette()
          AppActionButton({
            label: $r('app.string.user_mark_add'),
            primary: true,
            isEnabled: this.canCreateUserMark(),
            action: () => {
              this.createUserMark()
            }
          })
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder UserMarkExistingItems() {
    if (this.allUserMarkLabels().length === 0) {
      ListItem() {
        Column({ space: ThemeConstants.SPACE_XS }) {
          this.UserMarkSectionLabel($r('app.string.user_mark_existing_section'))
          GroupedListSection() {
            Text($r('app.string.user_mark_empty'))
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(ThemeConstants.SPACE_LG)
          }
        }
        .width('100%')
      }
    } else {
      ListItem() {
        this.UserMarkSectionLabel($r('app.string.user_mark_existing_section'))
      }
      ForEach(
        this.allUserMarkLabels(),
        (label: UserMarkLabel) => {
          ListItem() {
            GroupedListSection() {
              this.UserMarkExistingRow(label)
            }
          }
          .swipeAction({ end: this.UserMarkDeleteSwipeEnd(label) })
        },
        (label: UserMarkLabel) => label.id,
      )
    }
  }

  @Builder UserMarkExistingRow(label: UserMarkLabel) {
    ConciseListRow({
      title: label.name,
      showChevron: false,
      hasSwitch: true,
      checked: this.isUserMarkAssigned(label.id),
      isEnabled: !this.isUserMarkRowPending(label.id),
      prefixBuilderParam: (): void => this.UserMarkColorDot(label.color),
      switchAction: (value: boolean) => {
        this.setUserMarkAssignment(label, value)
      }
    })
  }

  @Builder UserMarkDeleteSwipeEnd(label: UserMarkLabel) {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(ThemeConstants.ICON_SIZE_SM)
          .fontColor([Color.White])
      }
      .width(48)
      .height(40)
      .backgroundColor(Color.Red)
      .onClick(() => {
        this.confirmDeleteUserMark(label)
      })
    }
    .height('100%')
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    .justifyContent(FlexAlign.Center)
  }

  @Builder UserMarkDisplayLimitSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.UserMarkSectionLabel($r('app.string.user_mark_display_section'))
      GroupedListSection() {
        ConciseListRow({
          title: $r('app.string.user_mark_display_limit'),
          subtitle: $r('app.string.user_mark_display_limit_hint'),
          showChevron: false,
          hasCounter: true,
          counterValue: `${this.userMarks.displayLimit}`,
          counterDecreaseEnabled: this.userMarks.displayLimit > UserMarkSettings.MIN_DISPLAY_LIMIT,
          counterIncreaseEnabled: this.userMarks.displayLimit < UserMarkSettings.MAX_DISPLAY_LIMIT,
          counterDecreaseAction: () => {
            this.updateUserMarkDisplayLimit(this.userMarks.displayLimit - 1)
          },
          counterIncreaseAction: () => {
            this.updateUserMarkDisplayLimit(this.userMarks.displayLimit + 1)
          }
        })
        ConciseListRow({
          title: $r('app.string.user_mark_combined_badge'),
          subtitle: $r('app.string.user_mark_combined_badge_hint'),
          showChevron: false,
          hasSwitch: true,
          checked: this.userMarks.combinedBadge,
          switchAction: (value: boolean) => {
            this.updateUserMarkCombinedBadge(value)
          }
        })
      }
    }
    .width('100%')
  }

  @Builder UserMarkColorPalette() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      ForEach(
        UserMarkSettings.defaultColors(),
        (color: string) => {
          this.UserMarkColorOption(color)
        },
        (color: string) => color,
      )
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder UserMarkColorOption(color: string) {
    Stack() {
      if (this.selectedUserMarkColor === color) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontColor([UserMarkSettings.textColorForBackground(color)])
      }
    }
    .width(32)
    .height(32)
    .borderRadius(16)
    .backgroundColor(color)
    .border({
      width: this.selectedUserMarkColor === color ? 3 : 1,
      color: this.selectedUserMarkColor === color
        ? ThemeConstants.BRAND_PRIMARY
        : $r('sys.color.ohos_id_color_button_normal')
    })
    .onClick(() => {
      this.selectedUserMarkColor = color
    })
  }

  @Builder UserMarkColorDot(color: string) {
    Text('')
      .width(18)
      .height(18)
      .borderRadius(9)
      .backgroundColor(color)
  }

  @Builder UserMarkSectionLabel(label: ResourceStr) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_SECTION_TITLE)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
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

  private openUserMarkSheet(): void {
    if (!this.targetUserMarkUsername()) {
      return
    }
    this.restoreUserMarks()
    this.userMarkSheetVisible = true
  }

  private closeUserMarkSheet(): void {
    this.userMarkSheetVisible = false
    this.userMarkSaving = false
    this.pendingUserMarkLabelId = ''
    this.userMarkInput = ''
  }

  private restoreUserMarks(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    UserMarkSettings.load(context).catch((error: Error) => {
      console.error('load user marks failed: ' + error.message)
    })
  }

  private targetUserMarkUsername(): string {
    return (this.displayProfileUsername() || this.username || '').trim()
  }

  private allUserMarkLabels(): UserMarkLabel[] {
    return UserMarkSettings.parseLabels(this.userMarks.labelsJson)
  }

  private isUserMarkAssigned(labelId: string): boolean {
    return UserMarkSettings.isLabelAssignedToUsername(
      this.targetUserMarkUsername(),
      labelId,
      this.userMarks.assignmentsJson,
    )
  }

  private canCreateUserMark(): boolean {
    return !this.userMarkBusy() && !!this.targetUserMarkUsername() && !!(this.userMarkInput || '').trim()
  }

  private userMarkBusy(): boolean {
    return this.userMarkSaving || !!this.pendingUserMarkLabelId
  }

  private isUserMarkRowPending(labelId: string): boolean {
    return !!labelId && this.pendingUserMarkLabelId === labelId
  }

  private createUserMark(): void {
    const name = (this.userMarkInput || '').trim()
    if (!name) {
      this.showActionToast(AppStrings.text($r('app.string.user_mark_name_required'), 'Enter a mark name'))
      return
    }
    const target = this.targetUserMarkUsername()
    if (!target || this.userMarkBusy()) {
      return
    }
    this.userMarkSaving = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    UserMarkSettings.createLabelAndAssign(context, target, name, this.selectedUserMarkColor)
      .then(() => {
        this.userMarkInput = ''
        this.userMarkSaving = false
        this.showActionToast(AppStrings.text($r('app.string.common_saved'), 'Saved'))
      })
      .catch((error: Error) => {
        this.userMarkSaving = false
        this.showActionToast(error.message || AppStrings.text($r('app.string.common_save_failed'), 'Save failed'))
      })
  }

  private setUserMarkAssignment(label: UserMarkLabel, assigned: boolean): void {
    if (this.userMarkBusy()) {
      return
    }
    const target = this.targetUserMarkUsername()
    if (!target || !label.id) {
      return
    }
    this.pendingUserMarkLabelId = label.id
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const task = assigned
      ? UserMarkSettings.assignLabel(context, target, label.id)
      : UserMarkSettings.unassignLabel(context, target, label.id)
    task
      .then(() => {
        this.pendingUserMarkLabelId = ''
      })
      .catch((error: Error) => {
        this.pendingUserMarkLabelId = ''
        this.showActionToast(error.message || AppStrings.text($r('app.string.common_save_failed'), 'Save failed'))
      })
  }

  private confirmDeleteUserMark(label: UserMarkLabel): void {
    if (!label.id || this.userMarkBusy()) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.text($r('app.string.common_delete'), 'Delete'),
      message: AppStrings.format(
        AppStrings.text($r('app.string.confirm_delete_proxy_message'), 'Delete "{0}"?'),
        [label.name],
      ),
      primaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.common_delete'),
        action: () => {
          this.deleteUserMark(label)
        }
      }
    })
  }

  private deleteUserMark(label: UserMarkLabel): void {
    if (!label.id || this.userMarkBusy()) {
      return
    }
    this.pendingUserMarkLabelId = label.id
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    UserMarkSettings.deleteLabel(context, label.id)
      .then(() => {
        this.pendingUserMarkLabelId = ''
        this.showActionToast(AppStrings.text($r('app.string.common_deleted'), 'Deleted'))
      })
      .catch((error: Error) => {
        this.pendingUserMarkLabelId = ''
        this.showActionToast(error.message || AppStrings.text($r('app.string.common_delete_failed'), 'Delete failed'))
      })
  }

  private updateUserMarkDisplayLimit(value: number): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    UserMarkSettings.saveDisplayLimit(context, value).catch((error: Error) => {
      this.showActionToast(error.message || AppStrings.text($r('app.string.common_save_failed'), 'Save failed'))
    })
  }

  private updateUserMarkCombinedBadge(value: boolean): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    UserMarkSettings.saveCombinedBadge(context, value).catch((error: Error) => {
      this.showActionToast(error.message || AppStrings.text($r('app.string.common_save_failed'), 'Save failed'))
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
    // Arm the shared-element (Hero) binding for the tapped image BEFORE the push, so the source thumbnail's
    // geometryTransition id matches the preview's; Index clears it in onHidden after the preview closes.
    connectImageHero().activeId = heroIdForUrl(MediaUrlUtils.normalizeUrl(normalized))
    let p: ImagePreviewParams = { url: normalized }
    // Push INSIDE animateTo (animated=false suppresses the HDS default route animation) so the route mount
    // happens in this window — that is what drives the shared-element (Hero) geometryTransition morph.
    this.getUIContext().animateTo({ duration: 300, curve: Curve.Friction }, () => {
      this.stack.pushPathByName('ImagePreview', p as Object, false)
    })
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
      // Centralised action-bus publisher keeps the Date.now() command token out of this @ComponentV2
      // leaf (forbidden by the V2 migration contract); identical `<timestamp>:<query>` semantics.
      SearchQueryBus.publishPending(route.query)
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
        this.applyBlockedMemberDeltaAfterSuccess(nextBlocked)
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

  private applyBlockedMemberDeltaAfterSuccess(blocked: boolean): void {
    const memberId = Math.floor(this.vm.profile?.id || 0)
    if (memberId <= 0) {
      DiagnosticLogger.info('storage', 'blocked_list_member_delta_skip_missing_id', {
        hasUsername: !!(this.username || this.vm.profile?.username),
        blocked: blocked,
      })
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    BlockedListSettings.applyBlockedMemberDelta(memberId, blocked, context, {
      endpoint: this.vm.actions?.blockPath || '',
      source: 'user_profile_mutation',
      trigger: 'member_block_success',
      hasCookie: !!CookieJarSettings.getCurrentCookie(),
      hasUsername: !!(this.username || this.vm.profile?.username),
    }).catch((error: Error) => {
      DiagnosticLogger.exception('storage', 'blocked_list_member_delta_exception', error, {
        memberId: memberId,
        blocked: blocked,
      })
    })
  }

  private isCurrentSessionUser(): boolean {
    // Compare against the live session username from the V2 AuthSessionSignalState mirror (kept in
    // lockstep by the AuthSessionSettings.apply chokepoint) instead of the retired direct
    // AppStorage.get read. Comparison semantics are unchanged: trim + lowercase, empty on either side
    // returns false.
    const current = (connectAuthSessionSignal().username ?? '').trim().toLowerCase()
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
      this.layout.topAvoidHeight,
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
    // These fields are OUTPUT-only from this page (the @ComponentV2 Index reads the V2
    // UserProfileAppbarState mirror to build the appbar); the page is their sole writer. The change
    // guards read the live mirror so the original behavior of only writing on an actual change holds.
    const appbar = connectUserProfileAppbar()
    if (appbar.titleRouteUsername !== next.routeUsername) {
      publishUserProfileAppbarTitleRouteUsername(next.routeUsername)
    }
    if (appbar.titleUsername !== next.titleUsername) {
      publishUserProfileAppbarTitleUsername(next.titleUsername)
    }
    if (appbar.titleAvatarUrl !== next.avatarUrl) {
      publishUserProfileAppbarTitleAvatarUrl(next.avatarUrl)
    }
  }

  private publishAppbarIdentityState(titleUsername: string, avatarUrl: string): void {
    const routeUsername = (this.username || '').trim().toLowerCase()
    if (!routeUsername) {
      return
    }
    // Read-modify-write of the shared per-route STATES ledgers, keyed by routeUsername so stacked
    // UserProfile pages each own their entry. Reading fresh from the live V2 mirror at write time keeps
    // this faithful; the page is the sole writer of these OUTPUT fields.
    const appbar = connectUserProfileAppbar()
    publishUserProfileAppbarTitleStates(
      UserProfilePageCoordinator.nextStringState(appbar.titleStates, routeUsername, titleUsername),
    )
    publishUserProfileAppbarAvatarStates(
      UserProfilePageCoordinator.nextStringState(appbar.avatarStates, routeUsername, avatarUrl),
    )
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
    // OUTPUT-only action-menu state (Index reads these V1-style to build the follow/block menu); the
    // page is their sole writer, so imperative setOrCreate is faithful.
    publishUserProfileActionsUsername(state.username)
    publishUserProfileActionsAvailable(state.available)
    publishUserProfileMarkLabel(state.markLabel)
    publishUserProfileFollowLabel(state.followLabel)
    publishUserProfileBlockLabel(state.blockLabel)
    publishUserProfileFollowing(state.following)
    publishUserProfileBlocked(state.blocked)
  }

  private showActionToast(message: string): void {
    promptAction.openToast({ message: message }).catch((_e: Error) => {})
  }

  private actionFailureToast(error: Error): string {
    const message = (error?.message || '').trim()
    // Web session expired is reported by the API layer; pass it through.
    if (message === 'Web session expired' || message === AppStrings.text($r('app.string.api_error_web_session_expired'), 'Web session expired, please log in again')) {
      return message
    }
    return AppStrings.text($r('app.string.user_profile_action_failed'), 'Action failed')
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
      const parsed = JSON.parse(this.readStates.statesJson || '[]') as TopicReadState[]
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

  @Monitor('actionState.command')
  onUserProfileActionCommand(): void {
    const raw = (this.actionState.command || '').trim()
    const appbar = connectUserProfileAppbar()
    const actionsAvailable = appbar.actionsAvailable
    const actionsUsername = appbar.actionsUsername
    if (
      !raw ||
      actionsUsername !== this.username
    ) {
      return
    }
    const action = raw.split(':').pop() || ''
    if (action === 'mark') {
      this.openUserMarkSheet()
      return
    }
    if (!actionsAvailable || this.vm.isActionLoading) {
      return
    }
    if (action === 'follow' && this.vm.actions?.followPath) {
      this.toggleFollow()
      return
    }
    if (action === 'block' && this.vm.actions?.blockPath) {
      this.toggleBlock()
    }
  }

  @Monitor('actionState.shown')
  onUserProfileShown(): void {
    const raw = (this.actionState.shown || '').trim()
    const shownUsername = raw.split(':').pop() || ''
    if (this.sameUsername(shownUsername, this.username)) {
      this.republishVisibleState()
    }
  }

  private sameUsername(a: string, b: string): boolean {
    return UserProfilePageCoordinator.sameUsername(a, b)
  }
}
