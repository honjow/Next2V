import { AppStrings } from 'shared'
import { connectImageHero, heroIdForUrl, MediaUrlUtils } from 'shared'
import {
  connectTopicDetailAction,
  connectTopicDetailAppbar,
  TopicDetailActionState,
  publishTopicDetailSavedLater,
  publishTopicDetailSiteFavorited,
  publishTopicDetailThanked,
  publishTopicDetailAppbarTitle,
  publishTopicDetailAppbarAvatarUrl,
  publishTopicDetailAppbarUsername,
  publishTopicDetailAppbarRouteTopicId,
  publishTopicDetailAppbarTitleStates,
  publishTopicDetailAppbarAvatarStates,
  publishTopicDetailAppbarUsernameStates,
  publishTopicDetailTopicIgnored,
  publishTopicDetailOwnership,
  clearTopicDetailOwnership,
  publishTopicComposeTarget,
  connectNodePickAction,
  NodePickActionState,
  AccountStore,
  type AccountRecord,
} from 'shared'
import { DetailViewModel, type ReplyThankSnapshot } from '../viewmodel/DetailViewModel'
import { ReplyComposerBar } from '../components/ReplyComposerBar'
import { ReplyComposerDraftCoordinator } from '../model/ReplyComposerDraftCoordinator'
import {
  ReplyContextListItem,
  ReplyContextSheetContent,
  TopicDetailHeader,
  TopicDetailReplyDivider,
  TopicRepliesPreloadIndicator,
} from '../components/TopicDetailComponents'
import { ReplyContextCoordinator, type ReplyContextItem } from '../model/ReplyContextCoordinator'
import {
  TopicDetailContentCoordinator,
  type TopicSupplementBlock,
} from '../model/TopicDetailContentCoordinator'
import {
  TopicDetailActionCoordinator,
  type ReplyThankedIdsSnapshot,
} from '../model/TopicDetailActionCoordinator'
import { TopicDetailAppbarCoordinator } from '../model/TopicDetailAppbarCoordinator'
import {
  TopicDetailFloatingActionCoordinator,
  type TopicDetailFollowTouchState,
} from '../model/TopicDetailFloatingActionCoordinator'
import {
  TopicDetailReplyDisplayCoordinator,
  type TopicDetailReplyCardDisplayState,
} from '../model/TopicDetailReplyDisplayCoordinator'
import { TopicDetailScrollCoordinator } from '../model/TopicDetailScrollCoordinator'
import { common, Want } from '@kit.AbilityKit'
import { CustomContentDialog, KeyboardAvoidMode, LoadingDialog, promptAction } from '@kit.ArkUI'
import { HdsAnimationMode, HdsTabsController } from '@kit.UIDesignKit'
import { HdsMiniBarButton } from '../components/HdsMiniBarButton'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { systemShare } from '@kit.ShareKit'
import {
  V2exReply,
  ReplyCard,
  ThemeConstants,
  MarkdownContent,
  PullRefreshListScaffold,
  NodeTopicListParams,
  UserProfileParams,
  ImagePreviewParams,
  CollectionSettings,
  CacheSettings,
  V2exTopic,
  AuthSettings,
  LoadingFooter,
  HttpClient,
  ApiService,
  CookieJarSettings,
  V2exToggleAction,
  ReadingSettings,
  ReplyDisplaySettings,
  V2exUrlRouter,
  V2exRouteNavigator,
  TopicDetailParams,
  MotionHandStateService,
  defaultSheetOptions,
  translateApiError,
  CacheOwnerResolver,
  TopicDetailActionOverlaySettings,
  BlockedListSettings,
  connectHotReplySettings,
  connectBlockedListStorage,
  BlockedListStorageState,
  HotReplySettingsState,
  DiagnosticLogger,
  connectNavStack,
  connectLayoutSafeArea,
  connectReadingSettings,
  connectReplyDisplay,
  connectAuthCookie,
  publishAccountWebViewUrl,
  connectMotionHandEdge,
  connectTopicDetailReplyButton,
  LayoutSafeAreaState,
  ReadingSettingsState,
  AuthCookieState,
  MotionHandEdgeState,
  TopicDetailReplyButtonState,
} from 'shared'
import type { V2exTopicThankAction, CacheScope, TopicDetailActionOverlay } from 'shared'
import type { V2exReplyModerationAction, V2exTopicModerationAction } from 'shared'
import { HotRepliesPanel } from '../components/HotRepliesPanel'
@ComponentV2
export struct TopicDetailPage {
  @Param topicId: number = 0;
  @Param targetFloor: number = 0;
  // Reply text a notification points at; used to verify/repair the targetFloor anchor (see jumpToTargetFloor).
  @Param verifyReplyText: string = '';
  @Param hideTitle: boolean = false;
  @Local v: DetailViewModel = new DetailViewModel(0);
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private stack: NavPathStack = connectNavStack().stack;
  // V2 mirrors (each dual-written by its single writer). layout (safe-area) + reading typography are
  // read reactively in build(); authState.configured drives the reply-button lock glyph.
  private layout: LayoutSafeAreaState = connectLayoutSafeArea();
  private reading: ReadingSettingsState = connectReadingSettings();
  private authState: AuthCookieState = connectAuthCookie();
  @Local private hotReplies: HotReplySettingsState = connectHotReplySettings();
  // @Monitor sources for the motion-hand edge + reply-button auto-hide preferences (see @Monitor below).
  @Local private motion: MotionHandEdgeState = connectMotionHandEdge();
  @Local private replyButton: TopicDetailReplyButtonState = connectTopicDetailReplyButton();
  // Blocked-list cache mirror: the topic page can no longer be trusted to report ignore
  // state (V2EX web bug), so the ignore/unignore menu toggle is driven by this cache.
  @Local private blockedStorage: BlockedListStorageState = connectBlockedListStorage();
  // TOPIC_DETAIL_ACTION command bus: Index (now @ComponentV2) dual-writes this mirror at sendTopicAction;
  // this page observes it via @Monitor below, filtering by its own topicId so stacked pages don't
  // double-fire. Replaces the former V1 TopicDetailActionListener zero-size child adapter.
  private topicAction: TopicDetailActionState = connectTopicDetailAction();
  // The appbar identity / action-flag OUTPUT keys are pushed through the TopicDetailAppbarState
  // write-through helpers (publish*) at their write sites; the @ComponentV2 Index reads them via the
  // mirror. The page holds no component state for them.
  private scroller: Scroller = new Scroller();
  @Local listScrollEnabled: boolean = true;
  @Local private isReplyListAtEnd: boolean = false;
  @Local isSavedLater: boolean = false;
  @Local private isSiteFavorited: boolean = false;
  @Local private isTopicThanked: boolean = false;
  @Local private isSiteFavoriteLoading: boolean = false;
  @Local private isTopicThankLoading: boolean = false;
  @Local private isReplyThankLoading: boolean = false;
  @Local private pendingReplyThankId: number = 0;
  @Local private isModerationActionLoading: boolean = false;
  @Local private jumpFloorText: string = '';
  @Local private contextReply: V2exReply | null = null;
  @Local private hotRepliesExpanded: boolean = true;
  @Local private contextItems: ReplyContextItem[] = [];
  @Local private contextSheetVisible: boolean = false;
  @Local private replyDisplayMenuShown: boolean = false;
  @Local private replyComposerVisible: boolean = false;
  // Page-level pending-submit flag. The reply composer sheet emits a clean content snapshot, this
  // page closes the sheet and owns the network submit, then opens the system LoadingDialog for
  // the duration of the request.
  @Local private isReplySubmitting: boolean = false;
  @Local private visualMotionHandEdge: string = 'right';
  @Local private detailRootWidth: number = 0;
  @Local private detailRootHeight: number = 0;
  @Local private replyComposerInitialContent: string = '';
  @Local private thankedReplyIdsJson: string = '[]';
  @Local private titleContentBottom: number = 0;
  @Local private currentScrollOffset: number = 0;
  @Local private isTitleCoveredByAppbar: boolean = false;
  // IT-Home-style "resume reading" affordance: on entry we no longer auto-scroll to the saved
  // floor; instead this flag surfaces a small floating button (above the reply FAB) that the user
  // taps to jump. It is consumed (set false) on tap, or auto-dismissed once the user scrolls the
  // saved floor into view on their own.
  @Local private showResumeButton: boolean = false;
  private readonly HDS_ACTION_BAR_CLEARANCE: number = 72;
  private readonly TOPIC_DETAIL_REPLY_BUTTON_SIZE: number = 56;
  private readonly TOPIC_DETAIL_RESUME_BUTTON_SIZE: number =
    ThemeConstants.TOPIC_DETAIL_RESUME_BUTTON_SIZE;
  private readonly TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING: number = ThemeConstants.SPACE_LG;
  private readonly TOPIC_DETAIL_REPLY_BUTTON_BOTTOM_CLEARANCE: number = ThemeConstants.SPACE_LG;
  private readonly TOPIC_DETAIL_REPLY_BUTTON_SCROLL_DELTA_PX: number = 6;
  // Treat the saved floor as "reached" once the viewport center is within this many floors of it,
  // so the resume button dismisses a touch early rather than requiring an exact landing.
  private readonly RESUME_BUTTON_FLOOR_PROXIMITY: number = 1;
  private readonly TOPIC_DETAIL_REPLY_BUTTON_ANIMATION_GUARD_MS: number = 180;
  private readonly FOLLOW_OPERATION_VERTICAL_SCROLL_THRESHOLD: number = 24;
  private readonly FOLLOW_OPERATION_VERTICAL_DOMINANCE_RATIO: number = 1.2;
  private readonly titleVisibilityHysteresis: number = 4;
  private api: ApiService = new ApiService();
  // Node-move flow: 移动主题 sets movePending then pushes NodePickerPage; the pick comes back on the shared
  // node-pick command bus. The bus is shared with the create editor, and this detail page outlives the
  // picker, so the pick is gated by movePending AND confirmed in a dialog before the (destructive) move —
  // a stray pick can never silently move the topic.
  private nodePick: NodePickActionState = connectNodePickAction();
  private movePending: boolean = false;
  private cacheScope: CacheScope | null = null;
  private topicActionOverlay: TopicDetailActionOverlay | null = null;
  private topicThankLocked: boolean = false;
  private replyThankLockedId: number = 0;
  private replySubmitLoadingDialogController: CustomDialogController = new CustomDialogController({
    builder: LoadingDialog({
      content: $r('app.string.reply_submitting'),
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false,
  });
  private jumpFloorDialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: $r('app.string.jump_to_floor_title'),
      contentBuilder: () => {
        this.JumpToFloorDialogContent()
      },
      buttons: [
        {
          value: $r('app.string.common_cancel'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            this.closeJumpToFloorDialog()
          },
        },
        {
          value: $r('app.string.jump_to_floor_button'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            const value = this.jumpFloorText
            this.closeJumpToFloorDialog()
            this.handleJumpToFloor(value)
          },
        },
      ],
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: false,
  });
  private lastReadFloor: number = 0;
  private hasRestoredReadPosition: boolean = false;
  private hasJumpedToTargetFloor: boolean = false;
  // The clamped, already-loaded floor the resume button jumps to when tapped. The saved floor it
  // derives from is used to auto-dismiss the button when the user scrolls there manually.
  private resumeTargetFloor: number = 0;
  private resumeSavedFloor: number = 0;
  private resumeButtonController: HdsTabsController = new HdsTabsController();
  private replyButtonController: HdsTabsController = new HdsTabsController();
  private replyButtonVisibleByScroll: boolean = true;
  private replyButtonAnimationGuardTimerId: number = -1;
  private replyButtonLastScrollOffset: number = 0;
  private followTouchState: TopicDetailFollowTouchState =
    TopicDetailFloatingActionCoordinator.initialTouchState();

