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
  @State private notificationPage: number = 1
  @State private notificationHasMore: boolean = true
  @State private isNotificationLoadingMore: boolean = false
  @State private notificationCacheUpdatedAt: number = 0
  @State private notificationLoadedFromCache: boolean = false
  @State private notificationSourceLabel: string = ''
  @State private scrollEnabled: boolean = true
  @State private viewedUnreadNotificationKeys: string[] = []
  private scroller: Scroller = new Scroller()
  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private notificationVm: NotificationCenterViewModel = new NotificationCenterViewModel(this.api)
  private readonly NOTIFICATION_PAGE_SIZE: number = 20
  private authRefreshRequestId: number = 0
  private notificationEntryUnreadCount: number = 0
  private pendingNotificationDeletes: Set<number> = new Set<number>()
  @Prop @Watch('onRefreshKeyChanged') refreshKey: number = 0

  aboutToAppear(): void {
    this.loadAuthSnapshot(false)
  }

  onRefreshKeyChanged(_propName: string): void {
    this.loadAuthSnapshot(true)
  }

  onAuthChanged(_propName: string): void {
    this.resetNotificationState()
    this.loadAuthSnapshot(true)
  }

  onLocalDataUpdated(_propName: string): void {
    this.notificationError = ''
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
          }, (item: V2exNotification) => this.notificationItemKey(item))
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
    const display = NotificationPageCoordinator.displayFor(this.notificationMeta(item))
    if (!display.readTag && this.isViewedUnreadNotification(item)) {
      display.readTag = '未读'
    }
    return display
  }

  private confirmDeleteNotification(item: V2exNotification): void {
    const id = item.id || 0
    if (id <= 0 || this.pendingNotificationDeletes.has(id)) {
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
    if (this.authTokenConfigured && this.authToken) {
      this.deleteNotification(item)
      return
    }
    this.deleteNotificationWithCookie(item)
  }

  private deleteNotification(item: V2exNotification): void {
    const notificationId = item.id || 0
    if (!this.authTokenConfigured || !this.authToken || notificationId <= 0) {
      promptAction.openToast({ message: '删除通知需要 V2 API 授权' }).catch((_error: Error) => {
      })
      return
    }
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
      promptAction.openToast({ message: '删除通知需要 Web 会话' }).catch((_error: Error) => {
      })
      return
    }
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
      promptAction.openToast({ message: '已删除' }).catch((_error: Error) => {
      })
      this.saveNotificationCache()
      this.retryDeleteNotificationRequest(request, 0)
        .catch((error: Error) => {
          this.restoreNotificationAfterDeleteFailure(item, originalIndex)
          promptAction.openToast({ message: error.message || '删除失败，已恢复' }).catch((_toastError: Error) => {
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
    if (force && this.notifications.length > 0) {
      this.resetViewedUnreadState()
    }
    const entryUnreadCount = this.captureNotificationEntryUnreadCount()
    this.isNotificationLoading = true
    this.notificationError = ''
    this.notificationPage = 1
    this.notificationHasMore = true
    try {
      const result = await this.notificationVm.loadPage(authContext, 1, this.NOTIFICATION_PAGE_SIZE)
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
    this.resetViewedUnreadState()
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
    this.notificationUnreadCount = 0
  }

  private captureNotificationEntryUnreadCount(): number {
    const count = Math.max(0, this.notificationUnreadCount)
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
    if (context.tokenConfigured && !!context.token) {
      return false
    }
    return context.cookieConfigured && !!context.cookie
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
      .filter((item: V2exNotification) => this.notificationVm.metadata(item).readTag === '未读')
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
