import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  ApiV2Service,
  AuthSessionSettings,
  AuthSettings,
  CookieJarSettings,
  EmptyState,
  LoadingFooter,
  NotificationSettings,
  PullRefreshListScaffold,
  StorageKeys,
  ThemeConstants,
  TopicDetailParams,
  V2exNotification
} from 'shared'
import {
  NotificationAuthContext,
  NotificationCenterViewModel,
  NotificationMetadata,
  NotificationPageResult
} from '../viewmodel/NotificationCenterViewModel'
import {
  NotificationAuthRequiredState,
  NotificationCard,
  NotificationDeleteSwipeAction,
  NotificationErrorState,
  NotificationSummaryCard
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
          ListItem() {
            NotificationSummaryCard({
              count: this.notifications.length,
              errorText: this.notificationError,
              kindSummary: this.notificationKindSummary(),
              cacheUpdatedAt: this.notificationCacheUpdatedAt,
              loadedFromCache: this.notificationLoadedFromCache,
              sourceLabel: this.notificationSourceLabel
            })
          }

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
    if (this.canDeleteNotifications()) {
      ListItem() {
        NotificationCard({
          item,
          kindTag: this.notificationKindTag(item),
          readTag: this.notificationReadTag(item),
          titleText: this.notificationTitle(item),
          bodyText: this.notificationBody(item)
        })
      }
      .onClick(() => { this.openNotification(item) })
      .swipeAction({ end: this.NotificationSwipeEnd(item) })
    } else {
      ListItem() {
        NotificationCard({
          item,
          kindTag: this.notificationKindTag(item),
          readTag: this.notificationReadTag(item),
          titleText: this.notificationTitle(item),
          bodyText: this.notificationBody(item)
        })
      }
      .onClick(() => { this.openNotification(item) })
    }
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
    if (!this.hasNotificationAuth()) {
      if (this.authCookieConfigured || this.authTokenConfigured) {
        this.loadAuthSnapshot(true)
      }
      return
    }
    if (this.isNotificationLoading || this.isNotificationLoadingMore) {
      return
    }
    if (this.notifications.length > 0 && !this.notificationLoadedFromCache) {
      return
    }
    this.loadAuthSnapshot(true)
  }

  private hasNotificationAuth(): boolean {
    return this.notificationVm.hasAuth(this.notificationAuthContext())
  }

  private canDeleteNotifications(): boolean {
    return this.notificationVm.canDelete(this.notificationAuthContext())
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
    if (meta.topicId <= 0) {
      return
    }
    const p: TopicDetailParams = meta.targetFloor && meta.targetFloor > 0
      ? { topicId: meta.topicId, targetFloor: meta.targetFloor }
      : { topicId: meta.topicId }
    this.ns.pushPathByName('TopicDetail', p as Object)
  }

  private notificationMeta(item: V2exNotification): NotificationMetadata {
    return this.notificationVm.metadata(item)
  }

  private notificationKindSummary(): string {
    return this.notificationVm.kindSummary(this.notifications)
  }

  private notificationReadTag(item: V2exNotification): string {
    return this.notificationMeta(item).readTag
  }

  private notificationKindTag(item: V2exNotification): string {
    return this.notificationMeta(item).kindTag
  }

  private notificationTitle(item: V2exNotification): string {
    return this.notificationMeta(item).title
  }

  private notificationBody(item: V2exNotification): string {
    return this.notificationMeta(item).body
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
          this.deleteNotification(id)
        }
      }
    })
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
        this.notifications = this.notifications.filter(item => item.id !== notificationId)
        this.saveNotificationCache()
        promptAction.openToast({ message: '已删除' }).catch((_error: Error) => {
        })
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '删除失败' }).catch((_error: Error) => {
        })
      })
      .finally(() => {
        this.isNotificationDeleting = false
      })
  }

  private loadNotifications(force: boolean = false): void {
    this.refreshNotifications(force).catch((error: Error) => {
      this.notificationError = error.message || '通知加载失败'
    })
  }

  private async refreshNotifications(force: boolean = false): Promise<void> {
    const authContext = this.notificationAuthContext()
    if (!this.notificationVm.hasAuth(authContext)) {
      return
    }
    if (this.isNotificationLoading || this.isNotificationLoadingMore) {
      return
    }
    if (this.notifications.length > 0 && !force && !this.notificationLoadedFromCache) {
      return
    }
    this.isNotificationLoading = true
    this.notificationError = ''
    this.notificationPage = 1
    this.notificationHasMore = true
    try {
      const result = await this.notificationVm.loadPage(authContext, 1, this.NOTIFICATION_PAGE_SIZE)
      this.notifications = result.items
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
  }

  private loadNotificationCache(username: string): void {
    const ownerKey = this.notificationOwnerKey(username)
    if (!ownerKey || (this.notifications.length > 0 && !this.notificationLoadedFromCache)) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NotificationSettings.loadCache(context, ownerKey)
      .then((snapshot) => {
        this.notificationCacheUpdatedAt = snapshot.updatedAt
        if (snapshot.items.length === 0 || (this.notifications.length > 0 && !this.notificationLoadedFromCache)) {
          return
        }
        this.notifications = snapshot.items
        this.notificationPage = snapshot.page
        this.notificationHasMore = snapshot.hasMore
        this.notificationLoadedFromCache = true
        this.notificationSourceLabel = this.notificationVm.sourceLabelFor(this.notificationAuthContext())
      })
      .catch((error: Error) => {
        console.error('load notification cache failed: ' + error.message)
      })
  }

  private saveNotificationCache(): void {
    const ownerKey = this.notificationOwnerKey('')
    if (!ownerKey) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    NotificationSettings.saveCache(context, ownerKey, this.notifications, this.notificationPage,
      this.notificationHasMore)
      .then((snapshot) => {
        this.notificationCacheUpdatedAt = snapshot.updatedAt
      })
      .catch((error: Error) => {
        console.error('save notification cache failed: ' + error.message)
      })
  }

  private notificationOwnerKey(username: string): string {
    let owner = username.trim()
    if (!owner) {
      owner = (this.storedUsername || '').trim()
    }
    if (!owner) {
      owner = (this.sessionUsername || '').trim()
    }
    return owner ? 'member:' + owner : ''
  }

  private handleExpiredCookieSession(message: string): void {
    if (!message || message.indexOf('会话已失效') < 0) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CookieJarSettings.clear(context)
      .then(() => AuthSessionSettings.clear(context))
      .catch((_error: Error) => {
      })
      .finally(() => {
        this.resetNotificationState()
      })
  }
}
