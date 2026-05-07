import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  ApiV2Service,
  AuthSessionSettings,
  AuthSettings,
  CookieJarSettings,
  DateUtils,
  EmptyState,
  LoadingFooter,
  NotificationSettings,
  SecondaryListScaffold,
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

@Component
export struct NotificationPage {
  @Consume('ns') ns: NavPathStack
  @StorageLink(StorageKeys.AUTH_TOKEN_CONFIGURED) @Watch('onAuthChanged') authTokenConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_COOKIE_CONFIGURED) @Watch('onAuthChanged') authCookieConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_USERNAME) @Watch('onAuthChanged') storedUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_USERNAME) @Watch('onAuthChanged') sessionUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_UPDATED_AT) @Watch('onAuthChanged') authSessionUpdatedAt: number = 0
  @StorageLink(StorageKeys.LOCAL_DATA_UPDATED_AT) @Watch('onLocalDataUpdated') localDataUpdatedAt: number = 0
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
  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private notificationVm: NotificationCenterViewModel = new NotificationCenterViewModel(this.api)
  private readonly NOTIFICATION_PAGE_SIZE: number = 20
  onOpenAccount: () => void = () => {}

  aboutToAppear(): void {
    this.loadAuthSnapshot()
    this.loadNotificationCache(this.sessionUsername || this.storedUsername)
  }

  onAuthChanged(_propName: string): void {
    this.loadAuthSnapshot(true)
    this.resetNotificationState()
    this.loadNotificationCache(this.sessionUsername || this.storedUsername)
  }

  onLocalDataUpdated(_propName: string): void {
    this.resetNotificationState()
    this.loadNotificationCache(this.sessionUsername || this.storedUsername)
  }

  build() {
    Column() {
      if (!this.hasNotificationAuth()) {
        this.AuthRequiredView('登录后可查看通知')
      } else if (this.isNotificationLoading && this.notifications.length === 0) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE)
          .height(ThemeConstants.LOADING_SIZE)
      } else if (this.notificationError && this.notifications.length === 0) {
        this.NotificationErrorView()
      } else {
        SecondaryListScaffold({
          bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT,
          onReachEnd: () => {
            this.loadMoreNotifications()
          }
        }) {
          ListItem() {
            this.NotificationSummaryRow()
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
  }

  @Builder
  AuthRequiredView(message: string) {
    Column() {
      Text(message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('去我的页面配置')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => {
          this.onOpenAccount()
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder
  NotificationErrorView() {
    Column() {
      Text(this.notificationError)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => {
          this.loadNotifications(true)
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder
  NotificationSummaryRow() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(`${this.notifications.length} 条通知`)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        if (this.notificationError && this.notifications.length > 0) {
          Text(this.notificationError)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          if (this.notificationKindSummary()) {
            Text(this.notificationKindSummary())
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.notificationCacheUpdatedAt > 0) {
            Text(`${this.notificationLoadedFromCache ? '缓存于' :
              '更新于'} ${DateUtils.toDateString(this.notificationCacheUpdatedAt)}${this.notificationSourceLabel ?
              ' · ' + this.notificationSourceLabel : ''}`)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else if (this.notificationSourceLabel) {
            Text(`来源: ${this.notificationSourceLabel}`)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('刷新')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .height(ThemeConstants.TOUCH_TARGET_SM)
        .type(ButtonType.Normal)
        .borderRadius(ThemeConstants.RADIUS_MD)
        .enabled(!this.isNotificationLoading && !this.isNotificationLoadingMore)
        .onClick(() => {
          this.loadNotifications(true)
        })

      Button('批量清除')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .height(ThemeConstants.TOUCH_TARGET_SM)
        .type(ButtonType.Normal)
        .borderRadius(ThemeConstants.RADIUS_MD)
        .enabled(false)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder
  NotificationListItem(item: V2exNotification) {
    if (this.canDeleteNotifications()) {
      ListItem() {
        this.NotificationCard(item)
      }
      .onClick(() => { this.openNotification(item) })
      .swipeAction({ end: this.NotificationSwipeEnd(item) })
    } else {
      ListItem() {
        this.NotificationCard(item)
      }
      .onClick(() => { this.openNotification(item) })
    }
  }

  @Builder
  NotificationTag(text: string, backgroundColor: ResourceColor, foregroundColor: ResourceColor) {
    Text(text)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor(foregroundColor)
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: ThemeConstants.SPACE_XS / 2,
        bottom: ThemeConstants.SPACE_XS / 2
      })
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor(backgroundColor)
  }

  @Builder
  NotificationCard(item: V2exNotification) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        this.NotificationTag(
          this.notificationKindTag(item),
          $r('sys.color.ohos_id_color_sub_background'),
          $r('sys.color.font_secondary')
        )
        if (this.notificationReadTag(item)) {
          this.NotificationTag(
            this.notificationReadTag(item),
            this.notificationReadTag(item) === '未读' ? ThemeConstants.BRAND_PRIMARY :
              $r('sys.color.ohos_id_color_sub_background'),
            this.notificationReadTag(item) === '未读' ? Color.White : $r('sys.color.font_secondary')
          )
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      Text(this.notificationTitle(item))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.notificationBody(item))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (item.created) {
        Text(DateUtils.toRelativeTime(item.created))
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder
  NotificationSwipeEnd(item: V2exNotification) {
    Row() {
      Button('删除')
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .height(40)
        .fontColor(Color.White)
        .backgroundColor(Color.Red)
        .onClick(() => {
          this.confirmDeleteNotification(item)
        })
    }
    .height('100%')
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    .justifyContent(FlexAlign.Center)
  }

  private loadAuthSnapshot(forceNotifications: boolean = false): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.load(context)
      .then((snapshot) => {
        this.authToken = snapshot.token
        this.loadNotificationCache(snapshot.username)
        this.loadNotifications(forceNotifications)
      })
      .catch((error: Error) => {
        this.notificationError = error.message || '读取通知授权失败'
      })
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
    this.notificationVm.loadPage(authContext, 1, this.NOTIFICATION_PAGE_SIZE)
      .then((result: NotificationPageResult) => {
        this.notifications = result.items
        this.notificationPage = result.page
        this.notificationHasMore = result.hasMore
        this.notificationSourceLabel = result.sourceLabel
        this.notificationLoadedFromCache = false
        this.saveNotificationCache()
      })
      .catch((error: Error) => {
        const message = error.message || '通知加载失败'
        this.notificationError = message
        this.notificationHasMore = false
        this.handleExpiredCookieSession(message)
      })
      .finally(() => {
        this.isNotificationLoading = false
      })
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