  aboutToAppear(): void {
    this.v = new DetailViewModel(this.topicId)
    this.v.setReplyDisplayMode(this.currentReplyDisplayMode())
    this.lastReadFloor = 0
    this.hasRestoredReadPosition = false
    this.hasJumpedToTargetFloor = false
    this.showResumeButton = false
    this.resumeTargetFloor = 0
    this.resumeSavedFloor = 0
    this.jumpFloorText = ''
    this.currentScrollOffset = 0
    this.replyButtonLastScrollOffset = 0
    this.replyButtonVisibleByScroll = true
    this.clearReplyButtonAnimationGuardTimer()
    this.applyReplyButtonAutoHideBinding()
    this.titleContentBottom = 0
    this.followTouchState = TopicDetailFloatingActionCoordinator.initialTouchState()
    this.visualMotionHandEdge = this.motion.edge
    this.isTitleCoveredByAppbar = false
    this.syncTopicDetailTitleState(false, false, false)
    this.publishAppbarIdentity(false)
    this.publishTopicIgnoredState()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.v.setCacheHandlers(
      () => CacheSettings.loadTopicDetail(context, this.topicId),
      (topic: V2exTopic | null, replies: V2exReply[]) =>
        CacheSettings.saveTopicDetail(context, this.topicId, topic, replies),
    )
    this.initializeCachedThenNetworkLoad(context)
    this.loadSavedState()
  }

  aboutToDisappear(): void {
    this.persistReadPosition()
    this.replySubmitLoadingDialogController.close()
    this.replyButtonController.unbindScroller(this.scroller)
    this.clearReplyButtonAnimationGuardTimer()
    // Safety net: if the page is left while the composer is open, restore the keyboard-avoid mode so
    // the NONE we set on open never leaks to other pages.
    if (this.replyComposerVisible) {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    }
  }

  private initializeCachedThenNetworkLoad(context: common.UIAbilityContext): void {
    this.loadTopicActionOverlay(context)
      .then(() => {
        this.v.loadCachedData()
        this.loadSiteFavoriteState()
        this.loadTopicThankState()
      })
      .finally(() => {
        AuthSettings.load(context)
          .then((snapshot) => {
            this.v.setToken(snapshot.token || '')
          })
          .catch((_error: Error) => {
            this.v.setToken('')
          })
          .finally(() => {
            this.v.load().then(() => {
              this.recordViewedTopic()
              this.markTopicReadState()
              // Arm the thread preload BEFORE the floor-targeting restore: ensureRepliesLoaded's
              // loadMore loop must see isPreloadingAll and join the in-flight preload instead of
              // racing it with a duplicate page fetch whose publish would collapse a held thread.
              this.triggerReplyPreloadIfNeeded()
              this.restoreInitialPosition()
              this.publishOwnership(context)
            })
          })
      })
  }

  // Owner + time-phase for the 编辑/附言 menu gates. Computed once the topic is loaded by comparing the
  // topic author to the active account's username (case-insensitive); the active username comes from the
  // cookie-session AccountStore record (NOT the API-token identity, which is empty for cookie logins).
  private publishOwnership(context: common.UIAbilityContext): void {
    const topic = this.v.topic
    if (!topic) {
      clearTopicDetailOwnership()
      return
    }
    const opName = (topic.member.username || '').trim().toLowerCase()
    const created = topic.created || 0
    AccountStore.getAll(context)
      .then((records: AccountRecord[]) => {
        const activeId = AccountStore.getActiveId()
        let active: AccountRecord | null = records.find((r: AccountRecord) => r.id === activeId) || null
        if (!active && records.length > 0) {
          active = records[0]
        }
        const me = (active && active.username ? active.username : '').trim().toLowerCase()
        const isOp = me.length > 0 && opName.length > 0 && me === opName
        publishTopicDetailOwnership(this.topicId, isOp, created)
      })
      .catch((_error: Error) => {
        publishTopicDetailOwnership(this.topicId, false, created)
      })
  }

  private async loadTopicActionOverlay(context: common.UIAbilityContext): Promise<void> {
    this.cacheScope = await CacheOwnerResolver.resolveActivePrivateScope(context)
    this.topicActionOverlay = await TopicDetailActionOverlaySettings.loadTopicOverlay(
      context,
      this.cacheScope,
      this.topicId,
    )
    this.applyTopicActionOverlay(this.topicActionOverlay)
  }

  private applyTopicActionOverlay(overlay: TopicDetailActionOverlay | null): void {
    this.v.setTopicActionOverlay(overlay)
    if (!overlay) {
      return
    }
    if (overlay.favoriteKnown) {
      this.isSiteFavorited = overlay.favoriteValue
      publishTopicDetailSiteFavorited(overlay.favoriteValue)
    }
    if (overlay.topicThankKnown && overlay.topicThankValue) {
      this.isTopicThanked = true
      publishTopicDetailThanked(true)
    }
    if (overlay.replyThankedIds.length > 0) {
      this.thankedReplyIdsJson = JSON.stringify(overlay.replyThankedIds)
    }
  }

  private persistTopicFavoriteOverlay(value: boolean): void {
    if (!this.cacheScope || this.topicId <= 0) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    TopicDetailActionOverlaySettings.commitTopicFavorite(
      context,
      this.cacheScope,
      this.topicId,
      value,
    )
      .then(() => this.loadTopicActionOverlay(context))
      .catch((_error: Error) => {})
  }

  private persistTopicThankOverlay(): void {
    if (!this.cacheScope || this.topicId <= 0) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    TopicDetailActionOverlaySettings.commitTopicThank(context, this.cacheScope, this.topicId)
      .then(() => this.loadTopicActionOverlay(context))
      .catch((_error: Error) => {})
  }

  private persistReplyThankOverlay(replyId: number): void {
    if (!this.cacheScope || this.topicId <= 0 || replyId <= 0) {
      return
    }
    const countAfterSuccess = this.v
      .getLoadedRepliesSnapshot()
      .find((item: V2exReply) => item.id === replyId)?.thanks
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    TopicDetailActionOverlaySettings.commitReplyThank(
      context,
      this.cacheScope,
      this.topicId,
      replyId,
      countAfterSuccess,
    )
      .then(() => this.loadTopicActionOverlay(context))
      .catch((_error: Error) => {})
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
    // Native-first: a V2EX URL with a built-in page (topic / node / member / search) opens natively;
    // everything else (external sites, dict /d/, …) goes to the system browser. Shared with the
    // node-description links via V2exRouteNavigator so all in-content links route identically.
    if (V2exRouteNavigator.openInApp(this.stack, clean)) {
      return
    }
    this.openInSystemBrowser(clean)
  }

