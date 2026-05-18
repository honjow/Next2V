import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  ApiV2Service,
  AuthSessionSettings,
  AuthSettings,
  CookieJarSettings,
  EmptyState,
  HttpClient,
  LoadingFooter,
  PullRefreshListScaffold,
  StorageKeys,
  ThemeConstants,
  TwoFactorChallengeService,
  V2exCookieTwoFactorRequiredError,
  V2exNotification
} from 'shared'
import {
  NotificationAuthContext,
  NotificationCenterViewModel,
  NotificationMetadata,
  NotificationPageResult
} from '../viewmodel/NotificationCenterViewModel'
import { NotificationCacheCoordinator } from '../model/NotificationCacheCoordinator'
import { NotificationCardDisplay, NotificationPageCoordinator } from '../model/NotificationPageCoordinator'
import {
  NotificationAuthRequiredState,
  NotificationCard,
  NotificationDeleteSwipeAction,
  NotificationErrorState
} from '../components/NotificationPageComponents'

@Component
export struct NotificationPage {
  @Consume('ns') ns: NavPathStack
  @StorageLink(StorageKeys.AUTH_TOKEN_CONFIGURED) @Watch('onAuthChanged') authTokenConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_COOKIE_CONFIGURED) @Watch('onAuthChanged') authCookieConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_USERNAME) @Watch('onAuthChanged') storedUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_USERNAME) @Watch('onAuthChanged') sessionUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_UPDATED_AT) @Watch('onAuthChanged') authSessionUpdatedAt: number = 0
  @StorageLink(StorageKeys.LOCAL_DATA_UPDATED_AT) @Watch('onLocalDataUpdated') localDataUpdatedAt: number = 0
  @StorageLink(StorageKeys.NOTIFICATION_ACTION) @Watch('onNotificationAction') notificationActionCommand: string = ''
  @StorageLink(StorageKeys.NOTIFICATION_UNREAD_COUNT) notificationUnreadCount: number = 0
  @State private authToken: string = ''
  @State private notifications: V2exNotification[] = []
  @State private notificationError: string = ''
  @State private isNotificationLoading: boolean = false
  @State private isNotificationDeleting: boolean = false
  @State private notificationPage: number = 1
  @State private notificationHasMore: boolean = true
  @State private isNotificationLoadingMore: boolean = false
  @State private notificationCacheUpdatedAt: number = 0
  @State private notificationLoadedFromCache: boolean = false
  @State private notificationSourceLabel: string = ''
  @State private scrollEnabled: boolean = true
  private scroller: Scroller = new Scroller()
  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private notificationVm: NotificationCenterViewModel = new NotificationCenterViewModel(this.api)
  private readonly NOTIFICATION_PAGE_SIZE: number = 20
  private authRefreshRequestId: number = 0
  @Prop @Watch('onRefreshKeyChanged') refreshKey: number = 0

  aboutToAppear(): void {
    this.loadAuthSnapshot(false)
  }

  onRefreshKeyChanged(_propName: string): void {
    this.resetNotificationState()
    this.loadAuthSnapshot(true)
  }

  onAuthChanged(_propName: string): void {
    this.resetNotificationState()
    this.loadAuthSnapshot(true)
  }

  onLocalDataUpdated(_propName: string): void {
    this.resetNotificationState()
    this.loadAuthSnapshot(true)
  }

  onNotificationAction(_propName: string): void {
    const raw = (this.notificationActionCommand || '').trim()
    if (!raw) {
      return
    }
    const action = raw.split(':').pop() || ''
    if (action === 'refresh') {
      this.loadNotifications(true)
    }
  }

  build() {
    Column() {
      if (!this.hasNotificationAuth()) {
        NotificationAuthRequiredState({
          message: '登录后可查看通知',
          onLoginClick: () => {
            this.ns.pushPathByName('V2exNativeLogin', null)
          }
        })
      } else if (this.isNotificationLoading && this.notifications.length === 0) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE)
          .height(ThemeConstants.LOADING_SIZE)
      } else if (this.notificationError && this.notifications.length === 0) {
        NotificationErrorState({
          message: this.notificationError,
          onRetryClick: () => {
            this.loadNotifications(true)
          }
        })
      } else {
        PullRefreshListScaffold({
          scroller: this.scroller,
          scrollEnabled: this.scrollEnabled,
          bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT,
          onRefresh: async () => {
            await this.refreshNotifications(true)
          },
          onScrollEnableChange: (enabled: boolean) => {
            this.scrollEnabled = enabled
          },
          onReachEnd: () => {
            this.loadMoreNotifications()
          }
        }) {
          ForEach(this.notifications, (item: V2exNotification) => {
            this.NotificationListItem(item)
          })
          if (this.notifications.length === 0) {
            ListItem() {
              EmptyState({ message: '暂无通知', stateHeight: 240 })
            }
          }
          if (this.notifications.length > 0) {
            ListItem() {
              LoadingFooter({ isLoading: this.isNotificationLoadingMore, hasMore: this.notificationHasMore })
            }
          }
        }
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRatio: number) => {
      if (isVisible) {
        this.refreshVisibleNotificationsIfNeeded()
      }
    })
  }

  @Builder
  NotificationListItem(item: V2exNotification) {
    if (this.canDeleteNotification(item)) {
      ListItem() {
        this.NotificationDisplayCard(item, this.notificationCardDisplay(item))
      }
      .onClick(() => { this.openNotification(item) })
      .swipeAction({ end: this.NotificationSwipeEnd(item) })
    } else {
      ListItem() {
        this.NotificationDisplayCard(item, this.notificationCardDisplay(item))
      }
      .onClick(() => { this.openNotification(item) })
    }
  }

  @Builder
  NotificationDisplayCard(item: V2exNotification, display: NotificationCardDisplay) {
    NotificationCard({
      item,
      kindTag: display.kindTag,
      readTag: display.readTag,
      titleText: display.titleText,
      bodyText: display.bodyText,
      replyContent: display.replyContent,
      memberName: display.memberName,
      avatarUrl: display.avatarUrl
    })
  }

  @Builder
  NotificationSwipeEnd(item: V2exNotification) {
    NotificationDeleteSwipeAction({
      item,
      onDeleteClick: (target: V2exNotification) => {
        this.confirmDeleteNotification(target)
      }
    })
  }

  private loadAuthSnapshot(forceNotifications: boolean = false): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const requestId = ++this.authRefreshRequestId
    const restoreCookieJar = CookieJarSettings.getCurrentCookie()
      ? Promise.resolve()
      : CookieJarSettings.load(context).catch((error: Error) => {
          console.error('restore notification cookie jar failed: ' + error.message)
        })
    restoreCookieJar
      .then(() => AuthSettings.load(context))
      .then((snapshot) => {
        if (requestId !== this.authRefreshRequestId) {
          return
        }
        this.authToken = snapshot.token
        this.loadNotificationCache(snapshot.username || this.sessionUsername)
        this.loadNotifications(forceNotifications)
      })
      .catch((error: Error) => {
        if (requestId !== this.authRefreshRequestId) {
          return
        }
        this.notificationError = error.message || '读取通知授权失败'
      })
  }

  private refreshVisibleNotificationsIfNeeded(): void {
    if (NotificationPageCoordinator.shouldRefreshVisible(
      this.hasNotificationAuth(),
      this.authCookieConfigured || this.authTokenConfigured,
      this.isNotificationLoading,
      this.isNotificationLoadingMore,
      this.notifications.length,
      this.notificationLoadedFromCache
    )) {
      this.loadAuthSnapshot(true)
    }
  }

  private hasNotificationAuth(): boolean {
    return this.notificationVm.hasAuth(this.notificationAuthContext())
  }

  private canDeleteNotification(item: V2exNotification): boolean {
    return this.notificationVm.canDeleteItem(this.notificationAuthContext(), item)
  }

  private notificationAuthContext(): NotificationAuthContext {
    const cookie = CookieJarSettings.getCurrentCookie()
    return {
      tokenConfigured: this.authTokenConfigured,
      token: this.authToken,
      cookieConfigured: cookie.length > 0,
      cookie: cookie
    }
  }

  private openNotification(item: V2exNotification): void {
    const meta = this.notificationMeta(item)
    const p = NotificationPageCoordinator.routeParams(meta)
    if (!p) {
      return
    }
    this.ns.pushPathByName('TopicDetail', p as Object)
  }

  private notificationMeta(item: V2exNotification): NotificationMetadata {
    return this.notificationVm.metadata(item)
  }

  private notificationCardDisplay(item: V2exNotification): NotificationCardDisplay {
    return NotificationPageCoordinator.displayFor(this.notificationMeta(item))
  }

  private confirmDeleteNotification(item: V2exNotification): void {
    const id = item.id || 0
    if (id <= 0 || this.isNotificationDeleting) {
      return
    }
    AlertDialog.show({
      title: '删除通知',
      message: '确定删除这条通知吗？',
      primaryButton: {
        value: '取消', action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: () => {
          this.deleteNotificationItem(item)
        }
      }
    })
  }

  private deleteNotificationItem(item: V2exNotification): void {
    if (this.authTokenConfigured && this.authToken) {
      this.deleteNotification(item.id || 0)
      return
    }
    this.deleteNotificationWithCookie(item)
  }

  private deleteNotification(notificationId: number): void {
    if (!this.authTokenConfigured || !this.authToken || this.isNotificationDeleting) {
      promptAction.openToast({ message: '删除通知需要 V2 API 授权' }).catch((_error: Error) => {
      })
      return
    }
    this.isNotificationDeleting = true
    this.apiV2.deleteNotification(this.authToken, notificationId)
      .then(() => {
        this.handleNotificationDeleted(notificationId)
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '删除失败' }).catch((_error: Error) => {
        })
      })
      .finally(() => {
        this.isNotificationDeleting = false
      })
  }

  private deleteNotificationWithCookie(item: V2exNotification): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    const notificationId = this.notificationVm.webDeleteId(item)
    const once = this.notificationVm.webDeleteOnce(item)
    if (!cookie || notificationId <= 0 || !once || this.isNotificationDeleting) {
      promptAction.openToast({ message: '删除通知需要 Web 会话' }).catch((_error: Error) => {
      })
      return
    }
    this.isNotificationDeleting = true
    this.api.deleteNotificationWithCookie(cookie, notificationId, once)
      .then(() => {
        this.handleNotificationDeleted(item.id || notificationId)
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '删除失败' }).catch((_error: Error) => {
        })
      })
      .finally(() => {
        this.isNotificationDeleting = false
      })
  }

  private handleNotificationDeleted(notificationId: number): void {
    this.notifications = this.notifications.filter(item => item.id !== notificationId)
    this.publishUnreadCount()
    this.saveNotificationCache()
    promptAction.openToast({ message: '已删除' }).catch((_error: Error) => {
    })
  }

  private loadNotifications(force: boolean = false): void {
    this.refreshNotifications(force).catch((error: Error) => {
      this.notificationError = error.message || '通知加载失败'
    })
  }

  private async refreshNotifications(force: boolean = false): Promise<void> {
    const authContext = this.notificationAuthContext()
    if (!NotificationPageCoordinator.shouldRefreshNotifications(
      this.notificationVm.hasAuth(authContext),
      this.isNotificationLoading,
      this.isNotificationLoadingMore,
      this.notifications.length,
      force,
      this.notificationLoadedFromCache
    )) {
      return
    }
    this.isNotificationLoading = true
    this.notificationError = ''
    this.notificationPage = 1
    this.notificationHasMore = true
    try {
      const result = await this.notificationVm.loadPage(authContext, 1, this.NOTIFICATION_PAGE_SIZE)
      this.notifications = result.items
      this.publishUnreadCount()
      this.notificationPage = result.page
      this.notificationHasMore = result.hasMore
      this.notificationSourceLabel = result.sourceLabel
      this.notificationLoadedFromCache = false
      this.saveNotificationCache()
    } catch (error) {
      const err = error as Error
      const message = err.message || '通知加载失败'
      this.notificationError = message
      this.notificationHasMore = false
      this.handleTwoFactorChallenge(err)
      this.handleExpiredCookieSession(message)
      throw err
    } finally {
      this.isNotificationLoading = false
    }
  }

  private loadMoreNotifications(): void {
    const authContext = this.notificationAuthContext()
    if (!this.notificationVm.hasAuth(authContext)) {
      return
    }
    if (this.isNotificationLoading || this.isNotificationLoadingMore || !this.notificationHasMore) {
      return
    }
    const nextPage = this.notificationPage + 1
    this.isNotificationLoadingMore = true
    this.notificationError = ''
    this.notificationVm.loadPage(authContext, nextPage, this.NOTIFICATION_PAGE_SIZE)
      .then((result: NotificationPageResult) => {
        if (!result.items || result.items.length === 0) {
          this.notificationHasMore = false
          return
        }
        const merged = this.notificationVm.mergeUnique(this.notifications, result.items)
        if (merged.length === this.notifications.length) {
          this.notificationHasMore = false
          return
        }
        this.notifications = merged
        this.publishUnreadCount()
        this.notificationPage = result.page
        this.notificationHasMore = result.hasMore
        this.notificationSourceLabel = result.sourceLabel
        this.notificationLoadedFromCache = false
        this.saveNotificationCache()
      })
      .catch((error: Error) => {
        const message = error.message || '加载更多失败'
        this.notificationError = message
        this.notificationHasMore = false
        this.handleTwoFactorChallenge(error)
        this.handleExpiredCookieSession(message)
      })
      .finally(() => {
        this.isNotificationLoadingMore = false
      })
  }

  private resetNotificationState(): void {
    this.notifications = []
    this.notificationError = ''
    this.isNotificationLoading = false
    this.notificationPage = 1
    this.notificationHasMore = true
    this.isNotificationLoadingMore = false
    this.notificationCacheUpdatedAt = 0
    this.notificationLoadedFromCache = false
    this.notificationSourceLabel = ''
    this.publishUnreadCount()
  }

  private loadNotificationCache(username: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NotificationCacheCoordinator.load(
      context,
      username,
      this.storedUsername,
      this.sessionUsername,
      this.notifications.length,
      this.notificationLoadedFromCache
    )
      .then((result) => {
        if (result.skipped) {
          return
        }
        this.notificationCacheUpdatedAt = result.updatedAt
        if (!result.shouldApplyItems) {
          return
        }
        this.notifications = result.items
        this.publishUnreadCount()
        this.notificationPage = result.page
        this.notificationHasMore = result.hasMore
        this.notificationLoadedFromCache = true
        this.notificationSourceLabel = this.notificationVm.sourceLabelFor(this.notificationAuthContext())
      })
      .catch((error: Error) => {
        console.error('load notification cache failed: ' + error.message)
      })
  }

  private saveNotificationCache(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NotificationCacheCoordinator.save(
      context,
      '',
      this.storedUsername,
      this.sessionUsername,
      this.notifications,
      this.notificationPage,
      this.notificationHasMore
    )
      .then((result) => {
        if (result.updatedAt > 0) {
          this.notificationCacheUpdatedAt = result.updatedAt
        }
      })
      .catch((error: Error) => {
        console.error('save notification cache failed: ' + error.message)
      })
  }

  private publishUnreadCount(): void {
    this.notificationUnreadCount = this.notificationVm.unreadCount(this.notifications)
  }

  private handleTwoFactorChallenge(error: Error): void {
    if (!(error instanceof V2exCookieTwoFactorRequiredError)) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      return
    }
    this.notificationError = 'V2EX 需要完成两步验证'
    TwoFactorChallengeService.request(cookie, 'notification')
  }

  private handleExpiredCookieSession(message: string): void {
    if (!message || message.indexOf('会话已失效') < 0) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CookieJarSettings.clearForBaseUrl(context, HttpClient.getInstance().getBaseUrl())
      .then(() => AuthSessionSettings.clear(context))
      .catch((_error: Error) => {
      })
      .finally(() => {
        this.resetNotificationState()
      })
  }
}
