import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  ApiV2Service,
  AppStrings,
  AuthCookieState,
  AuthIdentityState,
  AuthSessionSignalState,
  AuthSessionSettings,
  AuthSettings,
  connectAuthCookie,
  connectAuthIdentity,
  connectAuthSessionSignal,
  connectLocalDataSignal,
  connectNavStack,
  connectNotificationAction,
  connectNotificationUnread,
  CookieJarSettings,
  DiagnosticLogger,
  EmptyState,
  HttpClient,
  LoadingFooter,
  LocalDataSignalState,
  NotificationActionState,
  NotificationUnreadState,
  publishNotificationUnreadCount,
  PullRefreshListScaffold,
  ThemeConstants,
  TwoFactorChallengeService,
  V2exCookieTwoFactorRequiredError,
  V2exNotification,
  translateApiError
} from 'shared'
import {
  NotificationAuthContext,
  NotificationCenterViewModel,
  NotificationMetadata,
  NotificationPageResult,
  READ_TAG_UNREAD
} from '../viewmodel/NotificationCenterViewModel'
import { NotificationCacheCoordinator } from '../model/NotificationCacheCoordinator'
import { NotificationCardDisplay, NotificationPageCoordinator } from '../model/NotificationPageCoordinator'
import {
  NotificationAuthRequiredState,
  NotificationCard,
  NotificationDeleteSwipeAction,
  NotificationErrorState
} from '../components/NotificationPageComponents'

@ComponentV2
export struct NotificationPage {
  // ns from NavStackHolder (was @Consume('ns')).
  private ns: NavPathStack = connectNavStack().stack
  // Auth/session/local-data/notification-action read from their V2 mirrors (dual-written at the
  // service chokepoints); replaces the AUTH_* / LOCAL_DATA_UPDATED_AT / NOTIFICATION_ACTION
  // @StorageLink + @Watch. The shared onAuthChanged reaction is driven by a multi-path @Monitor below.
  // The unread badge count is read imperatively (never in build) off the V2 NotificationUnreadState
  // mirror and cleared through publishNotificationUnreadCount, keeping Index's tab badge in sync.
  private authIdentity: AuthIdentityState = connectAuthIdentity()
  private authCookie: AuthCookieState = connectAuthCookie()
  private session: AuthSessionSignalState = connectAuthSessionSignal()
  private localData: LocalDataSignalState = connectLocalDataSignal()
  private notificationAction: NotificationActionState = connectNotificationAction()
  private notificationUnread: NotificationUnreadState = connectNotificationUnread()
  @Local private authToken: string = ''
  @Local private notifications: V2exNotification[] = []
  @Local private notificationError: string = ''
  @Local private isNotificationLoading: boolean = false
  @Local private notificationPage: number = 1
  @Local private notificationHasMore: boolean = true
  @Local private isNotificationLoadingMore: boolean = false
  @Local private notificationCacheUpdatedAt: number = 0
  @Local private notificationLoadedFromCache: boolean = false
  @Local private notificationSourceLabel: string = ''
  @Local private notificationInitialSettled: boolean = false
  @Local private isNotificationAuthLoading: boolean = false
  @Local private scrollEnabled: boolean = true
  @Local private viewedUnreadNotificationKeys: string[] = []
  @Param scroller: Scroller = new Scroller()
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private notificationVm: NotificationCenterViewModel = new NotificationCenterViewModel(this.api)
  private readonly NOTIFICATION_PAGE_SIZE: number = 20
  private authRefreshRequestId: number = 0
  private notificationRefreshRequestId: number = 0
  private notificationCacheRequestId: number = 0
  private pendingNotificationForceRefresh: boolean = false
  private notificationIdentityKey: string = ''
  private notificationEntryUnreadCount: number = 0
  private pendingNotificationDeletes: Set<number> = new Set<number>()
  @Param refreshKey: number = 0
  @Param currentTab: number = 0

  aboutToAppear(): void {
    this.loadAuthSnapshot(false)
  }