  private openReplyEditor(initialContent: string = ''): void {
    if (!this.authState.configured || !CookieJarSettings.getCurrentCookie()) {
      this.stack.pushPathByName('V2exNativeLogin', null)
      return
    }
    this.replyComposerInitialContent = initialContent
    this.replyComposerVisible = true
    // The inline bar is page content, so the page's keyboard-avoid mode (default OFFSET) and
    // Navigation's own avoidance would both move it unpredictably across devices. Switch the page to
    // NONE while composing and lift the bar ourselves (expandSafeArea + manual keyboard padding), so
    // the bar reliably rests directly on top of the keyboard everywhere. Restored on dismiss.
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE)
  }

  // Open the shared topic editor in append mode for THIS topic. The menu item is only shown to the OP in
  // the append window (Index.ets gate), but re-check the cookie here as defence-in-depth.
  private openAppendEditor(): void {
    if (!this.authState.configured || !CookieJarSettings.getCurrentCookie()) {
      this.stack.pushPathByName('V2exNativeLogin', null)
      return
    }
    publishTopicComposeTarget('append', this.topicId)
    this.stack.pushPathByName('TopicEditor', null)
  }

  // Open the shared editor in edit mode for THIS topic (prefilled from the live edit form). The menu item
  // is only shown to the OP within the 600s edit window (Index.ets gate); re-check the cookie here.
  private openEditEditor(): void {
    if (!this.authState.configured || !CookieJarSettings.getCurrentCookie()) {
      this.stack.pushPathByName('V2exNativeLogin', null)
      return
    }
    publishTopicComposeTarget('edit', this.topicId)
    this.stack.pushPathByName('TopicEditor', null)
  }

  // 移动主题: arm the move, then pick the destination node via the shared NodePickerPage.
  private openMoveNode(): void {
    if (!this.authState.configured || !CookieJarSettings.getCurrentCookie()) {
      this.stack.pushPathByName('V2exNativeLogin', null)
      return
    }
    this.movePending = true
    this.stack.pushPathByName('NodePicker', null)
  }

  // The destination node came back on the shared node-pick bus. Only act when WE armed a move; then
  // confirm before the destructive move so a stray pick (the bus is shared) can never silently move it.
  @Monitor('nodePick.command')
  onMoveNodePicked(): void {
    if (!this.movePending) {
      return
    }
    this.movePending = false
    const node = (this.nodePick.name || '').trim()
    if (!node) {
      return
    }
    const nodeLabel = (this.nodePick.title || '').trim() || node
    this.getUIContext().showAlertDialog({
      title: AppStrings.text($r('app.string.topic_action_move'), 'Move topic'),
      message: AppStrings.format(AppStrings.text($r('app.string.topic_move_confirm_format'), 'Move this topic to node「{0}」?'), [nodeLabel]),
      primaryButton: { value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'), action: () => { } },
      secondaryButton: {
        value: AppStrings.text($r('app.string.topic_action_move'), 'Move'),
        action: () => { this.executeMoveNode(node) },
      },
    })
  }

  private executeMoveNode(node: string): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      return
    }
    this.api.moveTopicNodeWithCookie(cookie, this.topicId, node)
      .then(() => {
        promptAction.openToast({ message: AppStrings.text($r('app.string.topic_move_done'), 'Topic moved') }).catch((_e: Error) => { })
        this.reloadTopicWithThreadPreload()
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: translateApiError(error) }).catch((_e: Error) => { })
      })
  }

  // Single close path for the composer bar: restore the page keyboard-avoid mode and clear state.
  private dismissReplyComposer(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    this.replyComposerVisible = false
    this.replyComposerInitialContent = ''
  }

  private bodyFontSize(): number {
    return ReadingSettings.scaleTypographyToken(
      ThemeConstants.FONT_SIZE_BODY,
      this.reading.textScale,
    )
  }

  private bodyLineHeight(): number {
    return ReadingSettings.normalizeLineHeight(this.reading.lineHeight, this.reading.textScale)
  }

  private topicCardPadding(): number {
    if (this.reading.density === ReadingSettings.DENSITY_COMPACT) {
      return ThemeConstants.SPACE_MD
    }
    if (this.reading.density === ReadingSettings.DENSITY_COMFORTABLE) {
      return ThemeConstants.SPACE_XL
    }
    return ThemeConstants.SPACE_LG
  }

  build() {
    Stack() {
      Column() {
        if (this.v.isLoading && this.v.topic === null) {
          this.LoadingView()
        } else if (this.v.errorMessage && this.v.topic === null) {
          this.ErrorView()
        } else if (this.v.topic !== null) {
          this.ContentView()
        }
      }
      .width('100%')
      .height('100%')
      .clip(true)
      .onTouch((event: TouchEvent) => {
        this.trackReplyActionFollowOperation(event)
      })

      if (this.detailRootHeight > 0 && this.showResumeButton && !this.replyComposerVisible) {
        this.TopicDetailResumeButton()
      }

      // The reply FAB is the entry point; once the inline composer bar is open it hides so the two
      // never overlap (the bar replaces the FAB until the user sends or taps outside to dismiss).
      if (this.detailRootHeight > 0 && !this.replyComposerVisible) {
        this.TopicDetailReplyActionBar()
      }

      this.ReplyComposerBarHost()
      this.ReplyContextSheetHost()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRatio: number) => {
      if (isVisible) {
        this.republishAppbarIdentity()
      }
    })
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.detailRootWidth = this.areaLength(newValue?.width)
      this.detailRootHeight = this.areaLength(newValue?.height)
    })
  }

  @Builder TopicDetailReplyActionBar() {
    Row() {
      Row() {
        HdsMiniBarButton({
          controller: this.replyButtonController,
          barWidth: this.TOPIC_DETAIL_REPLY_BUTTON_SIZE,
          barHeight: this.TOPIC_DETAIL_REPLY_BUTTON_SIZE,
          activityPadding: this.TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING,
          barBottomMargin: this.TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING,
          onButtonClick: () => {
            this.openReplyEditor()
          },
        }) {
          SymbolGlyph(
            this.authState.configured ? $r('sys.symbol.pencil_line_1') : $r('sys.symbol.lock'),
          )
            .fontSize(28)
            .fontColor([ThemeConstants.BRAND_PRIMARY])
            .fontWeight(FontWeight.Bold)
        }
      }
      .translate({ x: this.replyButtonEdgeX() })
      .animation({ duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut })
    }
    .width('100%')
    .height(
      this.TOPIC_DETAIL_REPLY_BUTTON_SIZE + this.TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING * 2,
    )
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .position({
      x: 0,
      y: this.topicDetailReplyActionBarTop() - this.TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING,
    })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  private topicDetailReplyActionBarTop(): number {
    return TopicDetailFloatingActionCoordinator.actionBarTop(
      this.detailRootHeight,
      this.layout.bottomAvoidHeight,
      this.TOPIC_DETAIL_REPLY_BUTTON_SIZE,
      this.TOPIC_DETAIL_REPLY_BUTTON_BOTTOM_CLEARANCE,
    )
  }

  // Smart-edge horizontal position as a CONTINUOUS value so the @Monitor('motion.edge')
  // animateTo can interpolate it smoothly. justifyContent's FlexAlign is discrete and cannot
  // be tweened — that was the cause of the hard left/right jump (lost in the V1->V2 migration).
  // left edge => 0; right edge => rootWidth - the button's activity-box width.
  private replyButtonEdgeX(): number {
    if (this.visualMotionHandEdge === 'left') {
      return 0
    }
    const activityWidth =
      this.TOPIC_DETAIL_REPLY_BUTTON_SIZE + this.TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING * 2
    return Math.max(0, this.detailRootWidth - activityWidth)
  }

  private resumeButtonEdgeX(): number {
    if (this.visualMotionHandEdge === 'left') {
      return 0
    }
    const activityWidth =
      this.TOPIC_DETAIL_RESUME_BUTTON_SIZE + this.TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING * 2
    return Math.max(0, this.detailRootWidth - activityWidth)
  }

  // Smaller secondary FAB stacked directly above the reply button on the same (smart-edge) side.
  @Builder TopicDetailResumeButton() {
    Row() {
      Row() {
        HdsMiniBarButton({
          controller: this.resumeButtonController,
          barWidth: this.TOPIC_DETAIL_RESUME_BUTTON_SIZE,
          barHeight: this.TOPIC_DETAIL_RESUME_BUTTON_SIZE,
          activityPadding: this.TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING,
          barBottomMargin: this.TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING,
          onButtonClick: () => {
            this.resumeToSavedFloor()
          },
        }) {
          SymbolGlyph($r('sys.symbol.chevron_down_2_circle'))
            .fontSize(24)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
            .accessibilityText(
              AppStrings.text($r('app.string.topic_action_resume_reading'), 'Resume reading'),
            )
        }
      }
      .translate({ x: this.resumeButtonEdgeX() })
      .animation({ duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut })
    }
    .width('100%')
    .height(
      this.TOPIC_DETAIL_RESUME_BUTTON_SIZE + this.TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING * 2,
    )
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .position({
      x: 0,
      y: this.topicDetailResumeButtonTop() - this.TOPIC_DETAIL_REPLY_BUTTON_ACTIVITY_PADDING,
    })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  // Sit the resume button directly above the reply FAB, separated by one spacing unit, both centered
  // on the same side so they read as a vertical action stack.
  private topicDetailResumeButtonTop(): number {
    return (
      this.topicDetailReplyActionBarTop() -
      this.TOPIC_DETAIL_RESUME_BUTTON_SIZE -
      ThemeConstants.SPACE_XL
    )
  }

  private clearReplyButtonAnimationGuardTimer(): void {
    if (this.replyButtonAnimationGuardTimerId === -1) {
      return
    }
    clearTimeout(this.replyButtonAnimationGuardTimerId)
    this.replyButtonAnimationGuardTimerId = -1
  }

  private applyReplyButtonAutoHideBinding(): void {
    if (this.replyButton.autoHide) {
      this.replyButtonController.bindScroller(0, this.scroller)
      this.restoreReplyButtonIfHidden()
      return
    }
    this.replyButtonController.unbindScroller(this.scroller)
    this.restoreReplyButtonIfHidden()
  }

  private startReplyButtonAnimationGuardTimer(): void {
    this.clearReplyButtonAnimationGuardTimer()
    this.replyButtonAnimationGuardTimerId = setTimeout((): void => {
      this.replyButtonAnimationGuardTimerId = -1
    }, this.TOPIC_DETAIL_REPLY_BUTTON_ANIMATION_GUARD_MS)
  }

  private restoreReplyButtonIfHidden(): void {
    if (this.replyButtonVisibleByScroll) {
      return
    }
    this.replyButtonVisibleByScroll = true
    this.replyButtonController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
  }

  private applyReplyButtonScrollAnimation(visible: boolean): void {
    if (
      !this.replyButton.autoHide ||
      this.replyButtonAnimationGuardTimerId !== -1 ||
      this.replyButtonVisibleByScroll === visible
    ) {
      return
    }
    this.replyButtonVisibleByScroll = visible
    if (visible) {
      this.replyButtonController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
    } else {
      this.replyButtonController.applyHideAnimation(HdsAnimationMode.SCROLL_ANIMATION)
    }
    this.startReplyButtonAnimationGuardTimer()
  }

  // Cache-driven ignore state: re-publish to the Index title bar whenever the ignored-topic
  // ledger changes (e.g. the user (un)ignores this topic, or another surface does).
  @Monitor('blockedStorage.ignoredTopicIdsJson')
  private onIgnoredListChanged(): void {
    this.publishTopicIgnoredState()
  }

  private isCurrentTopicIgnored(): boolean {
    if (this.topicId <= 0) {
      return false
    }
    try {
      const ids = JSON.parse(this.blockedStorage.ignoredTopicIdsJson || '[]') as number[]
      return ids.indexOf(this.topicId) >= 0
    } catch (_e) {
      return false
    }
  }

  // Single point that mirrors the cache-derived ignore state up to the Index title bar.
  private publishTopicIgnoredState(): void {
    publishTopicDetailTopicIgnored(this.isCurrentTopicIgnored(), this.topicId)
  }

  @Monitor('replyButton.autoHide')
  private onTopicDetailReplyButtonAutoHideChanged(): void {
    this.applyReplyButtonAutoHideBinding()
  }

  @Monitor('hotReplies.enabled', 'hotReplies.maxCount', 'hotReplies.minThanks')
  private onHotReplySettingsChanged(): void {
    this.triggerReplyPreloadIfNeeded()
  }

  // TOPIC_DETAIL_ACTION command bus (was the V1 TopicDetailActionListener child). Filter by topicId so a
  // command targeting another stacked page is ignored — preventing duplicate dialogs on underneath pages.
  @Monitor('topicAction.command')
  private onTopicActionCommand(): void {
    const command = TopicDetailActionCoordinator.parseCommand(this.topicAction.command)
    if (!command || command.topicId !== this.topicId) {
      return
    }
    this.handleTopicAction(command.action)
  }

  private applyReplyButtonAutoHideByScroll(offset: number, state: ScrollState): void {
    if (!this.replyButton.autoHide) {
      this.replyButtonLastScrollOffset = offset
      this.restoreReplyButtonIfHidden()
      return
    }
    if (offset <= this.TOPIC_DETAIL_REPLY_BUTTON_SCROLL_DELTA_PX) {
      this.replyButtonLastScrollOffset = offset
      this.restoreReplyButtonIfHidden()
      return
    }
    if (state === ScrollState.Idle) {
      this.replyButtonLastScrollOffset = offset
      return
    }
    const lastOffset = this.replyButtonLastScrollOffset
    this.replyButtonLastScrollOffset = offset
    const delta = offset - lastOffset
    const isReverseScroll = delta < -this.TOPIC_DETAIL_REPLY_BUTTON_SCROLL_DELTA_PX
    const isForwardScroll = delta > this.TOPIC_DETAIL_REPLY_BUTTON_SCROLL_DELTA_PX
    if (isReverseScroll) {
      this.applyReplyButtonScrollAnimation(true)
    } else if (isForwardScroll) {
      this.applyReplyButtonScrollAnimation(false)
    }
  }

  private trackReplyActionFollowOperation(event: TouchEvent): void {
    if (event.type !== TouchType.Down && !this.followTouchState.active) {
      return
    }
    const touch = event.touches[0] ?? event.changedTouches[0]
    if (!touch) {
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.followTouchState = TopicDetailFloatingActionCoordinator.initialTouchState()
      }
      return
    }
    const update = TopicDetailFloatingActionCoordinator.updateTouch(
      this.followTouchState,
      event.type,
      touch.x,
      touch.y,
      this.FOLLOW_OPERATION_VERTICAL_SCROLL_THRESHOLD,
      this.FOLLOW_OPERATION_VERTICAL_DOMINANCE_RATIO,
    )
    this.followTouchState = update.state
    if (update.shouldReport) {
      MotionHandStateService.reportFollowOperationX(update.reportX, this.detailRootWidth)
    }
  }

  @Monitor('motion.edge')
  private onMotionHandEdgeChanged(): void {
    // The reply/resume FAB Rows carry `.animation()` on their translate, so simply updating the
    // visual edge here lets the declarative property animation interpolate the slide. animateTo
    // invoked from inside a @Monitor callback does NOT capture the translate change (it hard-jumped
    // — the V1->V2 animation regression), so we drive the slide via .animation() instead.
    this.visualMotionHandEdge = this.motion.edge
  }

  @Builder ReplyComposerBarHost() {
    if (this.replyComposerVisible) {
      Stack({ alignContent: Alignment.Bottom }) {
        // Tap-outside catcher: dismiss the bar without submitting (the bar auto-saves its draft).
        Column()
          .width('100%')
          .height('100%')
          .onClick(() => {
            this.dismissReplyComposer()
          })
        this.ReplyComposerBarBuilder()
      }
      .width('100%')
      .height('100%')
      // Own ALL bottom insets ourselves: opt out of the framework's system/keyboard avoidance for
      // this overlay (paired with keyboard-avoid NONE set on open) so nothing moves the bar except
      // composerLift() below. This keeps the bar pinned directly above the keyboard on every device.
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])
      .padding({ bottom: this.composerLift() })
    }
  }

  private composerLift(): number {
    // Sole source of the bar's bottom lift (framework avoidance is disabled while composing): rest it
    // exactly on top of the keyboard when up. When the keyboard is down, lift is 0 so the bar drops to
    // the screen bottom and its own background covers the bottom safe area (ReplyComposerBar owns that
    // inset), instead of floating above the safe area and exposing the page content below.
    return this.layout.keyboardHeight > 0 ? this.layout.keyboardHeight : 0
  }

  @Builder ReplyContextSheetHost() {
    Blank()
      .width(1)
      .height(1)
      .bindSheet(
        $$this.contextSheetVisible,
        this.ReplyContextSheet(),
        defaultSheetOptions(SheetSize.LARGE, () => {
          this.contextSheetVisible = false
          this.contextReply = null
          this.contextItems = []
        }),
      )
  }

  @Builder LoadingView() {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE_LARGE)
        .height(ThemeConstants.LOADING_SIZE_LARGE)
        .color(ThemeConstants.BRAND_PRIMARY)
      Text(AppStrings.text($r('app.string.topic_detail_loading'), 'Loading...'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: ThemeConstants.SPACE_MD })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder ErrorView() {
    Column() {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
        .fontSize(48)
        .fontColor([$r('sys.color.font_secondary')])
      Text(
        this.v.errorMessage || AppStrings.text($r('app.string.common_load_failed'), 'Load failed'),
      )
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: ThemeConstants.SPACE_MD })
      Button(AppStrings.text($r('app.string.common_retry'), 'Retry'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => {
          this.reloadTopicWithThreadPreload()
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder ContentView() {
    PullRefreshListScaffold({
      scroller: this.scroller,
      scrollEnabled: this.listScrollEnabled,
      onRefresh: async () => {
        await this.v.load()
        this.triggerReplyPreloadIfNeeded()
      },
      onScrollEnableChange: (enabled: boolean) => {
        this.listScrollEnabled = enabled
      },
      onScrollIndex: (_start: number, end: number, center: number) => {
        this.handleReplyListScrollIndex(end, center)
      },
      onDidScroll: (offset: number, state: ScrollState) => {
        this.currentScrollOffset = Math.max(0, offset)
        this.evaluateAppbarIdentityVisibility()
        this.applyReplyButtonAutoHideByScroll(this.currentScrollOffset, state)
      },
      onReachEnd: () => {
        this.handleReplyListReachEnd()
      },
      canStartBottomRefresh: () => {
        return this.canTriggerBottomRefresh()
      },
      onBottomRefresh: async () => {
        await this.refreshLastRepliesPage()
      },
      bottomPadding: this.topicDetailBottomPadding(),
    }) {
      ListItem() {
        this.TopicCard()
      }

      ListItem() {
        this.HotRepliesPreview(this.hotReplyItems())
      }

      // Reply divider
      ListItem() {
        this.ReplyDivider()
      }

      // Reply list
      LazyForEach(
        this.v.replyDataSource,
        (reply: V2exReply, index: number) => {
          ListItem() {
            ReplyCard({
              reply: reply,
              floor: this.replyCardDisplayState(reply, index).floor,
              isOp: this.replyCardDisplayState(reply, index).isOp,
              isThanked: this.isReplyThanked(reply),
              isThankPending: this.isReplyThankPending(reply.id),
              threadLevel: this.replyCardDisplayState(reply, index).threadLevel,
              relationLabel: '',
              displayContent: this.replyCardDisplayState(reply, index).displayContent,
              childReplies: this.replyCardDisplayState(reply, index).childReplies,
              opMemberId: this.replyCardDisplayState(reply, index).opMemberId,
              hideLeadingMention: this.replyCardDisplayState(reply, index).hideLeadingMention,
              isReplyThanked: (target: V2exReply) => {
                return this.isReplyThanked(target)
              },
              isReplyThankPending: (target: V2exReply) => {
                return this.isReplyThankPending(target.id)
              },
              isWrongReference: this.replyCardDisplayState(reply, index).isWrongReference,
              isDuplicateThreadItem: this.replyCardDisplayState(reply, index).isDuplicateThreadItem,
              onUserClick: (target: V2exReply) => {
                let p: UserProfileParams = { username: target.member.username }
                this.stack.pushPathByName('UserProfile', p as Object)
              },
              onContextClick: (target: V2exReply) => {
                this.openReplyContext(target)
              },
              onMentionClick: (target: V2exReply) => {
                this.openReplyEditor(this.getReplyMentionText(target, index))
              },
              onReplyClick: (target: V2exReply) => {
                this.openReplyEditor(this.getReplyMentionText(target, index))
              },
              onThankClick: (target: V2exReply) => {
                this.prepareReplyThank(target)
              },
              onIgnoreClick: (target: V2exReply) => {
                this.prepareReplyIgnore(target)
              },
              onReportClick: (target: V2exReply) => {
                this.prepareReplyReport(target)
              },
              onCopyUserClick: (target: V2exReply) => {
                this.copyToClipboard(target.member.username || '')
              },
              onCopyContentClick: (target: V2exReply) => {
                this.copyToClipboard(target.content || '')
              },
              onImageClick: (url: string) => {
                this.openImagePreview(url)
              },
              onLinkClick: (url: string) => {
                this.openContentLink(url)
              },
              onMentionUserClick: (username: string) => {
                this.openUserProfile(username)
              },
            })
          }
        },
        (reply: V2exReply) => reply.renderKey || reply.id.toString(),
      )

      if (this.v.isPreloadingAll) {
        ListItem() {
          TopicRepliesPreloadIndicator({ text: this.v.preloadProgress })
        }
      }

      if (this.v.shouldShowRepliesFooter()) {
        ListItem() {
          LoadingFooter({
            isLoading: this.v.isRepliesLoadingMore,
            hasMore: this.v.repliesHasMore,
            isError: this.v.repliesLoadMoreState === 'loadMoreError',
            onRetry: () => {
              this.retryLoadMoreReplies()
            },
          })
        }
      }
    }
  }

  @Builder ReplyComposerBarBuilder() {
    ReplyComposerBar({
      topicId: this.topicId,
      initialContent: this.replyComposerInitialContent,
      closeAction: () => {
        this.dismissReplyComposer()
      },
      submitAction: (content: string) => {
        this.submitReplyFromComposer(content)
      },
    }).width('100%')
  }

  // Owns the reply network submit. The composer sheet has already emitted a clean snapshot and is
  // closed by this method BEFORE the request starts, so the TextArea can't re-grab focus or re-open
  // the soft keyboard while the request is pending. The draft was persisted by the sheet, so a
  // failure keeps the user's text; success clears it. Auth/2FA/session errors are surfaced via the
  // translated toast — never swallowed or converted into a confirmation bypass.
  private submitReplyFromComposer(content: string): void {
    if (this.isReplySubmitting) {
      return
    }
    const cleanContent = (content || '').trim()
    if (cleanContent.length === 0 || this.topicId <= 0) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction
        .openToast({
          message: AppStrings.text($r('app.string.reply_login_required'), 'Log in first'),
        })
        .catch((_error: Error) => {})
      return
    }
    // Close the composer first (focus/keyboard fix), then open the system LoadingDialog before
    // starting the network request.
    this.replyComposerVisible = false
    this.replyComposerInitialContent = ''
    // Restore the page keyboard-avoid mode we switched off while the bar was open.
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    this.isReplySubmitting = true
    this.replySubmitLoadingDialogController.open()
    this.api
      .submitReplyWithCookie(cookie, this.topicId, cleanContent)
      .then(() => {
        this.clearReplyDraftAfterSuccess()
        // The posted reply lands on the LAST replies page; the wrapper re-preloads the thread
        // tail after the page-1 reload so the new reply is actually fetched and shown.
        this.reloadTopicWithThreadPreload()
      })
      .catch((error: Error) => {
        // Keep the draft and surface the (translated) error. Do NOT auto-reopen the composer:
        // the sheet's TextArea auto-focuses on open and would re-trigger the keyboard the user
        // was trying to avoid; they can tap reply manually to resume from the saved draft.
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.replySubmitLoadingDialogController.close()
        this.isReplySubmitting = false
      })
  }

  private clearReplyDraftAfterSuccess(): void {
    if (this.topicId <= 0) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReplyComposerDraftCoordinator.clearDraft(context, this.topicId).catch((_error: Error) => {})
  }

  private topicDetailBottomPadding(): number {
    return ThemeConstants.SPACE_XL + this.HDS_ACTION_BAR_CLEARANCE
  }

  private areaLength(value: Length | undefined): number {
    return TopicDetailAppbarCoordinator.areaLength(value)
  }

  private areaY(value: Length | undefined): number {
    return TopicDetailAppbarCoordinator.areaY(value)
  }

  private evaluateAppbarIdentityVisibility(): void {
    const result = TopicDetailAppbarCoordinator.evaluateVisibility({
      hasTopic: !!this.v.topic,
      titleContentBottom: this.titleContentBottom,
      currentScrollOffset: this.currentScrollOffset,
      appbarBottom: this.layout.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT,
      hysteresis: this.titleVisibilityHysteresis,
      currentlyVisible: this.isTitleCoveredByAppbar,
    })
    if (!result.shouldPublish) {
      return
    }
    this.isTitleCoveredByAppbar = result.visible
    this.publishAppbarIdentity(result.visible)
  }

  private republishAppbarIdentity(): void {
    this.evaluateAppbarIdentityVisibility()
    this.publishAppbarIdentity(this.isTitleCoveredByAppbar)
  }

  private publishAppbarIdentity(visible: boolean): void {
    const routeKey = this.topicRouteKey()
    if (!routeKey) {
      return
    }
    const identity = TopicDetailAppbarCoordinator.identity(this.v.topic, visible)
    // The per-route *_STATES maps are read-modify-written against the live V2 TopicDetailAppbarState
    // mirror (the write-through publish* helpers keep it current) so a new TopicDetailPage instance
    // never clobbers sibling nav-stack entries' identities; the @ComponentV2 Index appbar reads the
    // same mirror.
    const appbar = connectTopicDetailAppbar()
    publishTopicDetailAppbarTitleStates(
      TopicDetailAppbarCoordinator.nextStringState(appbar.titleStates, routeKey, identity.title),
    )
    publishTopicDetailAppbarAvatarStates(
      TopicDetailAppbarCoordinator.nextStringState(
        appbar.avatarStates,
        routeKey,
        identity.avatarUrl,
      ),
    )
    publishTopicDetailAppbarUsernameStates(
      TopicDetailAppbarCoordinator.nextStringState(
        appbar.usernameStates,
        routeKey,
        identity.username,
      ),
    )
    publishTopicDetailAppbarRouteTopicId(visible ? routeKey : '')
    publishTopicDetailAppbarTitle(identity.title)
    publishTopicDetailAppbarAvatarUrl(identity.avatarUrl)
    publishTopicDetailAppbarUsername(identity.username)
  }

  private topicRouteKey(): string {
    return TopicDetailAppbarCoordinator.routeKey(this.topicId)
  }

  @Builder TopicCard() {
    Column() {
      TopicDetailHeader({
        topic: this.v.topic!,
        onUserClick: () => {
          let p: UserProfileParams = { username: this.v.topic!.member.username }
          this.stack.pushPathByName('UserProfile', p as Object)
        },
        onNodeClick: () => {
          let p: NodeTopicListParams = {
            nodeName: this.v.topic!.node.name,
            nodeTitle: this.v.topic!.node.title,
          }
          this.stack.pushPathByName('NodeTopicList', p as Object)
        },
        onTitleAreaChange: (_oldValue: Area, newValue: Area) => {
          const measuredGlobalBottom =
            this.areaY(newValue?.globalPosition?.y) + this.areaLength(newValue?.height)
          this.titleContentBottom = measuredGlobalBottom + this.currentScrollOffset
          this.evaluateAppbarIdentityVisibility()
        },
      })

      // Topic body
      if (this.topicBodyBlocks().length > 0) {
        ForEach(
          this.topicBodyBlocks(),
          (block: string, index: number) => {
            MarkdownContent({
              source: block,
              topMargin: index === 0 ? ThemeConstants.SPACE_LG : ThemeConstants.SPACE_SM,
              onImageClick: (url: string) => {
                this.openImagePreview(url)
              },
              onLinkClick: (url: string) => {
                this.openContentLink(url)
              },
              onMentionClick: (username: string) => {
                this.openUserProfile(username)
              },
            })
          },
          (block: string, index: number) => `${index}-${block.length}-${block.slice(0, 16)}`,
        )
      }

      if (this.v.topic!.topicSupplementMarkdown) {
        Divider()
          .strokeWidth(1)
          .color($r('sys.color.ohos_id_color_list_separator'))
          .margin({ top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_XS })
        ForEach(
          this.topicSupplementBlocks(),
          (block: TopicSupplementBlock, index: number) => {
            Column() {
              Text(block.meta)
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontColor($r('sys.color.font_secondary'))
                .width('100%')
              if (block.bodyBlocks.length > 0) {
                ForEach(
                  block.bodyBlocks,
                  (bodyBlock: string, bodyIndex: number) => {
                    MarkdownContent({
                      source: bodyBlock,
                      topMargin:
                        bodyIndex === 0 ? ThemeConstants.SPACE_XS : ThemeConstants.SPACE_SM,
                      onImageClick: (url: string) => {
                        this.openImagePreview(url)
                      },
                      onLinkClick: (url: string) => {
                        this.openContentLink(url)
                      },
                      onMentionClick: (username: string) => {
                        this.openUserProfile(username)
                      },
                    })
                  },
                  (bodyBlock: string, bodyIndex: number) =>
                    `${bodyIndex}-${bodyBlock.length}-${bodyBlock.slice(0, 16)}`,
                )
              }
            }
            .width('100%')
            .margin({ top: index === 0 ? 0 : ThemeConstants.SPACE_MD })
          },
          (block: TopicSupplementBlock) => block.key,
        )
      }

    }
    .padding(this.topicCardPadding())
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('app.color.card_background'))
  }

  private topicBodyBlocks(): string[] {
    return TopicDetailContentCoordinator.topicBodyBlocks(this.v.topic)
  }

  private topicSupplementBlocks(): TopicSupplementBlock[] {
    return TopicDetailContentCoordinator.topicSupplementBlocks(
      this.v.topic?.topicSupplementMarkdown || '',
    )
  }

  private hotReplyItems(): V2exReply[] {
    return this.v.getHotReplies(
      this.hotReplies.enabled,
      this.hotReplies.maxCount,
      this.hotReplies.minThanks,
    )
  }

  @Builder HotRepliesPreview(items: V2exReply[]) {
    if (items.length > 0) {
      HotRepliesPanel({
        replies: items,
        minThanks: this.hotReplies.minThanks,
        opMemberId: this.v.topic?.member.id || 0,
        expanded: this.hotRepliesExpanded,
        onExpandedChange: (expanded: boolean) => {
          this.hotRepliesExpanded = expanded
        },
        onJumpClick: (reply: V2exReply) => {
          this.jumpToLoadedReplyFloor(reply.floor || 0)
        },
        onUserClick: (username: string) => {
          this.openUserProfile(username)
        },
        onContextClick: (reply: V2exReply) => {
          this.openReplyContext(reply)
        },
        onReplyClick: (reply: V2exReply) => {
          this.openReplyEditor(this.getReplyMentionText(reply, Math.max(0, (reply.floor || 1) - 1)))
        },
        onThankClick: (reply: V2exReply) => {
          this.prepareReplyThank(reply)
        },
        onIgnoreClick: (reply: V2exReply) => {
          this.prepareReplyIgnore(reply)
        },
        onReportClick: (reply: V2exReply) => {
          this.prepareReplyReport(reply)
        },
        onCopyUserClick: (reply: V2exReply) => {
          this.copyToClipboard(reply.member.username || '')
        },
        onCopyContentClick: (reply: V2exReply) => {
          this.copyToClipboard(reply.content || '')
        },
        isReplyThanked: (reply: V2exReply) => {
          return this.isReplyThanked(reply)
        },
        isReplyThankPending: (reply: V2exReply) => {
          return this.isReplyThankPending(reply.id)
        },
        onImageClick: (url: string) => {
          this.openImagePreview(url)
        },
        onLinkClick: (url: string) => {
          this.openContentLink(url)
        },
      })
    }
  }

  @Builder ReplyDivider() {
    TopicDetailReplyDivider({
      replyDisplayMenuShown: this.replyDisplayMenuShown,
      onReplyDisplayMenuShownChange: (value: boolean) => {
        this.replyDisplayMenuShown = value
      },
      replyCountText: this.replyCountText(),
      replyDisplayMode: this.v.replyDisplayMode,
      replyDisplayModeText: this.replyDisplayModeText(),
      onJumpToFloor: () => {
        this.openJumpToFloorDialog()
      },
      onLatest: () => {
        this.scrollToLatestReply()
      },
      onShowDisplayMenu: () => {
        this.showReplyDisplayMenu()
      },
      onDisplayModeChange: (mode: string) => {
        this.updateReplyDisplayMode(mode)
      },
    })
  }

  @Builder ReplyContextSheet() {
    ReplyContextSheetContent({
      title: this.replyContextTitle(),
      closeAction: () => {
        this.closeReplyContext()
      },
    }) {
      ForEach(
        this.contextItems,
        (item: ReplyContextItem) => {
          ListItem() {
            this.ReplyContextItemView(item)
          }
        },
        (item: ReplyContextItem) => `${item.reply.id}-${item.floor}-${item.label}`,
      )
    }
  }

  @Builder ReplyContextItemView(item: ReplyContextItem) {
    ReplyContextListItem({
      reply: item.reply,
      floor: item.floor,
      label: item.label,
      selected: item.selected,
      snippet: this.replySnippet(item.reply.content),
      bodyFontSize: this.bodyFontSize(),
      bodyLineHeight: this.bodyLineHeight(),
      onSelect: () => {
        this.jumpToLoadedReplyFloor(item.floor)
        this.closeReplyContext()
      },
    })
  }

  private openReplyContext(reply: V2exReply): void {
    this.contextReply = reply
    this.contextItems = this.buildReplyContextItems(reply)
    setTimeout(() => {
      this.contextSheetVisible = true
    }, 240)
  }

  private closeReplyContext(): void {
    this.contextSheetVisible = false
    this.contextItems = []
  }

  private replyContextTitle(): string {
    return ReplyContextCoordinator.title(this.contextReply, (replyId: number) =>
      this.v.getReplyFloor(replyId),
    )
  }

  private buildReplyContextItems(selected: V2exReply): ReplyContextItem[] {
    return ReplyContextCoordinator.build({
      selected: selected,
      selectedFloor: this.v.getReplyFloor(selected.id),
      replies: this.v.getLoadedRepliesSnapshot(),
      getReplyFloor: (replyId: number) => this.v.getReplyFloor(replyId),
    })
  }

  private replySnippet(content: string): string {
    return ReplyContextCoordinator.snippet(content)
  }

  private jumpToLoadedReplyFloor(floor: number): void {
    if (floor <= 0) {
      return
    }
    if (this.v.onlyOp) {
      this.v.setOnlyOp(false)
    }
    // Defer a tick so an onlyOp toggle re-publishes the data source before we resolve the floor's row.
    setTimeout(() => {
      this.jumpToFloorIndex(floor)
    }, 0)
  }

  // Resolve a floor to its ACTUAL displayed row and scroll there. Under 楼中楼 reordering a nested reply
  // has no top-level row of its own, so it resolves to the row that contains it (its ancestor) instead of
  // a chronological 2+floor guess that lands near the end. Falls back to the list end when the floor isn't
  // in the loaded data.
  private jumpToFloorIndex(floor: number): void {
    if (floor <= 0) {
      return
    }
    const source = this.v.replyDataSource
    const listIndex = TopicDetailScrollCoordinator.listIndexForFloor(
      floor,
      source.totalCount(),
      (index: number) => source.getData(index),
    )
    const target = listIndex >= 0 ? listIndex : this.lastReplyListIndex()
    if (target <= 0) {
      return
    }
    try {
      this.scrollToListIndex(target, true)
    } catch (_e) {
      // ignore
    }
  }

  private scrollToTop(): void {
    try {
      this.scroller.scrollEdge(Edge.Top)
    } catch (_e) {
      // ignore
    }
  }

  private scrollToLatestReply(): void {
    const count = this.v.replyDataSource.totalCount()
    if (count <= 0) {
      return
    }
    const listIndex = 2 + count
    try {
      this.scrollToListIndex(listIndex, true)
    } catch (_e) {
      // ignore
    }
  }

  // Full reloads via load() reset the reply list to page 1 and DISCARD any preloaded pages — in
  // thread mode the tail (e.g. a reply just posted, which lands on the LAST page) would silently
  // vanish until a manual load-more. Every non-initial reload trigger (reply submit, move node,
  // moderation actions, error retry) must use this wrapper so thread preload is re-triggered
  // afterwards, mirroring the initial-load path including its >limit confirm dialog.
  private reloadTopicWithThreadPreload(): Promise<void> {
    return this.v.load().then(() => {
      this.triggerReplyPreloadIfNeeded()
    })
  }

  private triggerReplyPreloadIfNeeded(): void {
    this.v.triggerThreadPreloadIfNeeded(this.hotReplies.enabled)
    if (this.v.needsPreloadConfirm) {
      this.showPreloadConfirmDialog()
    }
  }

  private loadMoreReplies(): void {
    this.v.loadMoreReplies()
  }

  private retryLoadMoreReplies(): void {
    this.v.retryLoadMoreReplies()
  }

  private refreshLastRepliesPage(): Promise<void> {
    return this.v
      .refreshLastRepliesPage()
      .then(() => {})
      .catch((error: Error) => {
        promptAction
          .openToast({ message: translateApiError(error) })
          .catch((_toastError: Error) => {})
      })
  }

  private canTriggerBottomRefresh(): boolean {
    // Pixel-true scroll-to-bottom is now enforced inside PullRefresh
    // (isListAtBottom via Scroller.isAtEnd). This gate only expresses
    // business state: refresh not already running, last page reached, etc.
    // isReplyListAtEnd intentionally NOT consulted here — it's a loose
    // "last item visible" signal owned by auto-pagination and would
    // re-introduce the false-trigger bug.
    return this.v.canBottomRefresh()
  }

  private handleReplyListReachEnd(): void {
    this.isReplyListAtEnd = true
    this.loadMoreReplies()
  }

  private handleReplyListScrollIndex(end: number, center: number): void {
    this.updateReadFloor(center)
    const lastReplyIndex = this.lastReplyListIndex()
    this.isReplyListAtEnd = lastReplyIndex > 0 && end >= lastReplyIndex
    if (lastReplyIndex > 0 && end >= lastReplyIndex - 3) {
      this.loadMoreReplies()
    }
  }

  private lastReplyListIndex(): number {
    return TopicDetailScrollCoordinator.lastReplyListIndex(this.v.replyDataSource.totalCount())
  }

  private replyCountText(): string {
    return TopicDetailReplyDisplayCoordinator.replyCountText(
      this.v.topic?.replies ?? 0,
      this.v.repliesLoaded,
    )
  }

  private toggleOnlyOp(): void {
    this.updateReplyDisplayMode(
      this.v.onlyOp ? ReplyDisplaySettings.MODE_THREAD : ReplyDisplaySettings.MODE_OP,
    )
  }

  private currentReplyDisplayMode(): string {
    // Persisted reply-display mode is seeded non-reactively (the page renders off v.replyDisplayMode);
    // read the durable V2 ReplyDisplayState mirror instead of AppStorage.
    return ReplyDisplaySettings.normalizeMode(connectReplyDisplay().mode)
  }

  private updateReplyDisplayMode(mode: string): void {
    const normalizedMode = ReplyDisplaySettings.normalizeMode(mode)
    if (
      TopicDetailReplyDisplayCoordinator.shouldPreloadForMode(
        normalizedMode,
        this.v.allRepliesLoaded,
        this.v.repliesHasMore,
      )
    ) {
      this.v.switchToThreadModeAndPreload(normalizedMode)
    } else {
      this.v.setReplyDisplayMode(normalizedMode)
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReplyDisplaySettings.save(context, normalizedMode).catch((error: Error) => {
      console.error('save reply display mode failed: ' + error.message)
    })
  }

  private showReplyDisplayMenu(): void {
    this.replyDisplayMenuShown = false
    setTimeout(() => {
      this.replyDisplayMenuShown = true
    }, 20)
  }

  private replyDisplayModeText(): string {
    return TopicDetailReplyDisplayCoordinator.modeText(this.v.replyDisplayMode)
  }

  private replyCardDisplayState(reply: V2exReply, index: number): TopicDetailReplyCardDisplayState {
    return TopicDetailReplyDisplayCoordinator.replyCardDisplayState(
      reply,
      this.v.topic,
      this.v.getReplyFloor(reply.id),
      index,
      this.v.replyDisplayMode,
    )
  }

  private getFloorForReply(replyId: number, index: number): number {
    return TopicDetailReplyDisplayCoordinator.floorForReply(this.v.getReplyFloor(replyId), index)
  }

  private getReplyMentionText(reply: V2exReply, fallbackIndex: number): string {
    return TopicDetailReplyDisplayCoordinator.mentionText(
      reply.member.username,
      this.getFloorForReply(reply.id, fallbackIndex),
    )
  }

  private openJumpToFloorDialog(): void {
    if (this.v.topic === null) {
      return
    }
    this.jumpFloorText = ''
    this.jumpFloorDialogController.open()
  }

  private closeJumpToFloorDialog(): void {
    try {
      this.jumpFloorDialogController.close()
    } catch (_error) {
      // Dialog may already be dismissed by tapping outside.
    }
  }

  private normalizeJumpFloorInput(value: string): string {
    return (value || '').replace(/[^0-9]/g, '')
  }

  @Builder
  JumpToFloorDialogContent() {
    TextInput({
      placeholder: $r('app.string.jump_to_floor_placeholder'),
      text: this.jumpFloorText,
    })
      .type(InputType.Number)
      .inputFilter('^[0-9]*$')
      .defaultFocus(true)
      .width('100%')
      .onChange((value: string) => {
        this.jumpFloorText = this.normalizeJumpFloorInput(value)
      })
  }

  private handleJumpToFloor(value: string): void {
    const maxFloor = this.v.topic !== null ? this.v.topic!.replies : 0
    const result = TopicDetailScrollCoordinator.parseJumpFloor(value, maxFloor)
    if (!result.valid) {
      promptAction.openToast({ message: result.message }).catch((_error: Error) => {})
      return
    }
    this.ensureRepliesLoaded(result.floor)
      .then(() => {
        this.jumpToFloorIndex(result.floor)
      })
      .catch((_error: Error) => {
        // ignore
      })
  }

  private updateReadFloor(centerIndex: number): void {
    const replyIndex = TopicDetailScrollCoordinator.replyIndexFromCenterListIndex(centerIndex)
    if (replyIndex < 0 || replyIndex >= this.v.replyDataSource.totalCount()) {
      return
    }
    try {
      const reply = this.v.replyDataSource.getData(replyIndex)
      const floor = this.v.getReplyFloor(reply.id)
      if (floor > 0) {
        this.lastReadFloor = floor
        this.maybeDismissResumeButton(floor)
      }
    } catch (_e) {
      // ignore
    }
  }

  // Auto-dismiss the resume affordance once the user scrolls the saved floor into view on their own,
  // so it doesn't linger after it has effectively been satisfied.
  private maybeDismissResumeButton(centerFloor: number): void {
    if (!this.showResumeButton || this.resumeSavedFloor <= 0) {
      return
    }
    if (centerFloor >= this.resumeSavedFloor - this.RESUME_BUTTON_FLOOR_PROXIMITY) {
      this.showResumeButton = false
    }
  }

  private persistReadPosition(): void {
    if (this.topicId <= 0 || this.lastReadFloor <= 0) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.saveTopicReadFloor(context, this.topicId, this.lastReadFloor).catch(
      (error: Error) => {
        console.error('save read position failed: ' + error.message)
      },
    )
  }

  // IT-Home-style restore: do NOT auto-scroll to the saved floor on entry. Instead pre-load the
  // replies up to that floor (so the later tap can land precisely) and surface the resume button.
  // The user is left at the top; tapping the button performs the actual jump.
  private restoreReadPosition(): void {
    if (this.hasRestoredReadPosition || this.topicId <= 0) {
      return
    }
    this.hasRestoredReadPosition = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.getTopicReadFloor(context, this.topicId)
      .then(async (floor: number) => {
        if (floor <= 0) {
          return
        }
        await this.ensureRepliesLoaded(floor)
        this.resumeSavedFloor = floor
        this.resumeTargetFloor = floor
        // Only offer the resume button while the user is still at the top. If they already scrolled
        // past the saved floor (or anywhere meaningful) by the time replies finished loading, the
        // affordance would be noise.
        if (this.currentScrollOffset <= this.TOPIC_DETAIL_REPLY_BUTTON_SCROLL_DELTA_PX) {
          this.showResumeButton = true
        }
      })
      .catch((_error: Error) => {
        // ignore
      })
  }

  // Resume button tap: jump to the saved floor and consume the affordance.
  private resumeToSavedFloor(): void {
    this.showResumeButton = false
    const targetFloor = this.resumeTargetFloor
    if (targetFloor <= 0) {
      return
    }
    setTimeout(() => {
      this.jumpToFloorIndex(targetFloor)
    }, 0)
  }

  private restoreInitialPosition(): void {
    const target = Math.floor(this.targetFloor)
    if (target > 0) {
      this.jumpToTargetFloor(target)
      return
    }
    if (!this.reading.restorePosition) {
      return
    }
    this.restoreReadPosition()
  }

  private jumpToTargetFloor(floor: number): void {
    if (this.hasJumpedToTargetFloor || floor <= 0) {
      return
    }
    this.hasJumpedToTargetFloor = true
    this.ensureRepliesLoaded(floor)
      // The reply a notification points at can sit on a later page than the (unreliable) anchor
      // would load; pull pages until it is present so the content match below can actually see it.
      .then(() => this.v.loadUntilReplyContent(this.verifyReplyText))
      .then(() => {
        // V2EX's #reply anchor can be wrong; re-resolve against the notification's reply text.
        const resolved = TopicDetailScrollCoordinator.verifiedFloor(
          floor,
          this.verifyReplyText,
          this.v.getLoadedRepliesSnapshot(),
        )
        this.jumpToLoadedReplyFloor(resolved)
      })
      .catch((_error: Error) => {
        // ignore
      })
  }

  private scrollToListIndex(index: number, smooth: boolean = false): void {
    this.scroller.scrollToIndex(index, smooth, ScrollAlign.START)
  }

  private async ensureRepliesLoaded(targetFloor: number): Promise<void> {
    await TopicDetailScrollCoordinator.ensureRepliesLoaded(
      targetFloor,
      this.v.repliesUseV2,
      () => this.v.replyDataSource.totalCount(),
      () => this.v.repliesHasMore,
      () => this.v.loadMoreReplies(),
    )
  }

  private loadSavedState(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.isTopicSaved(context, this.topicId)
      .then((saved: boolean) => {
        this.isSavedLater = saved
        publishTopicDetailSavedLater(saved)
      })
      .catch((error: Error) => {
        console.error('load saved topic state failed: ' + error.message)
      })
  }

  private toggleSavedLater(): void {
    if (this.v.topic === null) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const request = this.isSavedLater
      ? CollectionSettings.removeTopic(context, this.v.topic.id)
      : CollectionSettings.saveTopic(context, this.v.topic)
    request
      .then(() => {
        this.isSavedLater = !this.isSavedLater
        publishTopicDetailSavedLater(this.isSavedLater)
      })
      .catch((error: Error) => {
        console.error('toggle saved topic failed: ' + error.message)
      })
  }

  private recordViewedTopic(): void {
    if (this.v.topic === null) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.recordViewedTopic(context, this.v.topic).catch((error: Error) => {
      console.error('record viewed topic failed: ' + error.message)
    })
  }

  private markTopicReadState(): void {
    if (this.v.topic === null) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.markTopicRead(context, this.v.topic.id, this.v.topic.last_touched).catch(
      (error: Error) => {
        console.error('mark topic read failed: ' + error.message)
      },
    )
  }

  private handleTopicAction(action: string): void {
    if (this.v.topic === null) {
      promptAction
        .openToast({
          message: AppStrings.text($r('app.string.topic_still_loading'), 'Topic is still loading'),
        })
        .catch((_error: Error) => {})
      return
    }
    if (action === 'siteFavorite') {
      this.prepareSiteFavoriteToggle()
      return
    }
    if (action === 'thankTopic') {
      this.prepareTopicThank()
      return
    }
    if (action === 'ignoreTopic') {
      // The page can't tell us ignore state (web bug); the cache can. Toggle accordingly.
      if (this.isCurrentTopicIgnored()) {
        this.prepareTopicUnignore()
      } else {
        this.prepareTopicIgnore()
      }
      return
    }
    if (action === 'reportTopic') {
      this.prepareTopicReport()
      return
    }
    if (action === 'reply') {
      this.openReplyEditor()
      return
    }
    if (action === 'appendTopic') {
      this.openAppendEditor()
      return
    }
    if (action === 'editTopic') {
      this.openEditEditor()
      return
    }
    if (action === 'moveTopic') {
      this.openMoveNode()
      return
    }
    if (action === 'saveLater') {
      this.toggleSavedLater()
    } else if (action === 'copyTitle') {
      this.copyToClipboard(this.v.topic!.title || '')
    } else if (action === 'copyLink') {
      this.copyToClipboard(this.getTopicUrl())
    } else if (action === 'share') {
      this.shareTopic()
    } else if (action === 'openInApp') {
      this.openInAppWebView(this.getTopicUrl())
    } else if (action === 'openBrowser') {
      this.openInSystemBrowser(this.getTopicUrl())
    } else if (action === 'copyContent') {
      this.copyToClipboard(this.v.topic!.content || '')
    }
  }

  private prepareSiteFavoriteToggle(): void {
    if (this.isSiteFavoriteLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction
        .openToast({
          message: AppStrings.text($r('app.string.api_error_auth_required'), 'Please sign in'),
        })
        .catch((_error: Error) => {})
      return
    }
    const previousIsSiteFavorited = this.isSiteFavorited
    const targetFavorited = !this.isSiteFavorited
    this.isSiteFavoriteLoading = true
    this.isSiteFavorited = targetFavorited
    publishTopicDetailSiteFavorited(targetFavorited)
    this.api
      .toggleTopicFavoriteWithCookie(cookie, this.topicId)
      .then((favorited: boolean) => {
        this.isSiteFavorited = favorited
        publishTopicDetailSiteFavorited(favorited)
        this.persistTopicFavoriteOverlay(favorited)
      })
      .catch((error: Error) => {
        // Rollback failed optimistic action and leave durable overlay unchanged so stale private
        // account state never overwrites the server-confirmed cache with a failed mutation.
        this.isSiteFavorited = previousIsSiteFavorited
        publishTopicDetailSiteFavorited(previousIsSiteFavorited)
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.isSiteFavoriteLoading = false
      })
  }

  private loadSiteFavoriteState(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.topicId <= 0) {
      if (this.topicActionOverlay?.favoriteKnown) {
        return
      }
      this.isSiteFavorited = false
      publishTopicDetailSiteFavorited(false)
      return
    }
    this.api
      .getTopicFavoriteToggleActionWithCookie(cookie, this.topicId)
      .then((toggle: V2exToggleAction) => {
        this.isSiteFavorited = toggle.currentlyOn
        publishTopicDetailSiteFavorited(toggle.currentlyOn)
      })
      .catch((_error: Error) => {
        if (this.topicActionOverlay?.favoriteKnown) {
          return
        }
        this.isSiteFavorited = false
        publishTopicDetailSiteFavorited(false)
      })
  }

  private loadTopicThankState(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.topicId <= 0) {
      if (this.topicActionOverlay?.topicThankKnown) {
        return
      }
      this.isTopicThanked = false
      publishTopicDetailThanked(false)
      return
    }
    this.api
      .getTopicThankActionWithCookie(cookie, this.topicId)
      .then((_action: V2exTopicThankAction) => {
        if (this.topicActionOverlay?.topicThankKnown) {
          return
        }
        this.isTopicThanked = false
        publishTopicDetailThanked(false)
      })
      .catch((error: Error) => {
        const thanked = TopicDetailActionCoordinator.thankedFromTopicThankLoadError(error)
        if (!thanked && this.topicActionOverlay?.topicThankKnown) {
          return
        }
        this.isTopicThanked = thanked
        publishTopicDetailThanked(thanked)
      })
  }

  private showPreloadConfirmDialog(): void {
    const total = this.v.topic?.replies || 0
    this.getUIContext().showAlertDialog({
      title: AppStrings.text($r('app.string.topic_many_replies_title'), 'Many replies'),
      message: AppStrings.format(
        AppStrings.text(
          $r('app.string.load_all_replies_warning_format'),
          'This topic has {0} replies. Loading all replies may take some time.\n\nContinue loading to enable the full threaded view?',
        ),
        [`${total}`],
      ),
      primaryButton: {
        value: AppStrings.text($r('app.string.topic_flat_view'), 'Flat view'),
        action: () => {
          this.v.confirmPreloadFallbackFlat()
        },
      },
      secondaryButton: {
        value: AppStrings.text($r('app.string.topic_continue_loading'), 'Continue loading'),
        action: () => {
          this.v.confirmPreloadAll()
        },
      },
    })
  }

  private prepareTopicThank(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    const guard = TopicDetailActionCoordinator.topicThankGuard({
      locked: this.topicThankLocked,
      loading: this.isTopicThankLoading,
      thanked: this.isTopicThanked,
      storageThanked: connectTopicDetailAppbar().thanked,
      cookie,
    })
    if (!guard.allowed) {
      if (guard.message) {
        promptAction.openToast({ message: guard.message }).catch((_error: Error) => {})
      }
      return
    }
    this.topicThankLocked = true
    this.confirmTopicThank(cookie)
  }

  private confirmTopicThank(cookie: string): void {
    this.getUIContext().showAlertDialog({
      title: AppStrings.text($r('app.string.topic_action_thank_topic'), 'Thank topic'),
      message: TopicDetailActionCoordinator.topicThankMessage(this.v.topic?.title || ''),
      autoCancel: false,
      primaryButton: {
        value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
        action: () => {
          this.topicThankLocked = false
        },
      },
      secondaryButton: {
        value: AppStrings.text($r('app.string.action_thank'), 'Thank'),
        action: () => {
          this.executeTopicThank(cookie)
        },
      },
    })
  }

  private executeTopicThank(cookie: string): void {
    if (this.isTopicThankLoading) {
      return
    }
    const previousIsTopicThanked = this.isTopicThanked
    this.isTopicThankLoading = true
    this.isTopicThanked = true
    publishTopicDetailThanked(true)
    TopicDetailActionCoordinator.executeTopicThank(this.api, cookie, this.topicId)
      .then(() => {
        this.isTopicThanked = true
        publishTopicDetailThanked(true)
        this.persistTopicThankOverlay()
      })
      .catch((error: Error) => {
        this.isTopicThanked = previousIsTopicThanked
        publishTopicDetailThanked(previousIsTopicThanked)
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.isTopicThankLoading = false
        this.topicThankLocked = false
      })
  }

  private syncTopicDetailTitleState(
    savedLater: boolean,
    siteFavorited: boolean,
    thanked: boolean,
  ): void {
    this.isSavedLater = savedLater
    this.isSiteFavorited = siteFavorited
    this.isTopicThanked = thanked
    publishTopicDetailSavedLater(savedLater)
    publishTopicDetailSiteFavorited(siteFavorited)
    publishTopicDetailThanked(thanked)
  }

  private prepareReplyThank(reply: V2exReply): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    const guard = TopicDetailActionCoordinator.replyThankGuard({
      loading: this.isReplyThankLoading,
      lockedReplyId: this.replyThankLockedId,
      reply,
      thanked: TopicDetailActionCoordinator.isReplyThankedForGuard(
        reply,
        this.v.getLoadedRepliesSnapshot(),
        this.thankedReplyIdsJson,
      ),
      cookie,
    })
    if (!guard.allowed) {
      if (guard.message) {
        promptAction.openToast({ message: guard.message }).catch((_error: Error) => {})
      }
      return
    }
    const lockState = TopicDetailActionCoordinator.replyThankLockState(reply)
    this.replyThankLockedId = lockState.lockedReplyId
    this.pendingReplyThankId = lockState.pendingReplyThankId
    this.confirmReplyThank(cookie, reply)
  }

  private confirmReplyThank(cookie: string, reply: V2exReply): void {
    this.getUIContext().showAlertDialog({
      title: AppStrings.text($r('app.string.reply_thank_title'), 'Thank reply'),
      message: TopicDetailActionCoordinator.replyThankMessage(reply.member.username),
      autoCancel: false,
      primaryButton: {
        value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
        action: () => {
          this.clearReplyThankLock()
        },
      },
      secondaryButton: {
        value: AppStrings.text($r('app.string.action_thank'), 'Thank'),
        action: () => {
          this.executeReplyThank(cookie, reply)
        },
      },
    })
  }

  private executeReplyThank(cookie: string, reply: V2exReply): void {
    if (this.isReplyThankLoading) {
      return
    }
    this.isReplyThankLoading = true
    const replyThankSnapshot: ReplyThankSnapshot | null = this.v.optimisticallyMarkReplyThanked(
      reply.id,
    )
    const thankedIdsSnapshot: ReplyThankedIdsSnapshot = this.markReplyThanked(reply.id)
    TopicDetailActionCoordinator.executeReplyThank(this.api, cookie, this.topicId, reply.id)
      .then(() => {
        this.persistReplyThankOverlay(reply.id)
      })
      .catch((error: Error) => {
        this.v.rollbackReplyThank(replyThankSnapshot)
        this.thankedReplyIdsJson = TopicDetailActionCoordinator.rollbackReplyThankedIds(
          thankedIdsSnapshot,
          this.thankedReplyIdsJson,
        )
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.isReplyThankLoading = false
        this.clearReplyThankLock()
      })
  }

  private isReplyThankPending(replyId: number): boolean {
    return replyId > 0 && this.pendingReplyThankId === replyId
  }

  private clearReplyThankLock(): void {
    const lockState = TopicDetailActionCoordinator.clearReplyThankLockState()
    this.replyThankLockedId = lockState.lockedReplyId
    this.pendingReplyThankId = lockState.pendingReplyThankId
  }

  private isReplyThanked(reply: V2exReply): boolean {
    // Trust the rendered object's own server thanked flag first: during a held reload the page-1
    // snapshot omits the on-screen row, and this keeps its heart filled until the preload republish.
    if (reply.thanked) {
      return true
    }
    return TopicDetailActionCoordinator.isReplyThanked(
      reply.id,
      this.v.getLoadedRepliesSnapshot(),
      this.thankedReplyIdsJson,
    )
  }

  private markReplyThanked(replyId: number): ReplyThankedIdsSnapshot {
    const snapshot = TopicDetailActionCoordinator.markReplyThankedWithSnapshot(
      replyId,
      this.thankedReplyIdsJson,
    )
    this.thankedReplyIdsJson = snapshot.nextJson
    return snapshot
  }

  private prepareTopicIgnore(): void {
    this.prepareTopicModeration(
      AppStrings.text($r('app.string.topic_action_ignore_topic'), 'Ignore topic'),
      AppStrings.text($r('app.string.action_ignore'), 'Ignore'),
      (cookie: string) => this.api.getTopicIgnoreActionWithCookie(cookie, this.topicId),
      (cookie: string, action: V2exTopicModerationAction) =>
        this.api.executeTopicIgnoreWithCookie(cookie, action),
    )
  }

  private prepareTopicUnignore(): void {
    this.prepareTopicModeration(
      AppStrings.text($r('app.string.topic_action_unignore_topic'), 'Unignore topic'),
      AppStrings.text($r('app.string.action_unignore'), 'Unignore'),
      (cookie: string) => this.api.getTopicUnignoreActionWithCookie(cookie, this.topicId),
      (cookie: string, action: V2exTopicModerationAction) =>
        this.api.executeTopicUnignoreWithCookie(cookie, action),
    )
  }

  private prepareTopicReport(): void {
    this.prepareTopicModeration(
      AppStrings.text($r('app.string.topic_action_report_topic'), 'Report topic'),
      AppStrings.text($r('app.string.action_report'), 'Report'),
      (cookie: string) => this.api.getTopicReportActionWithCookie(cookie, this.topicId),
      (cookie: string, action: V2exTopicModerationAction) =>
        this.api.executeTopicReportWithCookie(cookie, action),
    )
  }

  private prepareReplyIgnore(reply: V2exReply): void {
    this.prepareReplyModeration(
      reply,
      AppStrings.text($r('app.string.reply_ignore_title'), 'Ignore reply'),
      AppStrings.text($r('app.string.action_ignore'), 'Ignore'),
      (cookie: string) => this.api.getReplyIgnoreActionWithCookie(cookie, this.topicId, reply.id),
      (cookie: string, action: V2exReplyModerationAction) =>
        this.api.executeReplyIgnoreWithCookie(cookie, this.topicId, action),
    )
  }

  private prepareReplyReport(reply: V2exReply): void {
    this.prepareReplyModeration(
      reply,
      AppStrings.text($r('app.string.reply_report_title'), 'Report reply'),
      AppStrings.text($r('app.string.action_report'), 'Report'),
      (cookie: string) => this.api.getReplyReportActionWithCookie(cookie, this.topicId, reply.id),
      (cookie: string, action: V2exReplyModerationAction) =>
        this.api.executeReplyReportWithCookie(cookie, this.topicId, action),
    )
  }

  private prepareTopicModeration(
    title: string,
    verb: string,
    loadAction: (cookie: string) => Promise<V2exTopicModerationAction>,
    executeAction: (cookie: string, action: V2exTopicModerationAction) => Promise<void>,
  ): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    const preflight = TopicDetailActionCoordinator.moderationPreflight({
      loading: this.isModerationActionLoading,
      cookie,
    })
    if (!preflight.guard.allowed) {
      if (preflight.guard.message) {
        promptAction.openToast({ message: preflight.guard.message }).catch((_error: Error) => {})
      }
      return
    }
    this.isModerationActionLoading = true
    loadAction(preflight.cookie)
      .then((action: V2exTopicModerationAction) => {
        this.confirmTopicModeration(title, verb, preflight.cookie, action, executeAction)
      })
      .catch((error: Error) => {
        promptAction
          .openToast({
            message: error.message || TopicDetailActionCoordinator.parseActionFailureMessage(verb),
          })
          .catch((_error: Error) => {})
      })
      .finally(() => {
        this.isModerationActionLoading = false
      })
  }

  private confirmTopicModeration(
    title: string,
    verb: string,
    cookie: string,
    action: V2exTopicModerationAction,
    executeAction: (cookie: string, action: V2exTopicModerationAction) => Promise<void>,
  ): void {
    const dialog = TopicDetailActionCoordinator.topicModerationConfirmDialog(
      title,
      verb,
      this.v.topic?.title || '',
    )
    this.getUIContext().showAlertDialog({
      title: dialog.title,
      message: dialog.message,
      primaryButton: { value: dialog.cancelLabel, action: () => {} },
      secondaryButton: {
        value: dialog.confirmLabel,
        action: () => {
          this.executeTopicModeration(verb, cookie, action, executeAction)
        },
      },
    })
  }

  private executeTopicModeration(
    verb: string,
    cookie: string,
    action: V2exTopicModerationAction,
    executeAction: (cookie: string, action: V2exTopicModerationAction) => Promise<void>,
  ): void {
    if (this.isModerationActionLoading) {
      return
    }
    this.isModerationActionLoading = true
    executeAction(cookie, action)
      .then(() => {
        this.applyTopicIgnoreDeltaAfterSuccess(action)
        promptAction
          .openToast({
            message: AppStrings.format(
              AppStrings.text($r('app.string.action_done_format'), '{0} done'),
              [verb],
            ),
          })
          .catch((_error: Error) => {})
        this.reloadTopicWithThreadPreload()
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.isModerationActionLoading = false
      })
  }

  private applyTopicIgnoreDeltaAfterSuccess(action: V2exTopicModerationAction): void {
    const ignored = this.topicIgnoreDeltaValue(action)
    if (ignored === null) {
      DiagnosticLogger.info('storage', 'blocked_list_topic_delta_skip_unknown_action', {
        endpoint: action?.actionPath || '',
        topicId: action?.topicId || this.topicId,
      })
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    BlockedListSettings.applyIgnoredTopicDelta(action.topicId || this.topicId, ignored, context, {
      endpoint: action.actionPath || '',
      source: 'topic_detail_mutation',
      trigger: ignored ? 'topic_ignore_success' : 'topic_unignore_success',
      hasCookie: !!CookieJarSettings.getCurrentCookie(),
    }).catch((error: Error) => {
      DiagnosticLogger.exception('storage', 'blocked_list_topic_delta_exception', error, {
        endpoint: action.actionPath || '',
        topicId: action.topicId || this.topicId,
      })
    })
  }

  private topicIgnoreDeltaValue(action: V2exTopicModerationAction): boolean | null {
    const actionPath = (action?.actionPath || '').toLowerCase()
    if (actionPath.indexOf('/unignore/') >= 0 || actionPath.indexOf('unignore') >= 0) {
      return false
    }
    if (actionPath.indexOf('/ignore/') >= 0 || actionPath.indexOf('ignore') >= 0) {
      return true
    }
    return null
  }

  private prepareReplyModeration(
    reply: V2exReply,
    title: string,
    verb: string,
    loadAction: (cookie: string) => Promise<V2exReplyModerationAction>,
    executeAction: (cookie: string, action: V2exReplyModerationAction) => Promise<void>,
  ): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    const preflight = TopicDetailActionCoordinator.moderationPreflight({
      loading: this.isModerationActionLoading,
      cookie,
      reply,
    })
    if (!preflight.guard.allowed) {
      if (preflight.guard.message) {
        promptAction.openToast({ message: preflight.guard.message }).catch((_error: Error) => {})
      }
      return
    }
    this.isModerationActionLoading = true
    loadAction(preflight.cookie)
      .then((action: V2exReplyModerationAction) => {
        this.confirmReplyModeration(reply, title, verb, preflight.cookie, action, executeAction)
      })
      .catch((error: Error) => {
        promptAction
          .openToast({
            message: error.message || TopicDetailActionCoordinator.parseActionFailureMessage(verb),
          })
          .catch((_error: Error) => {})
      })
      .finally(() => {
        this.isModerationActionLoading = false
      })
  }

  private confirmReplyModeration(
    reply: V2exReply,
    title: string,
    verb: string,
    cookie: string,
    action: V2exReplyModerationAction,
    executeAction: (cookie: string, action: V2exReplyModerationAction) => Promise<void>,
  ): void {
    const dialog = TopicDetailActionCoordinator.replyModerationConfirmDialog(title, verb, reply)
    this.getUIContext().showAlertDialog({
      title: dialog.title,
      message: dialog.message,
      primaryButton: { value: dialog.cancelLabel, action: () => {} },
      secondaryButton: {
        value: dialog.confirmLabel,
        action: () => {
          this.executeReplyModeration(verb, cookie, action, executeAction)
        },
      },
    })
  }

  private executeReplyModeration(
    verb: string,
    cookie: string,
    action: V2exReplyModerationAction,
    executeAction: (cookie: string, action: V2exReplyModerationAction) => Promise<void>,
  ): void {
    if (this.isModerationActionLoading) {
      return
    }
    this.isModerationActionLoading = true
    executeAction(cookie, action)
      .then(() => {
        promptAction
          .openToast({
            message: AppStrings.format(
              AppStrings.text($r('app.string.action_done_format'), '{0} done'),
              [verb],
            ),
          })
          .catch((_error: Error) => {})
        this.reloadTopicWithThreadPreload()
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
      .finally(() => {
        this.isModerationActionLoading = false
      })
  }

  private copyToClipboard(text: string): void {
    const content = (text || '').trim()
    if (!content) {
      return
    }
    try {
      let data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content)
      pasteboard.getSystemPasteboard().setDataSync(data)
      promptAction
        .openToast({ message: $r('app.string.common_copied') })
        .catch((_error: Error) => {})
    } catch (error) {
      promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
    }
  }

  private getMentionText(username: string, floor: number = 0): string {
    return TopicDetailReplyDisplayCoordinator.mentionText(username, floor)
  }

  private openInSystemBrowser(url: string): void {
    const target = (url || '').trim()
    if (!target) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const want: Want = { action: 'ohos.want.action.viewData', uri: target }
    context.startAbility(want).catch((error: Error) => {
      promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
    })
  }

  // Open the topic in the built-in cookie-injected WebView (logged-in view) instead of an external browser,
  // so the user can compare/read the topic as the site renders it while signed in.
  private openInAppWebView(url: string): void {
    const target = (url || '').trim()
    if (!target) {
      return
    }
    publishAccountWebViewUrl(target)
    this.stack.pushPathByName('AccountWebView', null)
  }

  private shareTopic(): void {
    if (this.v.topic === null) {
      return
    }
    const title = (
      this.v.topic.title || AppStrings.text($r('app.string.topic_share_fallback_title'), 'V2EX topic')
    ).trim()
    const url = this.getTopicUrl()
    const data = new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      title: title,
      description: title,
      content: url,
    })
    const controller = new systemShare.ShareController(data)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    controller
      .show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT,
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
      })
  }

  private getTopicUrl(): string {
    const baseUrl = HttpClient.getInstance().getBaseUrl()
    if (this.v.topic !== null) {
      const raw = (this.v.topic!.url || '').trim()
      const resolved = V2exUrlRouter.withSelectedBaseUrl(raw, baseUrl)
      if (resolved) {
        return resolved
      }
    }
    return `${baseUrl}/t/${this.topicId}`
  }
}
