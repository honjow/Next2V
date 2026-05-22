import { AppStrings } from 'shared'
import {
  DetailViewModel,
  type ReplyThankSnapshot,
} from '../viewmodel/DetailViewModel'
import { ReplyComposerSheet } from '../components/ReplyComposerSheet'
import {
  ReplyContextListItem,
  ReplyContextSheetContent,
  TopicDetailHeader,
  TopicDetailReplyDivider,
  TopicRepliesPreloadIndicator,
} from '../components/TopicDetailComponents'
import {
  ReplyContextCoordinator,
  type ReplyContextItem,
} from '../model/ReplyContextCoordinator'
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
import { LengthMetrics, promptAction } from '@kit.ArkUI'
import { ActionBarButton, ActionBarStyle, HdsActionBar } from '@kit.UIDesignKit'
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
  StorageKeys,
  ApiService,
  CookieJarSettings,
  V2exToggleAction,
  ReadingSettings,
  ReplyDisplaySettings,
  V2exRoute,
  V2exUrlRouter,
  TopicDetailParams,
  MotionHandStateService,
  defaultSheetOptions,
} from 'shared'
import type { V2exTopicThankAction } from 'shared'
import type { V2exReplyModerationAction, V2exTopicModerationAction } from 'shared'

@Component
export struct TopicDetailPage {
  @Prop topicId: number = 0;
  @Prop targetFloor: number = 0;
  @Prop hideTitle: boolean = false;
  @State v: DetailViewModel = new DetailViewModel(0);
  @Consume('ns') stack: NavPathStack;
  @StorageLink(StorageKeys.TOPIC_DETAIL_ACTION)
  @Watch('onTopicActionCommand')
  topicActionCommand: string = '';
  @StorageLink(StorageKeys.TOPIC_DETAIL_SAVED_LATER) topicDetailSavedLater: boolean = false;
  @StorageLink(StorageKeys.TOPIC_DETAIL_SITE_FAVORITED) topicDetailSiteFavorited: boolean = false;
  @StorageLink(StorageKeys.TOPIC_DETAIL_THANKED) topicDetailThanked: boolean = false;
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_TITLE) topicDetailAppbarTitle: string = '';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_AVATAR_URL) topicDetailAppbarAvatarUrl: string = '';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_USERNAME) topicDetailAppbarUsername: string = '';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_ROUTE_TOPIC_ID)
  topicDetailAppbarRouteTopicId: string = '';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_TITLE_STATES) topicDetailAppbarTitleStates: string =
    '{}';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_AVATAR_STATES)
  topicDetailAppbarAvatarStates: string = '{}';
  @StorageLink(StorageKeys.TOPIC_DETAIL_APPBAR_USERNAME_STATES)
  topicDetailAppbarUsernameStates: string = '{}';
  @StorageLink(StorageKeys.AUTH_COOKIE_CONFIGURED) authCookieConfigured: boolean = false;
  @StorageLink(StorageKeys.MOTION_HAND_EDGE)
  @Watch('onMotionHandEdgeChanged')
  motionHandEdge: string = 'right';
  @StorageLink(StorageKeys.READING_TEXT_SCALE) readingTextScale: number =
    ReadingSettings.TEXT_SCALE_DEFAULT;
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number =
    ThemeConstants.LINE_HEIGHT_BODY;
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string =
    ReadingSettings.DENSITY_STANDARD;
  @StorageLink(StorageKeys.READING_RESTORE_POSITION) readingRestorePosition: boolean = false;
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0;
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0;
  private scroller: Scroller = new Scroller();
  @State listScrollEnabled: boolean = true;
  @State private isReplyListAtEnd: boolean = false;
  @State isSavedLater: boolean = false;
  @State private isSiteFavorited: boolean = false;
  @State private isTopicThanked: boolean = false;
  @State private isSiteFavoriteLoading: boolean = false;
  @State private isTopicThankLoading: boolean = false;
  @State private isReplyThankLoading: boolean = false;
  @State private pendingReplyThankId: number = 0;
  @State private isModerationActionLoading: boolean = false;
  @State private jumpFloorText: string = '';
  @State private contextReply: V2exReply | null = null;
  @State private contextItems: ReplyContextItem[] = [];
  @State private contextSheetVisible: boolean = false;
  @StorageLink(StorageKeys.REPLY_DISPLAY_MODE) replyDisplayMode: string =
    ReplyDisplaySettings.MODE_THREAD;
  @State private replyDisplayMenuShown: boolean = false;
  @State private replyComposerVisible: boolean = false;
  @State private visualMotionHandEdge: string = 'right';
  @State private detailRootWidth: number = 0;
  @State private detailRootHeight: number = 0;
  @State private replyComposerInitialContent: string = '';
  @State private thankedReplyIdsJson: string = '[]';
  @State private titleContentBottom: number = 0;
  @State private currentScrollOffset: number = 0;
  @State private isTitleCoveredByAppbar: boolean = false;
  private readonly HDS_ACTION_BAR_CLEARANCE: number = 72;
  private readonly TOPIC_DETAIL_REPLY_BUTTON_SIZE: number = 56;
  private readonly FOLLOW_OPERATION_VERTICAL_SCROLL_THRESHOLD: number = 24;
  private readonly FOLLOW_OPERATION_VERTICAL_DOMINANCE_RATIO: number = 1.2;
  private readonly titleVisibilityHysteresis: number = 4;
  private api: ApiService = new ApiService();
  private topicThankLocked: boolean = false;
  private replyThankLockedId: number = 0;
  private jumpFloorDialogController: CustomDialogController | null = new CustomDialogController({
    builder: JumpToFloorDialog({
      floorText: $jumpFloorText,
      cancel: () => {},
      confirm: (value: string) => {
        this.handleJumpToFloor(value)
      },
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: false,
    cornerRadius: ThemeConstants.RADIUS_MD,
  });
  private lastReadFloor: number = 0;
  private hasRestoredReadPosition: boolean = false;
  private hasJumpedToTargetFloor: boolean = false;
  private followTouchState: TopicDetailFollowTouchState =
    TopicDetailFloatingActionCoordinator.initialTouchState();

  aboutToAppear(): void {
    this.v = new DetailViewModel(this.topicId)
    this.v.setReplyDisplayMode(this.replyDisplayMode)
    this.lastReadFloor = 0
    this.hasRestoredReadPosition = false
    this.hasJumpedToTargetFloor = false
    this.jumpFloorText = ''
    this.currentScrollOffset = 0
    this.titleContentBottom = 0
    this.followTouchState = TopicDetailFloatingActionCoordinator.initialTouchState()
    this.visualMotionHandEdge = this.motionHandEdge
    this.isTitleCoveredByAppbar = false
    this.syncTopicDetailTitleState(false, false, false)
    this.publishAppbarIdentity(false)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.v.setCacheHandlers(
      () => CacheSettings.loadTopicDetail(context, this.topicId),
      (topic: V2exTopic | null, replies: V2exReply[]) =>
        CacheSettings.saveTopicDetail(context, this.topicId, topic, replies),
    )
    this.v.loadCachedData()
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
          this.restoreInitialPosition()
          this.v.triggerThreadPreloadIfNeeded()
          if (this.v.needsPreloadConfirm) {
            this.showPreloadConfirmDialog()
          }
        })
      })
    this.loadSavedState()
    this.loadSiteFavoriteState()
    this.loadTopicThankState()
  }

  aboutToDisappear(): void {
    this.persistReadPosition()
  }

  private openImagePreview(url: string): void {
    const normalized = (url || '').trim()
    if (!normalized) {
      return
    }
    let p: ImagePreviewParams = { url: normalized }
    this.stack.pushPathByName('ImagePreview', p as Object)
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

  private openReplyEditor(initialContent: string = ''): void {
    if (!this.authCookieConfigured || !CookieJarSettings.getCurrentCookie()) {
      this.stack.pushPathByName('V2exNativeLogin', null)
      return
    }
    this.replyComposerInitialContent = initialContent
    this.replyComposerVisible = true
  }

  private bodyFontSize(): number {
    return ReadingSettings.scaleTypographyToken(ThemeConstants.FONT_SIZE_BODY, this.readingTextScale)
  }

  private bodyLineHeight(): number {
    return ReadingSettings.normalizeLineHeight(this.readingLineHeight, this.readingTextScale)
  }

  private topicCardPadding(): number {
    if (this.readingDensity === ReadingSettings.DENSITY_COMPACT) {
      return ThemeConstants.SPACE_MD
    }
    if (this.readingDensity === ReadingSettings.DENSITY_COMFORTABLE) {
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

      if (this.detailRootHeight > 0) {
        this.TopicDetailReplyActionBar()
      }

      this.ReplyComposerSheetHost()
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
      HdsActionBar({
        primaryButton: new ActionBarButton({
          width: LengthMetrics.vp(this.TOPIC_DETAIL_REPLY_BUTTON_SIZE),
          baseIcon: this.authCookieConfigured
            ? $r('sys.symbol.arrowshape_turn_up_left_fill')
            : $r('sys.symbol.lock'),
          hoverTips: this.authCookieConfigured ? '回复' : '登录',
          accessibilityText: this.authCookieConfigured ? '回复' : '登录',
          onClick: () => {
            this.openReplyEditor()
          },
        }),
        actionBarStyle: new ActionBarStyle({
          height: LengthMetrics.vp(this.TOPIC_DETAIL_REPLY_BUTTON_SIZE),
          margin: LengthMetrics.vp(0),
        }),
      })
    }
    .width('100%')
    .height(this.TOPIC_DETAIL_REPLY_BUTTON_SIZE)
    .justifyContent(this.topicDetailReplyActionBarAlign())
    .alignItems(VerticalAlign.Center)
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
    })
    .position({ x: 0, y: this.topicDetailReplyActionBarTop() })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  private topicDetailReplyActionBarTop(): number {
    return TopicDetailFloatingActionCoordinator.actionBarTop(
      this.detailRootHeight,
      this.bottomH,
      this.TOPIC_DETAIL_REPLY_BUTTON_SIZE,
    )
  }

  private topicDetailReplyActionBarAlign(): FlexAlign {
    return TopicDetailFloatingActionCoordinator.actionBarAlign(this.visualMotionHandEdge)
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

  private onMotionHandEdgeChanged(_propName: string): void {
    this.getUIContext().animateTo(
      { duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut },
      () => {
        this.visualMotionHandEdge = this.motionHandEdge
      },
    )
  }

  @Builder ReplyComposerSheetHost() {
    Blank()
      .width(1)
      .height(1)
      .bindSheet(
        $$this.replyComposerVisible,
        this.ReplyComposerSheetBuilder(),
        defaultSheetOptions(SheetSize.LARGE, () => {
          this.replyComposerVisible = false
          this.replyComposerInitialContent = ''
        },
          [SheetSize.LARGE, SheetSize.MEDIUM]
        ),
      )
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
        .color($r('sys.color.ohos_id_color_activated'))
      Text('加载中...')
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
      Text(this.v.errorMessage || '加载失败')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: ThemeConstants.SPACE_MD })
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => {
          this.v.load()
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
        this.v.triggerThreadPreloadIfNeeded()
      },
      onScrollEnableChange: (enabled: boolean) => {
        this.listScrollEnabled = enabled
      },
      onScrollIndex: (_start: number, end: number, center: number) => {
        this.handleReplyListScrollIndex(end, center)
      },
      onDidScroll: (offset: number, _state: ScrollState) => {
        this.currentScrollOffset = Math.max(0, offset)
        this.evaluateAppbarIdentityVisibility()
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

      // 回复分隔
      ListItem() {
        this.ReplyDivider()
      }

      // 回复列表
      LazyForEach(
        this.v.replyDataSource,
        (reply: V2exReply, index: number) => {
          ListItem() {
            ReplyCard({
              reply: reply,
              floor: this.replyCardDisplayState(reply, index).floor,
              isOp: this.replyCardDisplayState(reply, index).isOp,
              isThanked: this.isReplyThanked(reply.id),
              isThankPending: this.isReplyThankPending(reply.id),
              threadLevel: this.replyCardDisplayState(reply, index).threadLevel,
              relationLabel: '',
              displayContent: this.replyCardDisplayState(reply, index).displayContent,
              childReplies: this.replyCardDisplayState(reply, index).childReplies,
              opMemberId: this.replyCardDisplayState(reply, index).opMemberId,
              hideLeadingMention: this.replyCardDisplayState(reply, index).hideLeadingMention,
              isReplyThanked: (target: V2exReply) => {
                return this.isReplyThanked(target.id)
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

  @Builder ReplyComposerSheetBuilder() {
    ReplyComposerSheet({
      topicId: this.topicId,
      topicTitle: (this.v.topic?.title || '').trim(),
      initialContent: this.replyComposerInitialContent,
      closeAction: () => {
        this.replyComposerVisible = false
      },
      submittedAction: () => {
        this.v.load()
      },
    })
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
      appbarBottom: this.topH + ThemeConstants.TITLE_BAR_HEIGHT,
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
    this.topicDetailAppbarTitleStates = this.nextStringState(
      this.topicDetailAppbarTitleStates,
      routeKey,
      identity.title,
    )
    this.topicDetailAppbarAvatarStates = this.nextStringState(
      this.topicDetailAppbarAvatarStates,
      routeKey,
      identity.avatarUrl,
    )
    this.topicDetailAppbarUsernameStates = this.nextStringState(
      this.topicDetailAppbarUsernameStates,
      routeKey,
      identity.username,
    )
    this.topicDetailAppbarRouteTopicId = visible ? routeKey : ''
    this.topicDetailAppbarTitle = identity.title
    this.topicDetailAppbarAvatarUrl = identity.avatarUrl
    this.topicDetailAppbarUsername = identity.username
  }

  private nextStringState(statesJson: string, key: string, value: string): string {
    return TopicDetailAppbarCoordinator.nextStringState(statesJson, key, value)
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

      // 正文
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
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  private topicBodyBlocks(): string[] {
    return TopicDetailContentCoordinator.topicBodyBlocks(this.v.topic)
  }

  private topicSupplementBlocks(): TopicSupplementBlock[] {
    return TopicDetailContentCoordinator.topicSupplementBlocks(
      this.v.topic?.topicSupplementMarkdown || '',
    )
  }

  @Builder ReplyDivider() {
    TopicDetailReplyDivider({
      replyDisplayMenuShown: this.replyDisplayMenuShown,
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
    return ReplyContextCoordinator.title(
      this.contextReply,
      (replyId: number) => this.v.getReplyFloor(replyId),
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
    setTimeout(() => {
      try {
        this.scrollToListIndex(2 + floor, true)
      } catch (_e) {
        // ignore
      }
    }, 0)
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
          .openToast({ message: error.message || '刷新失败' })
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

  private updateReplyDisplayMode(mode: string): void {
    const normalizedMode = ReplyDisplaySettings.normalizeMode(mode)
    this.replyDisplayMode = normalizedMode
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

  private replyCardDisplayState(
    reply: V2exReply,
    index: number,
  ): TopicDetailReplyCardDisplayState {
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
    this.jumpFloorDialogController?.open()
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
        const loaded = this.v.replyDataSource.totalCount()
        const safeFloor = TopicDetailScrollCoordinator.loadedFloor(result.floor, loaded)
        if (safeFloor <= 0) {
          return
        }
        const listIndex = TopicDetailScrollCoordinator.listIndexForFloor(safeFloor)
        try {
          this.scrollToListIndex(listIndex, true)
        } catch (_e) {
          // ignore
        }
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
      }
    } catch (_e) {
      // ignore
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
        const loaded = this.v.replyDataSource.totalCount()
        const targetFloor = TopicDetailScrollCoordinator.loadedFloor(floor, loaded)
        if (targetFloor <= 0) {
          return
        }
        const listIndex = TopicDetailScrollCoordinator.listIndexForFloor(targetFloor)
        setTimeout(() => {
          try {
            this.scrollToListIndex(listIndex, true)
          } catch (_e) {
            // ignore
          }
        }, 0)
      })
      .catch((_error: Error) => {
        // ignore
      })
  }

  private restoreInitialPosition(): void {
    const target = Math.floor(this.targetFloor)
    if (target > 0) {
      this.jumpToTargetFloor(target)
      return
    }
    if (!this.readingRestorePosition) {
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
      .then(() => {
        const loaded = this.v.replyDataSource.totalCount()
        const safeFloor = TopicDetailScrollCoordinator.loadedFloor(floor, loaded)
        if (safeFloor <= 0) {
          return
        }
        this.jumpToLoadedReplyFloor(safeFloor)
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
        this.topicDetailSavedLater = saved
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
        this.topicDetailSavedLater = this.isSavedLater
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

  onTopicActionCommand(_propName: string): void {
    const command = TopicDetailActionCoordinator.parseCommand(this.topicActionCommand)
    if (!command || command.topicId !== this.topicId) {
      return
    }
    this.handleTopicAction(command.action)
  }

  private handleTopicAction(action: string): void {
    if (this.v.topic === null) {
      promptAction.openToast({ message: '主题仍在加载' }).catch((_error: Error) => {})
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
      this.prepareTopicIgnore()
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
    if (action === 'saveLater') {
      this.toggleSavedLater()
    } else if (action === 'copyTitle') {
      this.copyToClipboard(this.v.topic!.title || '')
    } else if (action === 'copyLink') {
      this.copyToClipboard(this.getTopicUrl())
    } else if (action === 'share') {
      this.shareTopic()
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
      promptAction.openToast({ message: '请先登录' }).catch((_error: Error) => {})
      return
    }
    this.isSiteFavoriteLoading = true
    this.api
      .getTopicFavoriteToggleActionWithCookie(cookie, this.topicId)
      .then((toggle) => {
        this.isSiteFavorited = toggle.currentlyOn
        this.topicDetailSiteFavorited = toggle.currentlyOn
        this.confirmSiteFavoriteToggle(cookie, toggle)
      })
      .catch((error: Error) => {
        promptAction
          .openToast({ message: error.message || '解析站内收藏失败' })
          .catch((_error: Error) => {})
      })
      .finally(() => {
        this.isSiteFavoriteLoading = false
      })
  }

  private loadSiteFavoriteState(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.topicId <= 0) {
      this.isSiteFavorited = false
      this.topicDetailSiteFavorited = false
      return
    }
    this.api
      .getTopicFavoriteToggleActionWithCookie(cookie, this.topicId)
      .then((toggle: V2exToggleAction) => {
        this.isSiteFavorited = toggle.currentlyOn
        this.topicDetailSiteFavorited = toggle.currentlyOn
      })
      .catch((_error: Error) => {
        this.isSiteFavorited = false
        this.topicDetailSiteFavorited = false
      })
  }

  private loadTopicThankState(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie || this.topicId <= 0) {
      this.isTopicThanked = false
      this.topicDetailThanked = false
      return
    }
    this.api
      .getTopicThankActionWithCookie(cookie, this.topicId)
      .then((_action: V2exTopicThankAction) => {
        this.isTopicThanked = false
        this.topicDetailThanked = false
      })
      .catch((error: Error) => {
        const thanked = TopicDetailActionCoordinator.thankedFromTopicThankLoadError(error)
        this.isTopicThanked = thanked
        this.topicDetailThanked = thanked
      })
  }

  private showPreloadConfirmDialog(): void {
    const total = this.v.topic?.replies || 0
    this.getUIContext().showAlertDialog({
      title: '回复数量较多',
      message: AppStrings.format(AppStrings.text($r('app.string.load_all_replies_warning_format'), 'This topic has {0} replies. Loading all replies may take some time.\n\nContinue loading to enable the full threaded view?'), [`${total}`]),
      primaryButton: {
        value: '平铺显示',
        action: () => {
          this.v.confirmPreloadFallbackFlat()
        },
      },
      secondaryButton: {
        value: '继续加载',
        action: () => {
          this.v.confirmPreloadAll()
        },
      },
    })
  }

  private confirmSiteFavoriteToggle(cookie: string, toggle: V2exToggleAction): void {
    const verb = this.isSiteFavorited ? '取消收藏' : '收藏'
    this.getUIContext().showAlertDialog({
      title: '站内收藏',
      message: TopicDetailActionCoordinator.topicFavoriteMessage(this.v.topic?.title || '', verb),
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: verb,
        action: () => {
          this.executeSiteFavoriteToggle(cookie, toggle)
        },
      },
    })
  }

  private executeSiteFavoriteToggle(cookie: string, toggle: V2exToggleAction): void {
    if (this.isSiteFavoriteLoading) {
      return
    }
    this.isSiteFavoriteLoading = true
    TopicDetailActionCoordinator
      .executeSiteFavoriteToggle(this.api, cookie, this.topicId, toggle)
      .then((favorited: boolean) => {
        this.isSiteFavorited = favorited
        this.topicDetailSiteFavorited = favorited
        promptAction
          .openToast({ message: favorited ? $r('app.string.favorited') : $r('app.string.unfavorited') })
          .catch((_error: Error) => {})
      })
      .catch((error: Error) => {
        promptAction
          .openToast({ message: error.message || '操作失败' })
          .catch((_error: Error) => {})
      })
      .finally(() => {
        this.isSiteFavoriteLoading = false
      })
  }

  private prepareTopicThank(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    const guard = TopicDetailActionCoordinator.topicThankGuard({
      locked: this.topicThankLocked,
      loading: this.isTopicThankLoading,
      thanked: this.isTopicThanked,
      storageThanked: this.topicDetailThanked,
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
      title: '感谢主题',
      message: TopicDetailActionCoordinator.topicThankMessage(this.v.topic?.title || ''),
      autoCancel: false,
      primaryButton: {
        value: '取消',
        action: () => {
          this.topicThankLocked = false
        },
      },
      secondaryButton: {
        value: '感谢',
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
    this.isTopicThankLoading = true
    TopicDetailActionCoordinator
      .executeTopicThank(this.api, cookie, this.topicId)
      .then(() => {
        this.isTopicThanked = true
        this.topicDetailThanked = true
        promptAction.openToast({ message: $r('app.string.thanked') }).catch((_error: Error) => {})
      })
      .catch((error: Error) => {
        promptAction
          .openToast({ message: error.message || '感谢失败' })
          .catch((_error: Error) => {})
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
    this.topicDetailSavedLater = savedLater
    this.topicDetailSiteFavorited = siteFavorited
    this.topicDetailThanked = thanked
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
      title: '感谢回复',
      message: TopicDetailActionCoordinator.replyActionMessage('感谢', reply.member.username),
      autoCancel: false,
      primaryButton: {
        value: '取消',
        action: () => {
          this.clearReplyThankLock()
        },
      },
      secondaryButton: {
        value: '感谢',
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
    const replyThankSnapshot: ReplyThankSnapshot | null =
      this.v.optimisticallyMarkReplyThanked(reply.id)
    const thankedIdsSnapshot: ReplyThankedIdsSnapshot = this.markReplyThanked(reply.id)
    TopicDetailActionCoordinator
      .executeReplyThank(this.api, cookie, this.topicId, reply.id)
      .then(() => {
        promptAction.openToast({ message: $r('app.string.thanked') }).catch((_error: Error) => {})
      })
      .catch((error: Error) => {
        this.v.rollbackReplyThank(replyThankSnapshot)
        this.thankedReplyIdsJson =
          TopicDetailActionCoordinator.rollbackReplyThankedIds(
            thankedIdsSnapshot,
            this.thankedReplyIdsJson,
          )
        promptAction
          .openToast({ message: error.message || '感谢失败' })
          .catch((_error: Error) => {})
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

  private isReplyThanked(replyId: number): boolean {
    return TopicDetailActionCoordinator.isReplyThanked(
      replyId,
      this.v.getLoadedRepliesSnapshot(),
      this.thankedReplyIdsJson,
    )
  }

  private markReplyThanked(replyId: number): ReplyThankedIdsSnapshot {
    const snapshot =
      TopicDetailActionCoordinator.markReplyThankedWithSnapshot(replyId, this.thankedReplyIdsJson)
    this.thankedReplyIdsJson = snapshot.nextJson
    return snapshot
  }

  private prepareTopicIgnore(): void {
    this.prepareTopicModeration(
      '忽略主题',
      '忽略',
      (cookie: string) => this.api.getTopicIgnoreActionWithCookie(cookie, this.topicId),
      (cookie: string, action: V2exTopicModerationAction) =>
        this.api.executeTopicIgnoreWithCookie(cookie, action),
    )
  }

  private prepareTopicReport(): void {
    this.prepareTopicModeration(
      '举报主题',
      '举报',
      (cookie: string) => this.api.getTopicReportActionWithCookie(cookie, this.topicId),
      (cookie: string, action: V2exTopicModerationAction) =>
        this.api.executeTopicReportWithCookie(cookie, action),
    )
  }

  private prepareReplyIgnore(reply: V2exReply): void {
    this.prepareReplyModeration(
      reply,
      '忽略回复',
      '忽略',
      (cookie: string) => this.api.getReplyIgnoreActionWithCookie(cookie, this.topicId, reply.id),
      (cookie: string, action: V2exReplyModerationAction) =>
        this.api.executeReplyIgnoreWithCookie(cookie, this.topicId, action),
    )
  }

  private prepareReplyReport(reply: V2exReply): void {
    this.prepareReplyModeration(
      reply,
      '举报回复',
      '举报',
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
        promptAction.openToast({ message: AppStrings.format(AppStrings.text($r('app.string.action_done_format'), '{0} done'), [verb]) }).catch((_error: Error) => {})
        this.v.load()
      })
      .catch((error: Error) => {
        promptAction
          .openToast({ message: error.message || `${verb}失败` })
          .catch((_error: Error) => {})
      })
      .finally(() => {
        this.isModerationActionLoading = false
      })
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
        promptAction.openToast({ message: AppStrings.format(AppStrings.text($r('app.string.action_done_format'), '{0} done'), [verb]) }).catch((_error: Error) => {})
        this.v.load()
      })
      .catch((error: Error) => {
        promptAction
          .openToast({ message: error.message || `${verb}失败` })
          .catch((_error: Error) => {})
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
      promptAction.openToast({ message: $r('app.string.common_copied') }).catch((_error: Error) => {})
    } catch (error) {
      promptAction
        .openToast({ message: (error as Error).message || '复制失败' })
        .catch((_error: Error) => {})
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
      promptAction.openToast({ message: error.message || '打开失败' }).catch((_error: Error) => {})
    })
  }

  private shareTopic(): void {
    if (this.v.topic === null) {
      return
    }
    const title = (this.v.topic.title || 'V2EX 主题').trim()
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
        promptAction
          .openToast({ message: error.message || '分享失败' })
          .catch((_error: Error) => {})
      })
  }

  private getTopicUrl(): string {
    const baseUrl = HttpClient.getInstance().getBaseUrl()
    if (this.v.topic !== null) {
      const raw = (this.v.topic!.url || '').trim()
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return raw
      }
      if (raw.startsWith('/')) {
        return `${baseUrl}${raw}`
      }
    }
    return `${baseUrl}/t/${this.topicId}`
  }
}

@CustomDialog
struct JumpToFloorDialog {
  controller?: CustomDialogController;
  @Link floorText: string;
  cancel: () => void = () => {};
  confirm: (value: string) => void = (_value: string) => {};

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text('跳转楼层')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      TextInput({ placeholder: '输入楼层号', text: this.floorText })
        .type(InputType.Number)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(ThemeConstants.RADIUS_MD)
        .onChange((value: string) => {
          this.floorText = value
        })
      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            if (this.controller != undefined) {
              this.controller.close()
            }
            this.cancel()
          })
        Button('跳转')
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            const value = this.floorText
            if (this.controller != undefined) {
              this.controller.close()
            }
            this.confirm(value)
          })
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .width('100%')
  }
}