  @Monitor('refreshKey')
  onRefreshKeyChanged(): void {
    this.loadAuthSnapshot(true)
  }

  @Monitor('authIdentity.tokenConfigured', 'authCookie.configured', 'authIdentity.username', 'session.username', 'session.updatedAt')
  onAuthChanged(): void {
    if (this.deferNotificationRefreshUntilVisible()) {
      return
    }
    const nextIdentity = this.currentNotificationIdentityKey()
    if (this.notificationIdentityKey && nextIdentity === this.notificationIdentityKey) {
      this.loadAuthSnapshot(true)
      return
    }
    if (!nextIdentity && !this.notificationIdentityKey && this.notifications.length === 0) {
      this.loadAuthSnapshot(true)
      return
    }
    this.loadAuthSnapshot(true)
  }

  @Monitor('localData.updatedAt')
  onLocalDataUpdated(): void {
    this.notificationError = ''
  }

  @Monitor('notificationAction.command')
  onNotificationAction(): void {
    const raw = (this.notificationAction.command || '').trim()
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
          message: AppStrings.text(AppStrings.R_NOTIFICATION_LOGIN_REQUIRED, 'Login to view notifications'),
          onLoginClick: () => {
            this.ns.pushPathByName('V2exNativeLogin', null)
          }
        })
      } else if (this.shouldShowNotificationInitialLoading()) {
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
          },
          onDidScroll: (offset: number, state: ScrollState) => {
            if (this.onDidScroll) {
              this.onDidScroll(offset, state)
            }
          }
        }) {
          ForEach(this.notifications, (item: V2exNotification) => {
            this.NotificationListItem(item)
          }, (item: V2exNotification) => this.notificationItemKey(item))
          if (this.shouldShowNotificationEmptyState()) {
            ListItem() {
              EmptyState({ message: AppStrings.text(AppStrings.R_NOTIFICATION_EMPTY, 'No notifications'), stateHeight: 240 })
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
      replyRenderedContent: display.replyRenderedContent,
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
    DiagnosticLogger.info('notification', 'notification_auth_snapshot_start', { force: forceNotifications, requestId: requestId })
    this.isNotificationAuthLoading = true
    const restoreCookieJar = CookieJarSettings.getCurrentCookie()
      ? Promise.resolve()
      : CookieJarSettings.load(context).catch((error: Error) => {
          console.error('restore notification cookie jar failed: ' + error.message)
        })
    restoreCookieJar
      .then(() => AuthSettings.load(context))
      .then((snapshot) => {
        if (requestId !== this.authRefreshRequestId) {
          DiagnosticLogger.info('notification', 'notification_auth_snapshot_stale_drop', { requestId: requestId })
          return
        }
        this.authToken = snapshot.token
        const nextIdentity = this.currentNotificationIdentityKey(snapshot.username || this.session.username)
        if (this.notificationIdentityKey && nextIdentity !== this.notificationIdentityKey) {
          DiagnosticLogger.info('notification', 'notification_identity_changed', {
            oldOwnerHash: DiagnosticLogger.ownerHash(this.notificationIdentityKey),
            newOwnerHash: DiagnosticLogger.ownerHash(nextIdentity)
          })
          this.resetNotificationState()
        }
        this.loadNotificationCache(snapshot.username || this.session.username)
        this.notificationIdentityKey = nextIdentity
        if (this.shouldLoadNotificationListForCurrentTab(forceNotifications)) {
          this.loadNotifications(forceNotifications)
        }
      })
      .catch((error: Error) => {
        if (requestId !== this.authRefreshRequestId) {
          DiagnosticLogger.info('notification', 'notification_auth_snapshot_stale_drop', { requestId: requestId })
          return
        }
        DiagnosticLogger.warn('notification', 'notification_refresh_error', { requestId: requestId, source: this.notificationVm.sourceKeyFor(this.notificationAuthContext()), errorKind: error.name || 'Error' }, error)
        this.notificationError = translateApiError(error)
        this.notificationInitialSettled = true
      })
      .finally(() => {
        if (requestId === this.authRefreshRequestId) {
          this.isNotificationAuthLoading = false
        }
      })
  }

  private shouldShowNotificationInitialLoading(): boolean {
    return this.notifications.length === 0 &&
      (this.isNotificationAuthLoading || this.isNotificationLoading || !this.notificationInitialSettled)
  }

  private deferNotificationRefreshUntilVisible(): boolean {
    if (this.currentTab === 2) {
      return false
    }
    this.pendingNotificationForceRefresh = true
    DiagnosticLogger.info('notification', 'notification_auth_refresh_deferred', { reason: 'inactive_tab' })
    return true
  }

  private shouldLoadNotificationListForCurrentTab(forceNotifications: boolean): boolean {
    if (this.currentTab === 2) {
      return true
    }
    // /notifications list reads mark V2EX unread state as consumed, so hidden tab/auth restores may only restore local cache and must wait for explicit tab entry.
    if (forceNotifications) {
      this.pendingNotificationForceRefresh = true
    }
    DiagnosticLogger.info('notification', 'notification_list_refresh_deferred', { force: forceNotifications, reason: 'inactive_tab' })
    return false
  }

  private shouldShowNotificationEmptyState(): boolean {
    return this.notifications.length === 0 &&
      this.notificationInitialSettled &&
      !this.isNotificationAuthLoading &&
      !this.isNotificationLoading
  }

  private refreshVisibleNotificationsIfNeeded(): void {
    if (NotificationPageCoordinator.shouldRefreshVisible(
      this.hasNotificationAuth(),
      this.authCookie.configured || this.authIdentity.tokenConfigured,
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
    const token = (this.authToken || '').trim()
    return {
      tokenConfigured: this.authIdentity.tokenConfigured || token.length > 0,
      token: token,
      cookieConfigured: this.authCookie.configured || cookie.length > 0,
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
    const display = NotificationPageCoordinator.displayFor(this.notificationMeta(item))
    if (!display.readTag && this.isViewedUnreadNotification(item)) {
      display.readTag = READ_TAG_UNREAD
    }
    return display
  }

  private confirmDeleteNotification(item: V2exNotification): void {
    const id = item.id || 0
    if (id <= 0 || this.pendingNotificationDeletes.has(id)) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.text(AppStrings.R_NOTIFICATION_DELETE_TITLE, 'Delete notification'),
      message: AppStrings.text(AppStrings.R_NOTIFICATION_DELETE_CONFIRM, 'Delete this notification?'),
      primaryButton: {
        value: $r('app.string.common_cancel'), action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.common_delete'),
        action: () => {
          this.deleteNotificationItem(item)
        }
      }
    })
  }

  private deleteNotificationItem(item: V2exNotification): void {
    const localId = item.id || 0
    if (localId <= 0 || this.pendingNotificationDeletes.has(localId)) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (cookie && this.notificationVm.webDeleteId(item) > 0 && this.notificationVm.webDeleteOnce(item)) {
      this.deleteNotificationWithCookie(item)
      return
    }
    if (this.authIdentity.tokenConfigured && this.authToken) {
      this.deleteNotification(item)
      return
    }
    this.deleteNotificationWithCookie(item)
  }

  private deleteNotification(item: V2exNotification): void {
    const notificationId = item.id || 0
    if (!this.authIdentity.tokenConfigured || !this.authToken || notificationId <= 0) {
      promptAction.openToast({ message: AppStrings.text(AppStrings.R_NOTIFICATION_DELETE_REQUIRES_API_AUTH, 'Delete notification requires V2 API authorization') }).catch((_error: Error) => {
      })
      return
    }
    DiagnosticLogger.info('notification', 'notification_delete_start', { method: 'pat', id: notificationId, page: this.notificationPageForItem(item), attempt: 0 })
    const originalIndex = this.handleNotificationDeleted(item)
    if (originalIndex < 0) {
      return
    }
    const token = this.authToken
    this.deleteNotificationInBackground(item, originalIndex, () => {
      return this.apiV2.deleteNotification(token, notificationId).then(() => {
      })
    })
  }

  private deleteNotificationWithCookie(item: V2exNotification): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    const notificationId = this.notificationVm.webDeleteId(item)
    const once = this.notificationVm.webDeleteOnce(item)
    const verifyPage = this.notificationPageForItem(item)
    if (!cookie || notificationId <= 0 || !once) {
      promptAction.openToast({ message: AppStrings.text(AppStrings.R_NOTIFICATION_DELETE_REQUIRES_WEB_SESSION, 'Delete notification requires web session') }).catch((_error: Error) => {
      })
      return
    }
    DiagnosticLogger.info('notification', 'notification_delete_start', { method: 'cookie', id: notificationId, page: verifyPage, attempt: 0 })
    const originalIndex = this.handleNotificationDeleted(item)
    if (originalIndex < 0) {
      return
    }
    this.deleteNotificationInBackground(item, originalIndex, () => {
      return this.api.deleteNotificationWithCookie(cookie, notificationId, once, verifyPage)
    })
  }

  private notificationPageForItem(item: V2exNotification): number {
    const index = this.notifications.findIndex((current: V2exNotification) => current.id === item.id)
    if (index < 0) {
      return 1
    }
    return Math.floor(index / this.NOTIFICATION_PAGE_SIZE) + 1
  }

  private notificationItemKey(item: V2exNotification): string {
    const id = item.id || 0
    const deleteId = item.delete_id || 0
    const topicId = item.topic_id || 0
    const targetFloor = item.target_floor || 0
    return `${id}:${deleteId}:${topicId}:${targetFloor}`
  }

  private handleNotificationDeleted(item: V2exNotification): number {
    const notificationId = item.id || 0
    const originalIndex = this.notifications.findIndex((current: V2exNotification) => current.id === notificationId)
    if (originalIndex < 0) {
      return -1
    }
    this.notifications = this.notifications.filter((current: V2exNotification) => current.id !== notificationId)
    this.publishUnreadCount()
    return originalIndex
  }

  private deleteNotificationInBackground(
    item: V2exNotification,
    originalIndex: number,
    request: () => Promise<void>
  ): void {
    const notificationId = item.id || 0
    if (notificationId <= 0) {
      return
    }
    this.pendingNotificationDeletes.add(notificationId)
    this.afterOptimisticDeleteFrame(() => {
      promptAction.openToast({ message: $r('app.string.common_deleted') }).catch((_error: Error) => {
      })
      this.saveNotificationCache()
      this.retryDeleteNotificationRequest(request, 0)
        .then(() => {
          DiagnosticLogger.info('notification', 'notification_delete_success', { id: notificationId, restored: false })
        })
        .catch((error: Error) => {
          DiagnosticLogger.warn('notification', 'notification_delete_error', { id: notificationId, restored: true }, error)
          this.restoreNotificationAfterDeleteFailure(item, originalIndex)
          promptAction.openToast({ message: error.message || 'Delete failed; restored' }).catch((_toastError: Error) => {
          })
        })
        .finally(() => {
          this.pendingNotificationDeletes.delete(notificationId)
        })
    })
  }

  private afterOptimisticDeleteFrame(work: () => void): void {
    setTimeout(() => {
      work()
    }, 32)
  }

  private retryDeleteNotificationRequest(request: () => Promise<void>, attempt: number): Promise<void> {
    return request().catch((error: Error) => {
      if (attempt >= 2) {
        throw error
      }
      return new Promise<void>((resolve) => {
        setTimeout(() => {
          resolve()
        }, this.deleteRetryDelayMs(attempt))
      }).then(() => this.retryDeleteNotificationRequest(request, attempt + 1))
    })
  }

  private deleteRetryDelayMs(attempt: number): number {
    return Math.pow(2, attempt) * 1200
  }

  private restoreNotificationAfterDeleteFailure(item: V2exNotification, originalIndex: number): void {
    const notificationId = item.id || 0
    if (notificationId <= 0 || this.notifications.some((current: V2exNotification) => current.id === notificationId)) {
      return
    }
    const safeIndex = Math.max(0, Math.min(originalIndex, this.notifications.length))
    this.notifications = this.notifications.slice(0, safeIndex)
      .concat([item])
      .concat(this.notifications.slice(safeIndex))
    this.publishUnreadCount()
    this.saveNotificationCache()
  }

  private loadNotifications(force: boolean = false): void {
    this.refreshNotifications(force).catch((error: Error) => {
      this.notificationError = translateApiError(error)
    })
  }

  private async refreshNotifications(force: boolean = false): Promise<void> {
    if (!this.shouldLoadNotificationListForCurrentTab(force)) {
      return
    }
    const authContext = this.notificationAuthContext()
    const hasAuth = this.notificationVm.hasAuth(authContext)
    if (force && hasAuth && (this.isNotificationLoading || this.isNotificationLoadingMore)) {
      this.pendingNotificationForceRefresh = true
      DiagnosticLogger.info('notification', 'notification_force_refresh_queued', { reason: 'busy' })
    }
    if (!NotificationPageCoordinator.shouldRefreshNotifications(
      hasAuth,
      this.isNotificationLoading,
      this.isNotificationLoadingMore,
      this.notifications.length,
      force,
      this.notificationLoadedFromCache
    )) {
      DiagnosticLogger.info('notification', 'notification_refresh_skip', {
        force: force,
        reason: hasAuth ? 'guard' : 'no_auth',
        currentCount: this.notifications.length,
        loadedFromCache: this.notificationLoadedFromCache
      })
      return
    }
    if (force && this.notifications.length > 0) {
      this.resetViewedUnreadState()
    }
    const requestId = ++this.notificationRefreshRequestId
    this.notificationCacheRequestId++
    const entryUnreadCount = this.captureNotificationEntryUnreadCount()
    DiagnosticLogger.info('notification', 'notification_refresh_start', {
      force: force,
      requestId: requestId,
      source: this.notificationVm.sourceKeyFor(authContext),
      currentCount: this.notifications.length,
      loadedFromCache: this.notificationLoadedFromCache
    })
    this.isNotificationLoading = true
    this.notificationError = ''
    this.notificationPage = 1
    this.notificationHasMore = true
    try {
      const result = await this.notificationVm.loadPage(authContext, 1, this.NOTIFICATION_PAGE_SIZE)
      if (requestId !== this.notificationRefreshRequestId) {
        DiagnosticLogger.info('notification', 'notification_refresh_stale_drop', { requestId: requestId })
        return
      }
      this.viewedUnreadNotificationKeys = this.viewedUnreadKeysForLoadedItems(
        result.items,
        result.source === 'cookie',
        entryUnreadCount
      )
      this.notifications = this.notificationsWithoutReadState(result.items)
      this.publishUnreadCount()
      this.notificationPage = result.page
      this.notificationHasMore = result.hasMore
      this.notificationSourceLabel = result.sourceLabel
      this.notificationLoadedFromCache = false
      this.notificationInitialSettled = true
      DiagnosticLogger.info('notification', 'notification_refresh_success', {
        requestId: requestId,
        source: result.source,
        count: result.items.length,
        page: result.page,
        hasMore: result.hasMore,
        unreadCountFallback: entryUnreadCount
      })
      this.saveNotificationCache()
    } catch (error) {
      if (requestId !== this.notificationRefreshRequestId) {
        DiagnosticLogger.info('notification', 'notification_refresh_stale_drop', { requestId: requestId })
        return
      }
      const err = error as Error
      DiagnosticLogger.warn('notification', 'notification_refresh_error', { requestId: requestId, source: this.notificationVm.sourceKeyFor(authContext), errorKind: err.name || 'Error' }, err)
      const message = err.message || AppStrings.text(AppStrings.R_NOTIFICATION_LOAD_FAILED, 'Notifications load failed')
      this.notificationError = message
      this.notificationHasMore = false
      this.handleTwoFactorChallenge(err)
      this.handleExpiredCookieSession(message)
      this.notificationInitialSettled = true
      throw err
    } finally {
      if (requestId === this.notificationRefreshRequestId) {
        this.isNotificationLoading = false
        this.replayPendingNotificationForceRefresh()
      }
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
    DiagnosticLogger.info('notification', 'notification_load_more_start', { source: this.notificationVm.sourceKeyFor(authContext), page: nextPage, count: this.notifications.length })
    this.isNotificationLoadingMore = true
    this.notificationError = ''
    this.notificationVm.loadPage(authContext, nextPage, this.NOTIFICATION_PAGE_SIZE)
      .then((result: NotificationPageResult) => {
        if (!result.items || result.items.length === 0) {
          this.notificationHasMore = false
          return
        }
        const merged = this.notificationVm.mergeUnique(
          this.notifications,
          this.notificationsWithoutReadState(result.items)
        )
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
        DiagnosticLogger.info('notification', 'notification_load_more_success', { source: result.source, page: result.page, count: result.items.length })
        this.saveNotificationCache()
      })
      .catch((error: Error) => {
        DiagnosticLogger.warn('notification', 'notification_load_more_error', { source: this.notificationVm.sourceKeyFor(authContext), page: nextPage }, error)
        const message = translateApiError(error)
        this.notificationError = message
        this.notificationHasMore = false
        this.handleTwoFactorChallenge(error)
        this.handleExpiredCookieSession(message)
      })
      .finally(() => {
        this.isNotificationLoadingMore = false
        this.replayPendingNotificationForceRefresh()
      })
  }

  private resetNotificationState(): void {
    DiagnosticLogger.info('notification', 'notification_reset', { reason: 'identity_changed' })
    this.notificationRefreshRequestId++
    this.notificationCacheRequestId++
    this.pendingNotificationForceRefresh = false
    this.authToken = ''
    this.notifications = []
    this.notificationError = ''
    this.isNotificationLoading = false
    this.notificationPage = 1
    this.notificationHasMore = true
    this.isNotificationLoadingMore = false
    this.notificationCacheUpdatedAt = 0
    this.notificationLoadedFromCache = false
    this.notificationSourceLabel = ''
    this.notificationInitialSettled = false
    this.resetViewedUnreadState()
    this.publishUnreadCount()
  }

  private loadNotificationCache(username: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const authContext = this.notificationAuthContext()
    const requestId = ++this.notificationCacheRequestId
    DiagnosticLogger.info('notification', 'notification_cache_load_start', {
      requestId: requestId,
      ownerHash: DiagnosticLogger.ownerHash(username || this.authIdentity.username || this.session.username),
      source: this.notificationVm.sourceKeyFor(authContext),
      currentCount: this.notifications.length
    })
    const refreshInFlightAtStart = this.isNotificationLoading
    NotificationCacheCoordinator.load(
      context,
      username,
      this.authIdentity.username,
      this.session.username,
      this.notificationVm.sourceKeyFor(authContext),
      this.notifications.length,
      this.notificationLoadedFromCache
    )
      .then((result) => {
        if (requestId !== this.notificationCacheRequestId) {
          DiagnosticLogger.info('notification', 'notification_cache_drop', { reason: 'stale', requestId: requestId })
          return
        }
        if (result.skipped) {
          DiagnosticLogger.info('notification', 'notification_cache_load_skip', { reason: 'coordinator_skip' })
          return
        }
        if (refreshInFlightAtStart || this.isNotificationLoading) {
          DiagnosticLogger.info('notification', 'notification_cache_drop', { reason: 'refresh_in_flight', requestId: requestId })
          return
        }
        if (this.notifications.length > 0 && !this.notificationLoadedFromCache) {
          DiagnosticLogger.info('notification', 'notification_cache_drop', { reason: 'fresh_rows_present', requestId: requestId })
          return
        }
        this.notificationCacheUpdatedAt = result.updatedAt
        if (!result.shouldApplyItems) {
          DiagnosticLogger.info('notification', 'notification_cache_drop', { reason: 'empty_or_no_apply', requestId: requestId })
          return
        }
        const authContext = this.notificationAuthContext()
        const entryUnreadCount = this.captureNotificationEntryUnreadCount()
        this.viewedUnreadNotificationKeys = this.viewedUnreadKeysForLoadedItems(
          result.items,
          this.isCookieNotificationSource(authContext),
          entryUnreadCount
        )
        this.notifications = this.notificationsWithoutReadState(result.items)
        this.publishUnreadCount()
        this.notificationPage = result.page
        this.notificationHasMore = result.hasMore
        this.notificationLoadedFromCache = true
        this.notificationSourceLabel = this.notificationVm.sourceLabelFor(authContext)
        this.notificationInitialSettled = true
        DiagnosticLogger.info('notification', 'notification_cache_apply', {
          ownerHash: DiagnosticLogger.ownerHash(username || this.authIdentity.username || this.session.username),
          source: this.notificationVm.sourceKeyFor(authContext),
          count: result.items.length,
          updatedAt: result.updatedAt
        })
      })
      .catch((error: Error) => {
        DiagnosticLogger.warn('notification', 'notification_cache_drop', { reason: 'load_error' }, error)
      })
  }

  private replayPendingNotificationForceRefresh(): void {
    if (!this.pendingNotificationForceRefresh || this.isNotificationLoading || this.isNotificationLoadingMore) {
      return
    }
    if (!this.notificationVm.hasAuth(this.notificationAuthContext())) {
      return
    }
    this.pendingNotificationForceRefresh = false
    DiagnosticLogger.info('notification', 'notification_force_refresh_replayed', {})
    setTimeout(() => {
      this.loadAuthSnapshot(true)
    }, 0)
  }

  private saveNotificationCache(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const authContext = this.notificationAuthContext()
    NotificationCacheCoordinator.save(
      context,
      '',
      this.authIdentity.username,
      this.session.username,
      this.notificationVm.sourceKeyFor(authContext),
      this.notifications,
      this.notificationPage,
      this.notificationHasMore
    )
      .then((result) => {
        if (result.updatedAt > 0) {
          this.notificationCacheUpdatedAt = result.updatedAt
          DiagnosticLogger.info('notification', 'notification_cache_save_success', {
            ownerHash: DiagnosticLogger.ownerHash(this.authIdentity.username || this.session.username),
            source: this.notificationVm.sourceKeyFor(authContext),
            count: this.notifications.length
          })
        }
      })
      .catch((error: Error) => {
        DiagnosticLogger.warn('notification', 'notification_cache_save_error', {
          ownerHash: DiagnosticLogger.ownerHash(this.authIdentity.username || this.session.username),
          source: this.notificationVm.sourceKeyFor(authContext),
          count: this.notifications.length
        }, error)
      })
  }

  private publishUnreadCount(): void {
    // Clear the cross-surface unread badge (the V2 NotificationUnreadState mirror the @ComponentV2 Index
    // tab badge reads) via the write-through helper.
    publishNotificationUnreadCount(0)
  }

  private captureNotificationEntryUnreadCount(): number {
    const count = Math.max(0, this.notificationUnread.count)
    if (count > this.notificationEntryUnreadCount) {
      this.notificationEntryUnreadCount = count
    }
    return this.notificationEntryUnreadCount
  }

  private resetViewedUnreadState(): void {
    this.viewedUnreadNotificationKeys = []
    this.notificationEntryUnreadCount = 0
  }

  private isCookieNotificationSource(context: NotificationAuthContext): boolean {
    return this.notificationVm.sourceKeyFor(context) === 'cookie'
  }

  private currentNotificationIdentityKey(username: string = ''): string {
    const authContext = this.notificationAuthContext()
    return NotificationPageCoordinator.ownerKey(
      username,
      this.authIdentity.username,
      this.session.username,
      this.notificationVm.sourceKeyFor(authContext)
    )
  }

  private viewedUnreadKeysForLoadedItems(
    items: V2exNotification[],
    useCountFallback: boolean,
    unreadCount: number
  ): string[] {
    if (!Array.isArray(items) || items.length === 0) {
      return []
    }
    if (this.notificationVm.unreadCount(items) > 0) {
      return this.unreadKeysFromItems(items)
    }
    if (!useCountFallback || unreadCount <= 0) {
      return this.retainViewedUnreadKeys(items)
    }
    return items.slice(0, Math.min(unreadCount, items.length))
      .map((item: V2exNotification) => this.notificationItemKey(item))
      .filter((key: string) => !!key)
  }

  private unreadKeysFromItems(items: V2exNotification[]): string[] {
    return items
      .filter((item: V2exNotification) => this.notificationVm.metadata(item).readTag === READ_TAG_UNREAD)
      .map((item: V2exNotification) => this.notificationItemKey(item))
      .filter((key: string) => !!key)
  }

  private retainViewedUnreadKeys(items: V2exNotification[]): string[] {
    if (this.viewedUnreadNotificationKeys.length === 0) {
      return []
    }
    const keys = new Set<string>(items.map((item: V2exNotification) => this.notificationItemKey(item)))
    return this.viewedUnreadNotificationKeys.filter((key: string) => keys.has(key))
  }

  private isViewedUnreadNotification(item: V2exNotification): boolean {
    const key = this.notificationItemKey(item)
    return !!key && this.viewedUnreadNotificationKeys.indexOf(key) >= 0
  }

  private notificationsWithoutReadState(items: V2exNotification[]): V2exNotification[] {
    return items.map((item: V2exNotification) => this.notificationWithoutReadState(item))
  }

  private notificationWithoutReadState(item: V2exNotification): V2exNotification {
    return {
      id: item.id,
      member: item.member,
      for_member_id: item.for_member_id,
      text: item.text,
      reply_content: item.reply_content,
      reply_content_rendered: item.reply_content_rendered,
      payload: item.payload,
      payload_rendered: item.payload_rendered,
      title: item.title,
      content: item.content,
      content_rendered: item.content_rendered,
      topic_id: item.topic_id,
      topic_title: item.topic_title,
      target_floor: item.target_floor,
      delete_id: item.delete_id,
      delete_once: item.delete_once,
      created: item.created,
      last_modified: item.last_modified
    }
  }

  private handleTwoFactorChallenge(error: Error): void {
    if (!(error instanceof V2exCookieTwoFactorRequiredError)) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      return
    }
    this.notificationError = AppStrings.text(AppStrings.R_TWO_FACTOR_REQUIRED, 'V2EX requires two-factor verification')
    DiagnosticLogger.warn('notification', 'notification_two_factor_required', { source: this.notificationVm.sourceKeyFor(this.notificationAuthContext()) })
    TwoFactorChallengeService.request(cookie, 'notification')
  }

  private handleExpiredCookieSession(message: string): void {
    if (!message || (message.indexOf('Web session expired') < 0 && message.indexOf(AppStrings.text(AppStrings.R_API_ERROR_WEB_SESSION_EXPIRED, 'Web session expired, please log in again')) < 0)) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    DiagnosticLogger.warn('notification', 'notification_session_expired', { source: this.notificationVm.sourceKeyFor(this.notificationAuthContext()) })
    CookieJarSettings.clearForBaseUrl(context, HttpClient.getInstance().getBaseUrl())
      .then(() => AuthSessionSettings.clear(context))
      .catch((_error: Error) => {
      })
      .finally(() => {
        this.resetNotificationState()
      })
  }
}
