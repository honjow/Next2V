import { DetailViewModel } from '../viewmodel/DetailViewModel'
import { ReplyComposerSheet } from '../components/ReplyComposerSheet'
import { common, Want } from '@kit.AbilityKit'
import { promptAction, SymbolGlyphModifier } from '@kit.ArkUI'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { systemShare } from '@kit.ShareKit'
import {
  V2exReply,
  Avatar,
  ReplyCard,
  TimeAgo,
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
  AppModalScaffold,
  V2exRoute,
  V2exUrlRouter,
  TopicDetailParams,
  ImageUtils,
  HtmlEntityUtils,
  defaultSheetOptions,
} from 'shared'
import type { V2exReplyThankAction, V2exTopicThankAction } from 'shared'
import type { V2exReplyModerationAction, V2exTopicModerationAction } from 'shared'

interface ReplyContextItem {
  reply: V2exReply
  floor: number
  label: string
  selected: boolean
}
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
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number =
    ThemeConstants.FONT_SIZE_BODY;
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number =
    ThemeConstants.LINE_HEIGHT_BODY;
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string =
    ReadingSettings.DENSITY_STANDARD;
  @StorageLink(StorageKeys.READING_RESTORE_POSITION) readingRestorePosition: boolean = false;
  @StorageLink(StorageKeys.MOTION_HAND_EDGE)
  @Watch('onMotionHandEdgeChanged')
  motionHandEdge: string = 'center';
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0;
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0;
  private scroller: Scroller = new Scroller();
  @State listScrollEnabled: boolean = true;
  @State private isReplyListAtEnd: boolean = false;
  @State private visualMotionHandEdge: string = 'center';
  @State private floatingReplyAreaWidth: number = 0;
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
  @State private replyComposerInitialContent: string = '';
  @State private thankedReplyIdsJson: string = '[]';
  @State private titleContentBottom: number = 0;
  @State private currentScrollOffset: number = 0;
  @State private isTitleCoveredByAppbar: boolean = false;
  private readonly FLOATING_REPLY_HEIGHT: number = 40;
  private readonly FLOATING_REPLY_BOTTOM_GAP: number = 2;
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

  aboutToAppear(): void {
    this.v = new DetailViewModel(this.topicId)
    this.v.setReplyDisplayMode(this.replyDisplayMode)
    this.lastReadFloor = 0
    this.hasRestoredReadPosition = false
    this.hasJumpedToTargetFloor = false
    this.jumpFloorText = ''
    this.visualMotionHandEdge = this.motionHandEdge
    this.currentScrollOffset = 0
    this.titleContentBottom = 0
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
    return ReadingSettings.normalizeFontSize(this.readingFontSize)
  }

  private bodyLineHeight(): number {
    return ReadingSettings.normalizeLineHeight(this.readingLineHeight, this.bodyFontSize())
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
    Stack({ alignContent: Alignment.BottomStart }) {
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

      if (this.v.topic !== null) {
        this.FloatingReplyPill()
      }

      this.ReplyComposerSheetHost()
      this.ReplyContextSheetHost()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.floatingReplyAreaWidth = this.areaLength(newValue.width)
    })
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRatio: number) => {
      if (isVisible) {
        this.republishAppbarIdentity()
      }
    })
  }

  @Builder ReplyComposerSheetHost() {
    Blank()
      .width(1)
      .height(1)
      .bindSheet(
        $$this.replyComposerVisible,
        this.ReplyComposerSheetBuilder(),
        defaultSheetOptions(SheetSize.MEDIUM, () => {
          this.replyComposerVisible = false
          this.replyComposerInitialContent = ''
        }),
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
              floor: this.getFloorForReply(reply.id, index),
              isOp: this.v.topic !== null && reply.member.id === this.v.topic!.member.id,
              isThanked: this.isReplyThanked(reply.id),
              isThankPending: this.isReplyThankPending(reply.id),
              threadLevel: reply.threadLevel || 0,
              relationLabel: '',
              displayContent: this.replyDisplayContent(reply),
              childReplies: reply.threadChildren || [],
              opMemberId: this.v.topic !== null ? this.v.topic!.member.id : 0,
              hideLeadingMention: this.v.replyDisplayMode === 'thread',
              isReplyThanked: (target: V2exReply) => {
                return this.isReplyThanked(target.id)
              },
              isReplyThankPending: (target: V2exReply) => {
                return this.isReplyThankPending(target.id)
              },
              isWrongReference: !!reply.isWrongReference,
              isDuplicateThreadItem: !!reply.isDuplicateThreadItem,
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
          Row({ space: ThemeConstants.SPACE_SM }) {
            LoadingProgress()
              .width(20)
              .height(20)
            Text(this.v.preloadProgress)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .padding(ThemeConstants.SPACE_MD)
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

  @Builder FloatingReplyPill() {
    Row() {
      Button() {
        Row({ space: ThemeConstants.SPACE_XS }) {
          SymbolGlyph(
            this.authCookieConfigured
              ? $r('sys.symbol.arrowshape_turn_up_left_fill')
              : $r('sys.symbol.lock'),
          )
            .fontSize(18)
            .fontColor([Color.White])
          Text(this.authCookieConfigured ? '回复' : '登录')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.openReplyEditor()
        })
      }
      .type(ButtonType.Normal)
      .height(this.FLOATING_REPLY_HEIGHT)
      .width(96)
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(ThemeConstants.BRAND_PRIMARY)
      .shadow(ShadowStyle.OUTER_DEFAULT_SM)
      .translate({ x: this.floatingReplyOffsetX() })
      .zIndex(10)
      .onClick(() => {
        this.openReplyEditor()
      })
    }
    .width('100%')
    .height(this.bottomH + this.floatingReplyClearance())
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      bottom: this.bottomH + this.FLOATING_REPLY_BOTTOM_GAP,
    })
    .alignItems(VerticalAlign.Bottom)
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(10)
    .animation({ duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut })
  }

  private floatingReplyOffsetX(): number {
    const buttonWidth = 96
    const sideMargin = ThemeConstants.SPACE_LG
    const availableWidth = Math.max(0, this.floatingReplyAreaWidth - sideMargin * 2 - buttonWidth)
    if (this.visualMotionHandEdge === 'right') {
      return availableWidth
    }
    if (this.visualMotionHandEdge === 'center') {
      return availableWidth / 2
    }
    return 0
  }

  private floatingReplyClearance(): number {
    return this.FLOATING_REPLY_HEIGHT + this.FLOATING_REPLY_BOTTOM_GAP + ThemeConstants.SPACE_SM
  }

  private topicDetailBottomPadding(): number {
    return ThemeConstants.SPACE_XL + this.floatingReplyClearance()
  }

  private onMotionHandEdgeChanged(_propName: string): void {
    this.getUIContext().animateTo(
      { duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut },
      () => {
        this.visualMotionHandEdge = this.motionHandEdge
      },
    )
  }

  private areaLength(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }

  private areaY(value: Length | undefined): number {
    return this.areaLength(value)
  }

  private evaluateAppbarIdentityVisibility(): void {
    if (!this.v.topic || this.titleContentBottom <= 0) {
      this.isTitleCoveredByAppbar = false
      this.publishAppbarIdentity(false)
      return
    }
    const currentTitleBottom = this.titleContentBottom - this.currentScrollOffset
    const appbarBottom = this.topH + ThemeConstants.TITLE_BAR_HEIGHT
    const shouldShowIdentity = this.isTitleCoveredByAppbar
      ? currentTitleBottom <= appbarBottom + this.titleVisibilityHysteresis
      : currentTitleBottom <= appbarBottom
    if (shouldShowIdentity === this.isTitleCoveredByAppbar) {
      return
    }
    this.isTitleCoveredByAppbar = shouldShowIdentity
    this.publishAppbarIdentity(shouldShowIdentity)
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
    const title = visible ? this.topicAppbarTitle() : ''
    const avatarUrl = visible ? this.topicAppbarAvatarUrl() : ''
    const username = visible ? this.topicAppbarUsername() : ''
    this.topicDetailAppbarTitleStates = this.nextStringState(
      this.topicDetailAppbarTitleStates,
      routeKey,
      title,
    )
    this.topicDetailAppbarAvatarStates = this.nextStringState(
      this.topicDetailAppbarAvatarStates,
      routeKey,
      avatarUrl,
    )
    this.topicDetailAppbarUsernameStates = this.nextStringState(
      this.topicDetailAppbarUsernameStates,
      routeKey,
      username,
    )
    this.topicDetailAppbarRouteTopicId = visible ? routeKey : ''
    this.topicDetailAppbarTitle = title
    this.topicDetailAppbarAvatarUrl = avatarUrl
    this.topicDetailAppbarUsername = username
  }

  private nextStringState(statesJson: string, key: string, value: string): string {
    let states: Record<string, string> = {}
    try {
      const parsed = JSON.parse(statesJson || '{}') as Record<string, string>
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        states = parsed
      }
    } catch (_error) {}
    states[key] = value
    return JSON.stringify(states)
  }

  private topicRouteKey(): string {
    return this.topicId > 0 ? this.topicId.toString() : ''
  }

  private topicAppbarTitle(): string {
    return (this.v.topic?.title || '').trim()
  }

  private topicAppbarUsername(): string {
    return (this.v.topic?.member?.username || '').trim()
  }

  private topicAppbarAvatarUrl(): string {
    if (!this.v.topic) {
      return ''
    }
    return (this.v.topic.member.avatar_large || this.v.topic.member.avatar_normal || '').trim()
  }

  @Builder TopicCard() {
    Column() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Avatar({
          url: ImageUtils.memberAvatarUrl(this.v.topic!.member),
          avatarSize: ThemeConstants.AVATAR_SIZE_REPLY,
        })
          .onClick(() => {
            let p: UserProfileParams = { username: this.v.topic!.member.username }
            this.stack.pushPathByName('UserProfile', p as Object)
          })
        Text(this.v.topic!.member.username)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            let p: UserProfileParams = { username: this.v.topic!.member.username }
            this.stack.pushPathByName('UserProfile', p as Object)
          })
        Text('·')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor($r('sys.color.font_secondary'))
        TimeAgo({ timestamp: this.v.topic!.created })
        Blank()
        Text(this.v.topic!.node.title)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
          .padding({
            left: ThemeConstants.SPACE_SM,
            right: ThemeConstants.SPACE_SM,
            top: 2,
            bottom: 2,
          })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onClick(() => {
            let p: NodeTopicListParams = {
              nodeName: this.v.topic!.node.name,
              nodeTitle: this.v.topic!.node.title,
            }
            this.stack.pushPathByName('NodeTopicList', p as Object)
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(this.v.topic!.title)
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(28)
        .width('100%')
        .margin({ top: ThemeConstants.SPACE_MD })
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          const measuredGlobalBottom =
            this.areaY(newValue?.globalPosition?.y) + this.areaLength(newValue?.height)
          this.titleContentBottom = measuredGlobalBottom + this.currentScrollOffset
          this.evaluateAppbarIdentityVisibility()
        })

      // 正文
      if (this.topicBodySource()) {
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
          this.supplementBlocks(this.v.topic!.topicSupplementMarkdown || ''),
          (block: string, index: number) => {
            Column() {
              Text(this.supplementMeta(block))
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontColor($r('sys.color.font_secondary'))
                .width('100%')
              if (this.supplementBody(block)) {
                ForEach(
                  this.markdownBlocks(this.supplementBody(block)),
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
          (block: string, index: number) => `${index}-${block.length}-${block.slice(0, 16)}`,
        )
      }
    }
    .padding(this.topicCardPadding())
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  private topicBodySource(): string {
    const rendered = (this.v.topic?.content_rendered || '').trim()
    if (rendered.length > 0) {
      return this.v.topic?.content_rendered || ''
    }
    return this.v.topic?.content || ''
  }

  private topicBodyBlocks(): string[] {
    const source = this.topicBodySource()
    if ((this.v.topic?.content_rendered || '').trim().length > 0) {
      return [source]
    }
    return this.markdownBlocks(source)
  }

  private markdownBlocks(source: string): string[] {
    const normalized = (source || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n')
    const lines = normalized.split('\n')
    const blocks: string[] = []
    let buffer: string[] = []
    let tableBuffer: string[] = []
    let inTable = false
    const flushBuffer = (): void => {
      const text = buffer.join('\n').trim()
      if (text.length > 0) {
        blocks.push(text)
      }
      buffer = []
    }
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const trimmed = line.trim()
      if (inTable) {
        tableBuffer.push(line)
        if (/<\/table>/i.test(line)) {
          const table = tableBuffer.join('\n').trim()
          if (table.length > 0) {
            blocks.push(table)
          }
          tableBuffer = []
          inTable = false
        }
        continue
      }
      if (/<table\b/i.test(line)) {
        flushBuffer()
        tableBuffer = [line]
        inTable = !/<\/table>/i.test(line)
        if (!inTable) {
          blocks.push(tableBuffer.join('\n').trim())
          tableBuffer = []
        }
        continue
      }
      if (/^#{1,6}\s+/.test(trimmed)) {
        flushBuffer()
        blocks.push(trimmed)
        continue
      }
      if (trimmed.length === 0) {
        flushBuffer()
        continue
      }
      buffer.push(line)
    }
    flushBuffer()
    const trailingTable = tableBuffer.join('\n').trim()
    if (trailingTable.length > 0) {
      blocks.push(trailingTable)
    }
    return blocks
  }

  private supplementBlocks(source: string): string[] {
    const normalized = (source || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim()
    if (normalized.length === 0) {
      return []
    }
    const lines = normalized.split('\n')
    const blocks: string[] = []
    let current: string[] = []
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      if (/^##\s+/.test(line.trim()) && current.length > 0) {
        blocks.push(current.join('\n').trim())
        current = []
      }
      current.push(line)
    }
    const last = current.join('\n').trim()
    if (last.length > 0) {
      blocks.push(last)
    }
    return blocks
  }

  private supplementMeta(block: string): string {
    const first = ((block || '').split('\n')[0] || '').trim()
    return first.replace(/^##\s+/, '').trim()
  }

  private supplementBody(block: string): string {
    const lines = (block || '').split('\n')
    if (lines.length <= 1) {
      return ''
    }
    return lines.slice(1).join('\n').trim()
  }

  @Builder ReplyDivider() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Text(this.replyCountText())
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.ReplyToolButton('楼层', false, () => {
          this.openJumpToFloorDialog()
        })
        this.ReplyDisplayModeButton()
        this.ReplyToolButton('最新', false, () => {
          this.scrollToLatestReply()
        })
      }.alignItems(VerticalAlign.Center)
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_SM,
      right: ThemeConstants.SPACE_SM,
      top: ThemeConstants.SPACE_SM,
      bottom: ThemeConstants.SPACE_XS,
    })
  }

  @Builder ReplyToolButton(label: string, active: boolean, action: () => void) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TINY)
      .fontColor(active ? Color.White : $r('sys.color.font_secondary'))
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 5, bottom: 5 })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(
        active ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_button_normal'),
      )
      .onClick(action)
  }

  @Builder ReplyDisplayModeButton() {
    Text(this.replyDisplayModeText())
      .fontSize(ThemeConstants.FONT_SIZE_TINY)
      .fontColor(
        this.v.replyDisplayMode === 'origin' ? $r('sys.color.font_secondary') : Color.White,
      )
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 5, bottom: 5 })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(
        this.v.replyDisplayMode === 'origin'
          ? $r('sys.color.ohos_id_color_button_normal')
          : ThemeConstants.BRAND_PRIMARY,
      )
      .onClick(() => {
        this.showReplyDisplayMenu()
      })
      .bindMenu(this.replyDisplayMenuShown, this.ReplyDisplayModeMenu, {
        placement: Placement.BottomRight,
        aboutToDisappear: () => {
          this.replyDisplayMenuShown = false
        },
      })
  }

  @Builder ReplyDisplayModeMenu() {
    Menu() {
      this.ReplyDisplayModeMenuItem('楼中楼', 'thread')
      this.ReplyDisplayModeMenuItem('楼中楼(@)', 'threadWithMention')
      this.ReplyDisplayModeMenuItem('冗余楼中楼', 'threadRedundant')
      this.ReplyDisplayModeMenuItem('只看楼主', 'op')
      this.ReplyDisplayModeMenuItem('原版', 'origin')
    }
  }

  @Builder ReplyDisplayModeMenuItem(label: string, mode: string) {
    MenuItem({
      content: label,
      symbolEndIcon:
        this.v.replyDisplayMode === mode
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
    }).onClick(() => {
      this.updateReplyDisplayMode(mode)
    })
  }

  @Builder ReplyContextSheet() {
    AppModalScaffold({
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
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(item.label)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor(
            item.selected
              ? $r('sys.color.ohos_id_color_activated')
              : $r('sys.color.font_secondary'),
          )
          .padding({
            left: ThemeConstants.SPACE_SM,
            right: ThemeConstants.SPACE_SM,
            top: 2,
            bottom: 2,
          })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        Text(`#${item.floor}`)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
        Text(item.reply.member.username)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        TimeAgo({ timestamp: item.reply.created })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(this.replySnippet(item.reply.content))
        .fontSize(this.bodyFontSize())
        .lineHeight(this.bodyLineHeight())
        .fontColor($r('sys.color.font_primary'))
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor(
      item.selected
        ? $r('sys.color.ohos_id_color_button_normal')
        : $r('sys.color.ohos_id_color_sub_background'),
    )
    .onClick(() => {
      this.jumpToLoadedReplyFloor(item.floor)
      this.closeReplyContext()
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
    if (this.contextReply === null) {
      return '回复上下文'
    }
    const floor = this.v.getReplyFloor(this.contextReply.id)
    return floor > 0 ? `#${floor} 回复上下文` : '回复上下文'
  }

  private buildReplyContextItems(selected: V2exReply): ReplyContextItem[] {
    const selectedFloor = this.v.getReplyFloor(selected.id)
    const replies = this.v.getLoadedRepliesSnapshot()
    const items: ReplyContextItem[] = []
    const seen = new Set<number>()

    const addReply = (reply: V2exReply | null, label: string, selectedItem: boolean): void => {
      if (reply === null || reply.id <= 0 || seen.has(reply.id)) {
        return
      }
      const floor = this.v.getReplyFloor(reply.id)
      if (floor <= 0) {
        return
      }
      seen.add(reply.id)
      items.push({ reply: reply, floor: floor, label: label, selected: selectedItem })
    }

    this.addContextReplyByFloor(replies, selectedFloor - 2, '上文', addReply)
    this.addContextReplyByFloor(replies, selectedFloor - 1, '上文', addReply)
    this.addMentionTargetsBeforeSelection(
      replies,
      selectedFloor,
      selected.content,
      selected.content_rendered,
      addReply,
    )
    addReply(selected, '当前回复', true)
    this.addRepliesMentioningSelectedAuthor(
      replies,
      selectedFloor,
      selected.member.username,
      addReply,
    )
    this.addContextReplyByFloor(replies, selectedFloor + 1, '下文', addReply)
    this.addContextReplyByFloor(replies, selectedFloor + 2, '下文', addReply)

    return items.sort((left: ReplyContextItem, right: ReplyContextItem) => left.floor - right.floor)
  }

  private addContextReplyByFloor(
    replies: V2exReply[],
    floor: number,
    label: string,
    addReply: (reply: V2exReply | null, label: string, selectedItem: boolean) => void,
  ): void {
    if (floor <= 0 || floor > replies.length) {
      return
    }
    addReply(replies[floor - 1], label, false)
  }

  private addMentionTargetsBeforeSelection(
    replies: V2exReply[],
    selectedFloor: number,
    content: string,
    renderedContent: string,
    addReply: (reply: V2exReply | null, label: string, selectedItem: boolean) => void,
  ): void {
    const names = this.extractMentionedUsernames(content, renderedContent)
    names.forEach((name: string) => {
      const target = this.findPreviousReplyByUsername(replies, selectedFloor, name)
      addReply(target, `@${name}`, false)
    })
  }

  private addRepliesMentioningSelectedAuthor(
    replies: V2exReply[],
    selectedFloor: number,
    username: string,
    addReply: (reply: V2exReply | null, label: string, selectedItem: boolean) => void,
  ): void {
    const clean = (username || '').trim()
    if (!clean) {
      return
    }
    let added = 0
    for (let i = selectedFloor; i < replies.length && added < 2; i++) {
      const reply = replies[i]
      if (reply && this.contentMentionsUsername(reply.content, reply.content_rendered, clean)) {
        addReply(reply, `提到 @${clean}`, false)
        added++
      }
    }
  }

  private findPreviousReplyByUsername(
    replies: V2exReply[],
    selectedFloor: number,
    username: string,
  ): V2exReply | null {
    const clean = (username || '').trim().toLowerCase()
    if (!clean) {
      return null
    }
    for (let i = selectedFloor - 2; i >= 0; i--) {
      const reply = replies[i]
      if (reply && (reply.member.username || '').trim().toLowerCase() === clean) {
        return reply
      }
    }
    return null
  }

  private contentMentionsUsername(
    content: string,
    renderedContent: string,
    username: string,
  ): boolean {
    const clean = (username || '').trim().toLowerCase()
    if (!clean) {
      return false
    }
    return this.extractMentionedUsernames(content, renderedContent).some(
      (name: string) => name.toLowerCase() === clean,
    )
  }

  private extractMentionedUsernames(content: string, renderedContent: string = ''): string[] {
    const names: string[] = []
    const seen = new Set<string>()
    const addName = (name: string): void => {
      const clean = (name || '').trim()
      const key = clean.toLowerCase()
      if (clean && !seen.has(key)) {
        seen.add(key)
        names.push(clean)
      }
    }

    const rendered = renderedContent || ''
    const linkRe =
      /@\s*<a\b[^>]*href=["'](?:https?:\/\/(?:www\.)?v2ex\.(?:com|co))?\/member\/([^"'?#\/]+)[^"']*["'][^>]*>/gi
    let linkMatch: RegExpExecArray | null = linkRe.exec(rendered)
    while (linkMatch) {
      addName(this.decodeHtmlText(linkMatch[1] || ''))
      linkMatch = linkRe.exec(rendered)
    }
    if (names.length > 0) {
      return names
    }

    const raw = content || ''
    const re = /@([0-9A-Za-z_]{2,32})/g
    let m: RegExpExecArray | null = re.exec(raw)
    while (m) {
      if (this.isValidMentionMatch(raw, m.index, m[0])) {
        addName(m[1] || '')
      }
      m = re.exec(raw)
    }
    return names
  }

  private isValidMentionMatch(raw: string, atIndex: number, matchText: string): boolean {
    const before = atIndex > 0 ? raw.charAt(atIndex - 1) : ''
    const afterIndex = atIndex + matchText.length
    const after = afterIndex < raw.length ? raw.charAt(afterIndex) : ''
    return this.isMentionBoundaryChar(before) && this.isMentionBoundaryChar(after)
  }

  private isMentionBoundaryChar(ch: string): boolean {
    if (!ch) {
      return true
    }
    return !this.isMentionNameChar(ch) && ch !== '-' && ch !== '.'
  }

  private decodeHtmlText(value: string): string {
    return HtmlEntityUtils.decode(value || '')
  }

  private isMentionNameChar(ch: string): boolean {
    return (
      (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch === '_'
    )
  }

  private replySnippet(content: string): string {
    const text = (content || '')
      .replace(/\r/g, '\n')
      .replace(/\n+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
    return text || '（无内容）'
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
    const count = this.v.replyDataSource.totalCount()
    if (count <= 0) {
      return 0
    }
    return 2 + count
  }

  private replyCountText(): string {
    const total = this.v.topic?.replies ?? 0
    if (total > 0 && this.v.repliesLoaded < total) {
      return `已加载 ${this.v.repliesLoaded} / ${total}`
    }
    if (total > 0) {
      return `共 ${total} 条回复`
    }
    return `共 ${this.v.repliesLoaded} 条回复`
  }

  private toggleOnlyOp(): void {
    this.updateReplyDisplayMode(
      this.v.onlyOp ? ReplyDisplaySettings.MODE_THREAD : ReplyDisplaySettings.MODE_OP,
    )
  }

  private updateReplyDisplayMode(mode: string): void {
    const normalizedMode = ReplyDisplaySettings.normalizeMode(mode)
    this.replyDisplayMode = normalizedMode
    const isThreadSwitch =
      normalizedMode === ReplyDisplaySettings.MODE_THREAD ||
      normalizedMode === ReplyDisplaySettings.MODE_THREAD_WITH_MENTION ||
      normalizedMode === ReplyDisplaySettings.MODE_THREAD_REDUNDANT
    if (isThreadSwitch && !this.v.allRepliesLoaded && this.v.repliesHasMore) {
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
    return ReplyDisplaySettings.modeText(this.v.replyDisplayMode)
  }

  private replyDisplayContent(reply: V2exReply): string {
    if (
      this.v.replyDisplayMode === 'thread' &&
      (reply.hiddenLeadingMentionContent || '').trim() &&
      (reply.threadLevel || 0) > 0 &&
      (reply.replyUsers || []).length === 1
    ) {
      return reply.hiddenLeadingMentionContent || ''
    }
    return ''
  }

  private getFloorForReply(replyId: number, index: number): number {
    const floor = this.v.getReplyFloor(replyId)
    return floor > 0 ? floor : index + 1
  }

  private getReplyMentionText(reply: V2exReply, fallbackIndex: number): string {
    return this.getMentionText(reply.member.username, this.getFloorForReply(reply.id, fallbackIndex))
  }

  private openJumpToFloorDialog(): void {
    if (this.v.topic === null) {
      return
    }
    this.jumpFloorText = ''
    this.jumpFloorDialogController?.open()
  }

  private handleJumpToFloor(value: string): void {
    const raw = (value || '').trim()
    const floor = parseInt(raw, 10)
    if (!raw || isNaN(floor) || floor <= 0) {
      promptAction.openToast({ message: '请输入有效楼层号' }).catch((_error: Error) => {})
      return
    }
    const maxFloor = this.v.topic !== null ? this.v.topic!.replies : 0
    const targetFloor = maxFloor > 0 && floor > maxFloor ? maxFloor : floor
    this.ensureRepliesLoaded(targetFloor)
      .then(() => {
        const loaded = this.v.replyDataSource.totalCount()
        if (loaded <= 0) {
          return
        }
        const safeFloor = targetFloor <= loaded ? targetFloor : loaded
        const listIndex = 2 + safeFloor
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
    const replyIndex = centerIndex - 3
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
        if (loaded <= 0) {
          return
        }
        const targetFloor = floor <= loaded ? floor : loaded
        const listIndex = 2 + targetFloor
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
        if (loaded <= 0) {
          return
        }
        const safeFloor = floor <= loaded ? floor : loaded
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
    if (targetFloor <= 0 || !this.v.repliesUseV2) {
      return
    }
    let guard = 0
    while (
      this.v.replyDataSource.totalCount() < targetFloor &&
      this.v.repliesHasMore &&
      guard < 20
    ) {
      guard++
      await this.v.loadMoreReplies()
    }
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
    const raw = (this.topicActionCommand || '').trim()
    if (!raw) {
      return
    }
    // Payload format: `${ts}:${topicId}:${action}`. Filter by topicId so
    // only the foreground TopicDetailPage reacts — without this, every
    // live instance in the nav stack would handle the action.
    const parts = raw.split(':')
    if (parts.length < 3) {
      return
    }
    const targetTopicId = Number(parts[1])
    if (targetTopicId !== this.topicId) {
      return
    }
    const action = parts.slice(2).join(':')
    this.handleTopicAction(action)
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
        const message = error.message || ''
        const thanked = message.indexOf('已经感谢过') >= 0
        this.isTopicThanked = thanked
        this.topicDetailThanked = thanked
      })
  }

  private showPreloadConfirmDialog(): void {
    const total = this.v.topic?.replies || 0
    AlertDialog.show({
      title: '回复数量较多',
      message: `该主题有 ${total} 条回复，加载全部回复可能需要较长时间。\n\n是否继续加载以启用完整的楼中楼视图？`,
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
    const title = (this.v.topic?.title || '').trim()
    const verb = this.isSiteFavorited ? '取消收藏' : '收藏'
    AlertDialog.show({
      title: '站内收藏',
      message: title ? `确定${verb}《${title}》吗？` : `确定${verb}该主题吗？`,
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
    this.api
      .executeTopicFavoriteToggleWithCookie(cookie, this.topicId, toggle)
      .then((favorited: boolean) => {
        this.isSiteFavorited = favorited
        this.topicDetailSiteFavorited = favorited
        promptAction
          .openToast({ message: favorited ? '已收藏' : '已取消收藏' })
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
    if (this.topicThankLocked || this.isTopicThankLoading) {
      return
    }
    if (this.isTopicThanked || this.topicDetailThanked) {
      promptAction.openToast({ message: '已经感谢过' }).catch((_error: Error) => {})
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction.openToast({ message: '请先登录' }).catch((_error: Error) => {})
      return
    }
    this.topicThankLocked = true
    this.confirmTopicThank(cookie)
  }

  private confirmTopicThank(cookie: string): void {
    const title = (this.v.topic?.title || '').trim()
    AlertDialog.show({
      title: '感谢主题',
      message: title ? `确定感谢《${title}》吗？` : '确定感谢该主题吗？',
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
    this.api
      .getTopicThankActionWithCookie(cookie, this.topicId)
      .then((action: V2exTopicThankAction) => this.api.executeTopicThankWithCookie(cookie, action))
      .then(() => {
        this.isTopicThanked = true
        this.topicDetailThanked = true
        promptAction.openToast({ message: '已感谢' }).catch((_error: Error) => {})
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
    if (this.isReplyThankLoading || this.replyThankLockedId > 0) {
      return
    }
    if (!reply || reply.id <= 0) {
      promptAction.openToast({ message: '回复信息缺失' }).catch((_error: Error) => {})
      return
    }
    if (this.isReplyThanked(reply.id)) {
      promptAction.openToast({ message: '已经感谢过' }).catch((_error: Error) => {})
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction.openToast({ message: '请先登录' }).catch((_error: Error) => {})
      return
    }
    if (!reply || reply.id <= 0) {
      promptAction.openToast({ message: '回复信息缺失' }).catch((_error: Error) => {})
      return
    }
    this.replyThankLockedId = reply.id
    this.pendingReplyThankId = reply.id
    this.confirmReplyThank(cookie, reply)
  }

  private confirmReplyThank(cookie: string, reply: V2exReply): void {
    AlertDialog.show({
      title: '感谢回复',
      message: `确定感谢 ${reply.member.username || '该用户'} 的回复吗？`,
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
    this.api
      .getReplyThankActionWithCookie(cookie, this.topicId, reply.id)
      .then((action: V2exReplyThankAction) =>
        this.api.executeReplyThankWithCookie(cookie, this.topicId, action),
      )
      .then(() => {
        this.v.markReplyThanked(reply.id)
        this.markReplyThanked(reply.id)
        promptAction.openToast({ message: '已感谢' }).catch((_error: Error) => {})
      })
      .catch((error: Error) => {
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
    this.replyThankLockedId = 0
    this.pendingReplyThankId = 0
  }

  private isReplyThanked(replyId: number): boolean {
    if (replyId <= 0) {
      return false
    }
    const replies = this.v.getLoadedRepliesSnapshot()
    for (let i = 0; i < replies.length; i++) {
      if (replies[i] && replies[i].id === replyId && replies[i].thanked) {
        return true
      }
    }
    try {
      const ids = JSON.parse(this.thankedReplyIdsJson || '[]') as number[]
      return Array.isArray(ids) && ids.indexOf(replyId) >= 0
    } catch (_error) {
      return false
    }
  }

  private markReplyThanked(replyId: number): void {
    if (replyId <= 0) {
      return
    }
    let ids: number[] = []
    try {
      const parsed = JSON.parse(this.thankedReplyIdsJson || '[]') as number[]
      ids = Array.isArray(parsed) ? parsed : []
    } catch (_error) {
      ids = []
    }
    if (ids.indexOf(replyId) < 0) {
      ids.push(replyId)
      this.thankedReplyIdsJson = JSON.stringify(ids)
    }
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
    if (this.isModerationActionLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction.openToast({ message: '请先登录' }).catch((_error: Error) => {})
      return
    }
    this.isModerationActionLoading = true
    loadAction(cookie)
      .then((action: V2exTopicModerationAction) => {
        this.confirmTopicModeration(title, verb, cookie, action, executeAction)
      })
      .catch((error: Error) => {
        promptAction
          .openToast({ message: error.message || `解析${verb}操作失败` })
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
    const topicTitle = (this.v.topic?.title || '').trim()
    AlertDialog.show({
      title: title,
      message: topicTitle ? `确定${verb}《${topicTitle}》吗？` : `确定${verb}该主题吗？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: verb,
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
        promptAction.openToast({ message: `已${verb}` }).catch((_error: Error) => {})
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
    if (this.isModerationActionLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction.openToast({ message: '请先登录' }).catch((_error: Error) => {})
      return
    }
    if (!reply || reply.id <= 0) {
      promptAction.openToast({ message: '回复信息缺失' }).catch((_error: Error) => {})
      return
    }
    this.isModerationActionLoading = true
    loadAction(cookie)
      .then((action: V2exReplyModerationAction) => {
        this.confirmReplyModeration(reply, title, verb, cookie, action, executeAction)
      })
      .catch((error: Error) => {
        promptAction
          .openToast({ message: error.message || `解析${verb}操作失败` })
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
    AlertDialog.show({
      title: title,
      message: `确定${verb} ${reply.member.username || '该用户'} 的回复吗？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: verb,
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
        promptAction.openToast({ message: `已${verb}` }).catch((_error: Error) => {})
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
      promptAction.openToast({ message: '已复制' }).catch((_error: Error) => {})
    } catch (error) {
      promptAction
        .openToast({ message: (error as Error).message || '复制失败' })
        .catch((_error: Error) => {})
    }
  }

  private getMentionText(username: string, floor: number = 0): string {
    const clean = (username || '').trim()
    if (!clean) {
      return ''
    }
    const cleanFloor = Math.floor(floor)
    return cleanFloor > 0 ? `@${clean} #${cleanFloor} ` : `@${clean} `
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
