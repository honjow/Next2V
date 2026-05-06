import {
  HdsNavigation, HdsNavDestination, HdsTabs, HdsTabsController, HdsTabsFloatingStyle,
  hdsMaterial, HdsNavigationTitleMode, ScrollEffectType, BlurStrategy
} from '@kit.UIDesignKit'
import { common } from '@kit.AbilityKit'
import {
  ApiDomainSettings, HttpClient, ThemeConstants, StorageKeys, ApiConstants, TabItem,
  AuthSettings, MediaSettings, WriteActionSettings, ApiService, ApiV2Service, DateUtils, CollectionSettings, TopicDetailParams, NodeTopicListParams, ImagePreviewParams, CacheSettings,
  CookieJarSettings, AuthSessionSettings, V2exSessionParser, LoadingFooter
}
  from 'shared'
import type { V2exAuthenticatedMember, V2exNotification, SavedTopic, SavedNode, ViewedTopic, CacheStats } from 'shared'
import type { V2exTokenInfo } from 'shared'
import { HomePage } from 'feed'
import { ReplyEditorPage, TopicDetailPage } from 'detail'
import { DiscoverPage, NodePickerPage, NodeTopicPage } from 'node'
import { UserProfilePage } from 'user'
import { ComponentContent, promptAction } from '@kit.ArkUI'
import { V2exWebLoginPage } from './V2exWebLoginPage'
import { V2exNativeLoginPage } from './V2exNativeLoginPage'
import { ImagePreviewPage } from './ImagePreviewPage'
import { SearchPage } from './SearchPage'
import { TopicEditorPage } from './TopicEditorPage'

@Component
struct FeedPills {
  @StorageLink('feedTab') feedTab: string = 'tech'

  build() {
    Scroll() {
      Row({ space: ThemeConstants.SPACE_XS }) {
        ForEach(ApiConstants.TAB_ITEMS, (tab: TabItem) => {
          Column({ space: 2 }) {
            Text(tab.label)
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(this.feedTab === tab.key ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.TEXT_SECONDARY)
              .fontWeight(this.feedTab === tab.key ? FontWeight.Medium : FontWeight.Regular)
              .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })
            if (this.feedTab === tab.key) {
              Divider().strokeWidth(2).color(ThemeConstants.BRAND_PRIMARY).width(18)
            }
          }
          .alignItems(HorizontalAlign.Center)
          .padding({ bottom: ThemeConstants.SPACE_XS })
          .onClick(() => { this.feedTab = tab.key })
        })
      }
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      .alignItems(VerticalAlign.Center).height('100%')
    }
    .scrollBar(BarState.Off)
    .scrollable(ScrollDirection.Horizontal)
    .width('100%').height('100%')
  }
}

@Builder
function PillCCBuilder() { FeedPills() }

@Entry
@Component
struct Index {
  @Provide('ns') ns: NavPathStack = new NavPathStack()
  private tc: HdsTabsController = new HdsTabsController()
  private tabTitles: string[] = ['首页', '发现', '通知', '我的']
  @State ct: number = 0
  @StorageLink(StorageKeys.USE_CO_DOMAIN) useCoDomain: boolean = false
  @StorageLink(StorageKeys.MEDIA_AUTO_LOAD_IMAGES) autoLoadImages: boolean = true
  @StorageLink(StorageKeys.AUTH_TOKEN_CONFIGURED) authTokenConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_COOKIE_CONFIGURED) authCookieConfigured: boolean = false
  @StorageLink(StorageKeys.ACCOUNT_WRITE_ENABLED) accountWriteEnabled: boolean = false
  @StorageLink(StorageKeys.AUTH_USERNAME) storedUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_USERNAME) sessionUsername: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_AVATAR) sessionAvatar: string = ''
  @StorageLink(StorageKeys.AUTH_SESSION_VALIDATED_AT) sessionValidatedAt: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_LIMIT) apiRateLimitLimit: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_REMAINING) apiRateLimitRemaining: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_RESET) apiRateLimitReset: number = 0
  @StorageLink(StorageKeys.API_RATE_LIMIT_UPDATED_AT) apiRateLimitUpdatedAt: number = 0
  @State private authToken: string = ''
  @State private tokenDraft: string = ''
  @State private authProfile: V2exAuthenticatedMember | null = null
  @State private tokenInfo: V2exTokenInfo | null = null
  @State private tokenInfoError: string = ''
  @State private authError: string = ''
  @State private sessionError: string = ''
  @State private isSessionValidating: boolean = false
  @State private isAuthLoading: boolean = false
  @State private notifications: V2exNotification[] = []
  @State private savedTopics: SavedTopic[] = []
  @State private savedNodes: SavedNode[] = []
  @State private viewedTopics: ViewedTopic[] = []
  @State private cacheStats: CacheStats = { topicListCount: 0, topicDetailCount: 0, updatedAt: 0 }
  @State private cacheMessage: string = ''
  @State private notificationError: string = ''
  @State private isNotificationLoading: boolean = false
  @State private isNotificationDeleting: boolean = false
  @State private notificationPage: number = 1
  @State private notificationHasMore: boolean = true
  @State private isNotificationLoadingMore: boolean = false
  private http: HttpClient = HttpClient.getInstance()
  private api: ApiService = new ApiService()
  private apiV2: ApiV2Service = new ApiV2Service()
  private readonly NOTIFICATION_PAGE_SIZE: number = 20

  aboutToAppear(): void {
    this.loadAuthSnapshot()
    this.loadSessionSnapshot()
    this.loadSavedTopics()
    this.loadSavedNodes()
    this.loadViewedTopics()
    this.loadTopicReadStates()
    this.loadCacheStats()
  }

  @Builder pm(name: string, param: Object) {
    if (name === 'TopicDetail') {
      HdsNavDestination() { TopicDetailPage({ topicId: (param as Record<string, Object>)['topicId'] as number }) }
        .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'ImagePreview') {
      HdsNavDestination() { ImagePreviewPage({ url: (param as ImagePreviewParams).url }) }
        .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'NodeTopicList') {
      HdsNavDestination() {
        NodeTopicPage({ nodeName: (param as Record<string, Object>)['nodeName'] as string, nodeTitle: (param as Record<string, Object>)['nodeTitle'] as string })
      }.titleBar(this.navDestTitleBarOpts())
    } else if (name === 'ReplyEditor') {
      HdsNavDestination() {
        ReplyEditorPage({
          topicId: ((param as Record<string, Object>)['topicId'] as number) || 0,
          topicTitle: ((param as Record<string, Object>)['topicTitle'] as string) || ''
        })
      }.titleBar(this.navDestTitleBarOpts())
    } else if (name === 'UserProfile') {
      HdsNavDestination() { UserProfilePage({ username: (param as Record<string, Object>)['username'] as string }) }
        .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'V2exWebLogin') {
      HdsNavDestination() { V2exWebLoginPage() }
        .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'V2exNativeLogin') {
      HdsNavDestination() { V2exNativeLoginPage() }
        .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'NodePicker') {
      HdsNavDestination() { NodePickerPage() }
        .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'Search') {
      HdsNavDestination() { SearchPage() }
        .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'TopicEditor') {
      HdsNavDestination() { TopicEditorPage() }
        .titleBar(this.navDestTitleBarOpts())
    }
  }

  build() {
    HdsNavigation(this.ns) {
      HdsTabs({ controller: this.tc, index: this.ct }) {
        TabContent() { HomePage() }.tabBar(this.TabIcon('首页', 0))
        TabContent() { DiscoverPage() }.tabBar(this.TabIcon('发现', 1))
        TabContent() { this.NotifyPage() }.tabBar(this.TabIcon('通知', 2))
        TabContent() { this.MePage() }.tabBar(this.TabIcon('我的', 3))
      }
        .barOverlap(true).barPosition(BarPosition.End).barMode(BarMode.Fixed)
        .scrollable(false)
        .animationDuration(0)
        .barFloatingStyle({
          barBottomMargin: ThemeConstants.SPACE_XL,
          systemMaterialEffect: { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }
        } as HdsTabsFloatingStyle)
        .onChange((i: number) => {
          this.ct = i
          if (i === 2) {
            this.loadNotifications()
          } else if (i === 3) {
            this.validateCookieSession()
            this.loadSavedTopics()
            this.loadSavedNodes()
            this.loadViewedTopics()
            this.loadCacheStats()
          }
        })
    }
      .titleBar(this.titleBarOptions())
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .navDestination(this.pm).mode(NavigationMode.Stack).width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private navDestTitleBarOpts(): Record<string, Object> {
    let mat: Record<string, Object> = { 'materialType': hdsMaterial.MaterialType.ADAPTIVE, 'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE }
    let scrollOpts: Record<string, Object> = { 'enableScrollEffect': true, 'scrollEffectType': ScrollEffectType.GRADIENT_BLUR }
    let style: Record<string, Object> = { 'systemMaterialEffect': mat, 'scrollEffectOpts': scrollOpts }
    return { 'avoidLayoutSafeArea': true, 'enableComponentSafeArea': false, 'blurStrategy': BlurStrategy.ENABLE, 'style': style }
  }

  private titleBarOptions(): Record<string, Object> {
    let titleInfo: Record<string, Object> = { 'mainTitle': this.tabTitles[this.ct] }
    let content: Record<string, Object>
    if (this.ct === 0) {
      let cc = new ComponentContent(this.getUIContext(), wrapBuilder(PillCCBuilder))
      let bb: Record<string, Object> = { 'builderComponent': cc, 'height': ApiConstants.TAB_BAR_HEIGHT, 'showType': 0 }
      content = { 'title': titleInfo, 'bottomBuilder': bb }
    } else {
      content = { 'title': titleInfo }
    }
    let mat: Record<string, Object> = { 'materialType': hdsMaterial.MaterialType.ADAPTIVE, 'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE }
    let scrollOpts: Record<string, Object> = { 'enableScrollEffect': true, 'scrollEffectType': ScrollEffectType.GRADIENT_BLUR }
    let style: Record<string, Object> = { 'systemMaterialEffect': mat, 'scrollEffectOpts': scrollOpts }
    return { 'avoidLayoutSafeArea': true, 'enableComponentSafeArea': false, 'blurStrategy': BlurStrategy.ENABLE, 'content': content, 'style': style }
  }

  @Builder TabIcon(title: string, idx: number) {
    Column() {
      SymbolGlyph(idx === 0 ? $r('sys.symbol.house_fill')
        : idx === 1 ? $r('sys.symbol.square_fill_grid_2x2')
        : idx === 2 ? $r('sys.symbol.bell_fill')
        : $r('sys.symbol.person_fill'))
        .fontSize(ThemeConstants.INDICATOR_SIZE - 6).renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
        .fontColor([this.ct === idx ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_secondary')])
      Text(title).fontSize(ThemeConstants.FONT_SIZE_TINY).fontColor(this.ct === idx ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_secondary'))
    }
      .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center).width('100%').height('100%')
      .padding({ top: ThemeConstants.SPACE_SM - 2, bottom: ThemeConstants.SPACE_XS })
  }

  // NotifyPage 和 MePage 较为简单，保留在 Index 文件内
  @StorageProp('topAvoidHeight') topH: number = 0
  @StorageProp('bottomAvoidHeight') bottomH: number = 0
  private readonly TBH: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly FLOAT_H: number = ThemeConstants.FLOAT_BAR_HEIGHT

  @Builder NotifyPage() {
    Column() {
      if (!this.authTokenConfigured) {
        this.AuthRequiredView('配置 Personal Access Token 后可查看通知')
      } else if (this.isNotificationLoading && this.notifications.length === 0) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE)
          .height(ThemeConstants.LOADING_SIZE)
      } else if (this.notificationError && this.notifications.length === 0) {
        this.NotificationErrorView()
      } else {
        List({ space: ThemeConstants.SPACE_SM }) {
          ListItem() { Column() { Blank().height(this.topH + this.TBH) } }
          ForEach(this.notifications, (item: V2exNotification) => {
            ListItem() { this.NotificationCard(item) }
              .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
              .onClick(() => {
                const topicId = item.topic_id || 0
                if (topicId > 0) {
                  let p: TopicDetailParams = { topicId: topicId }
                  this.ns.pushPathByName('TopicDetail', p as Object)
                }
              })
              .swipeAction({ end: this.NotificationSwipeEnd(item) })
          })
          if (this.notifications.length === 0) {
            ListItem() { this.EmptyNoticeView() }
          }
          if (this.notifications.length > 0) {
            ListItem() {
              LoadingFooter({ isLoading: this.isNotificationLoadingMore, hasMore: this.notificationHasMore })
            }
              .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
          }
          ListItem() { Column() { Blank().height(this.bottomH + this.FLOAT_H) } }
        }
        .onReachEnd(() => {
          this.loadMoreNotifications()
        })
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
    }
      .justifyContent(FlexAlign.Center)
      .width('100%').height('100%')
      .padding({ top: this.topH + this.TBH, bottom: this.bottomH + this.FLOAT_H })
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder MePage() {
    Column() {
      List() {
        ListItem() {
          this.AuthCard()
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.SavedTopicsCard()
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })

        ListItem() {
          this.ViewedTopicsCard()
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })

        ListItem() {
          Column() {
            Text('搜索')
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Text('在本地数据 / 节点库 / 网页搜索中查找')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ top: ThemeConstants.SPACE_XS })
            Row({ space: ThemeConstants.SPACE_SM }) {
              Button('打开')
                .fontSize(ThemeConstants.FONT_SIZE_TAG)
                .height(40)
                .onClick(() => { this.ns.pushPathByName('Search', null) })
            }.margin({ top: ThemeConstants.SPACE_SM })
          }
            .padding(ThemeConstants.SPACE_LG)
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })

        ListItem() {
          this.SavedNodesCard()
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })

        ListItem() {
          this.CacheCard()
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })

        ListItem() {
          Column() {
            Text('图片加载').fontSize(ThemeConstants.FONT_SIZE_BODY).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text(`自动加载: ${this.autoLoadImages ? '开启' : '关闭'}`)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_XS })
            Row({ space: ThemeConstants.SPACE_SM }) {
              Button('开启').fontSize(ThemeConstants.FONT_SIZE_TAG)
                .height(40)
                .onClick(() => { this.updateAutoLoadImages(true) })
              Button('关闭').fontSize(ThemeConstants.FONT_SIZE_TAG)
                .height(40)
                .onClick(() => { this.updateAutoLoadImages(false) })
            }.margin({ top: ThemeConstants.SPACE_SM })
          }
            .padding(ThemeConstants.SPACE_LG).width('100%').alignItems(HorizontalAlign.Start).borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })

        ListItem() {
          Column() {
            Text('写入操作')
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Text(`全局开关: ${this.accountWriteEnabled ? '开启' : '关闭'}`)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(this.accountWriteEnabled ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_secondary'))
              .margin({ top: ThemeConstants.SPACE_XS })
            Text('开启后会显示写入相关 UI，提交仍需二次确认。')
              .fontSize(ThemeConstants.FONT_SIZE_TINY)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ top: ThemeConstants.SPACE_XS })
            Row({ space: ThemeConstants.SPACE_SM }) {
              Button('开启')
                .fontSize(ThemeConstants.FONT_SIZE_TAG)
                .height(40)
                .enabled(!this.accountWriteEnabled)
                .onClick(() => { this.confirmEnableWriteActions() })
              Button('关闭')
                .fontSize(ThemeConstants.FONT_SIZE_TAG)
                .height(40)
                .enabled(this.accountWriteEnabled)
                .onClick(() => { this.updateWriteActions(false) })
            }.margin({ top: ThemeConstants.SPACE_SM })
          }
            .padding(ThemeConstants.SPACE_LG)
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })

        ListItem() {
          Column() {
            Text('发帖草稿')
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Text('编辑/预览新主题草稿（不会提交）')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ top: ThemeConstants.SPACE_XS })
            Row({ space: ThemeConstants.SPACE_SM }) {
              Button('打开')
                .fontSize(ThemeConstants.FONT_SIZE_TAG)
                .height(40)
                .onClick(() => { this.ns.pushPathByName('TopicEditor', null) })
            }.margin({ top: ThemeConstants.SPACE_SM })
          }
            .padding(ThemeConstants.SPACE_LG)
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })

        ListItem() {
          Column() {
            Text('API 域名').fontSize(ThemeConstants.FONT_SIZE_BODY).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text(`当前: ${this.useCoDomain ? 'v2ex.co' : 'v2ex.com'}`)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_XS })
            Row({ space: ThemeConstants.SPACE_SM }) {
              Button('v2ex.com').fontSize(ThemeConstants.FONT_SIZE_TAG)
                .height(40)
                .onClick(() => { this.updateApiDomain(false) })
              Button('v2ex.co').fontSize(ThemeConstants.FONT_SIZE_TAG)
                .height(40)
                .onClick(() => { this.updateApiDomain(true) })
            }.margin({ top: ThemeConstants.SPACE_SM })
          }
            .padding(ThemeConstants.SPACE_LG).width('100%').alignItems(HorizontalAlign.Start).borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })

        ListItem() {
          Column() {
            Text('关于 Next2V').fontSize(ThemeConstants.FONT_SIZE_BODY).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text('版本 0.1.0').fontSize(ThemeConstants.FONT_SIZE_TAG).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_XS })
          }
            .padding(ThemeConstants.SPACE_LG).width('100%').alignItems(HorizontalAlign.Start).borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM })
      }
        .scrollBar(BarState.Off)
        .padding({ top: this.topH + this.TBH, bottom: this.bottomH + this.FLOAT_H })
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private updateApiDomain(useCoDomain: boolean): void {
    this.useCoDomain = useCoDomain
    this.http.setBaseUrl(useCoDomain ? ApiConstants.BASE_URL_CO : ApiConstants.BASE_URL_COM)
    CookieJarSettings.refreshConfiguredState()
    CookieJarSettings.restoreCurrentToWebCookieManager().catch((error: Error) => {
      console.error('restore web cookie failed: ' + error.message)
    })
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ApiDomainSettings.save(context, useCoDomain).catch((error: Error) => {
      console.error('save api domain failed: ' + error.message)
    })
  }

  private updateAutoLoadImages(autoLoadImages: boolean): void {
    this.autoLoadImages = autoLoadImages
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    MediaSettings.save(context, autoLoadImages).catch((error: Error) => {
      console.error('save media settings failed: ' + error.message)
    })
  }

  private confirmEnableWriteActions(): void {
    if (this.accountWriteEnabled) {
      return
    }
    AlertDialog.show({
      title: '开启写入操作',
      message: '写入操作可能导致误触或误操作。确定开启吗？',
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '开启',
        fontColor: ThemeConstants.BRAND_PRIMARY,
        action: () => { this.updateWriteActions(true) }
      }
    })
  }

  private updateWriteActions(enabled: boolean): void {
    this.accountWriteEnabled = enabled
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    WriteActionSettings.save(context, enabled).catch((error: Error) => {
      console.error('save write settings failed: ' + error.message)
    })
  }

  private loadSessionSnapshot(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CookieJarSettings.load(context)
      .then(() => {
        this.validateCookieSession()
      })
      .catch((error: Error) => {
        console.error('restore cookie jar failed: ' + error.message)
      })
    AuthSessionSettings.load(context).catch((error: Error) => {
      console.error('restore auth session failed: ' + error.message)
    })
  }

  private validateCookieSession(force: boolean = false): void {
    if (this.isSessionValidating) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      return
    }
    const now = Date.now()
    if (!force && this.sessionValidatedAt > 0 && now - this.sessionValidatedAt < 10 * 60 * 1000) {
      return
    }

    this.isSessionValidating = true
    this.sessionError = ''

    const headers: Record<string, string> = { 'Cookie': cookie }
    this.http.getTextWithHeaders('/settings', headers)
      .then((html: string) => {
        const username = V2exSessionParser.extractUsername(html)
        if (!username) {
          throw new Error('Web 会话已失效，请重新登录')
        }
        return this.api.getMember(username)
          .then((profile) => {
            const context = this.getUIContext().getHostContext() as common.UIAbilityContext
            return AuthSessionSettings.save(context, {
              loginMode: 'cookie',
              username: username,
              avatar: profile.avatar_normal || '',
              validatedAt: Date.now()
            })
          })
      })
      .catch((error: Error) => {
        this.sessionError = error.message || 'Web 会话验证失败'
      })
      .finally(() => {
        this.isSessionValidating = false
      })
  }

  @Builder AuthCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row() {
        Text('V2EX 登录')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text(this.authCookieConfigured ? 'Web 已登录' : (this.authTokenConfigured ? 'Token 已配置' : '未登录'))
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor((this.authCookieConfigured || this.authTokenConfigured) ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_secondary'))
      }
      .width('100%')
      if (this.sessionUsername || this.authProfile || this.storedUsername) {
        Text(this.sessionUsername || this.authProfile?.username || this.storedUsername)
          .fontSize(ThemeConstants.FONT_SIZE_HEADING)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      if (this.authProfile) {
        if (this.authProfile.tagline) {
          Text(this.authProfile.tagline)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (this.authProfile.location) {
          Text(`位置: ${this.authProfile.location}`)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }
        if (this.authProfile.created && this.authProfile.created > 0) {
          Text(`注册: ${DateUtils.toDateString(this.authProfile.created)}`)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      if (this.authCookieConfigured && this.isSessionValidating) {
        Text('Web 会话验证中…')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      if (this.sessionError) {
        Text(this.sessionError)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
      }
      if (this.tokenInfoError) {
        Text(this.tokenInfoError)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
      } else if (this.tokenInfo) {
        if (this.tokenInfo.scope) {
          Text(`Token Scope: ${this.tokenInfo.scope}`)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
        if (this.tokenInfo.expiration && this.tokenInfo.expiration > 0) {
          Text(`到期: ${DateUtils.toDateString(this.tokenInfo.expiration)}`)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }
        if (this.tokenInfo.last_used && this.tokenInfo.last_used > 0) {
          Text(`最后使用: ${DateUtils.toDateString(this.tokenInfo.last_used)}`)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      if (this.apiRateLimitLimit > 0) {
        Text(`API Rate Limit: ${this.apiRateLimitRemaining} / ${this.apiRateLimitLimit}`)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        if (this.apiRateLimitReset > 0) {
          Text(`重置时间: ${DateUtils.toDateString(this.apiRateLimitReset)}`)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }
        if (this.apiRateLimitUpdatedAt > 0) {
          Text(`更新于 ${DateUtils.toDateString(this.apiRateLimitUpdatedAt)}`)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      Button('网页登录（推荐）')
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .height(40)
        .onClick(() => { this.ns.pushPathByName('V2exWebLogin', null) })
      Button('账号密码登录')
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .height(40)
        .onClick(() => { this.ns.pushPathByName('V2exNativeLogin', null) })
      TextInput({ placeholder: 'Personal Access Token', text: this.tokenDraft })
        .height(44)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .type(InputType.Password)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(ThemeConstants.RADIUS_MD)
        .onChange((value: string) => { this.tokenDraft = value })
      if (this.authError) {
        Text(this.authError)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
      }
      Row({ space: ThemeConstants.SPACE_SM }) {
        Button(this.isAuthLoading ? '验证中' : '保存并验证')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .enabled(!this.isAuthLoading)
          .onClick(() => { this.verifyAndSaveToken() })
        if (this.authTokenConfigured || this.authCookieConfigured) {
          Button('退出')
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .height(40)
            .onClick(() => { this.logoutAll() })
        }
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder SavedTopicsCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row() {
        Text('稍后读')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text(`${this.savedTopics.length}`)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      if (this.savedTopics.length === 0) {
        Text('在主题详情页保存后会显示在这里')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      } else {
        ForEach(this.savedTopics.slice(0, 3), (item: SavedTopic) => {
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(item.title)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Row({ space: ThemeConstants.SPACE_XS }) {
              Text(item.nodeTitle)
                .fontSize(ThemeConstants.FONT_SIZE_TINY)
                .fontColor($r('sys.color.font_secondary'))
              Text('·')
                .fontSize(ThemeConstants.FONT_SIZE_TINY)
                .fontColor($r('sys.color.font_secondary'))
              Text(DateUtils.toDateString(item.savedAt))
                .fontSize(ThemeConstants.FONT_SIZE_TINY)
                .fontColor($r('sys.color.font_secondary'))
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
          .onClick(() => {
            let p: TopicDetailParams = { topicId: item.id }
            this.ns.pushPathByName('TopicDetail', p as Object)
          })
        }, (item: SavedTopic) => item.id.toString())
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder SavedNodesCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row() {
        Text('关注节点')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text(`${this.savedNodes.length}`)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      if (this.savedNodes.length === 0) {
        Text('在节点主题页关注后会显示在这里')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      } else {
        ForEach(this.savedNodes.slice(0, 4), (item: SavedNode) => {
          Row() {
            Column({ space: ThemeConstants.SPACE_XS }) {
              Text(item.title)
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(item.name)
                .fontSize(ThemeConstants.FONT_SIZE_TINY)
                .fontColor($r('sys.color.font_secondary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text(DateUtils.toDateString(item.savedAt))
              .fontSize(ThemeConstants.FONT_SIZE_TINY)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .padding({ top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
          .onClick(() => {
            let p: NodeTopicListParams = { nodeName: item.name, nodeTitle: item.title }
            this.ns.pushPathByName('NodeTopicList', p as Object)
          })
        }, (item: SavedNode) => item.name)
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder ViewedTopicsCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row() {
        Text('最近浏览')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text(`${this.viewedTopics.length}`)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      if (this.viewedTopics.length === 0) {
        Text('打开主题详情后会自动记录')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      } else {
        ForEach(this.viewedTopics.slice(0, 3), (item: ViewedTopic) => {
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(item.title)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Row({ space: ThemeConstants.SPACE_XS }) {
              Text(item.nodeTitle)
                .fontSize(ThemeConstants.FONT_SIZE_TINY)
                .fontColor($r('sys.color.font_secondary'))
              Text('·')
                .fontSize(ThemeConstants.FONT_SIZE_TINY)
                .fontColor($r('sys.color.font_secondary'))
              Text(DateUtils.toDateString(item.viewedAt))
                .fontSize(ThemeConstants.FONT_SIZE_TINY)
                .fontColor($r('sys.color.font_secondary'))
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
          .onClick(() => {
            let p: TopicDetailParams = { topicId: item.id }
            this.ns.pushPathByName('TopicDetail', p as Object)
          })
        }, (item: ViewedTopic) => item.id.toString())
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder CacheCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row() {
        Text('离线缓存')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text(`${this.cacheStats.topicListCount + this.cacheStats.topicDetailCount}`)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      Text(`列表 ${this.cacheStats.topicListCount} 组 · 详情 ${this.cacheStats.topicDetailCount} 篇`)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
      if (this.cacheStats.updatedAt > 0) {
        Text(`更新于 ${DateUtils.toDateString(this.cacheStats.updatedAt)}`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      if (this.cacheMessage) {
        Text(this.cacheMessage)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      }
      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('刷新状态')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .onClick(() => { this.loadCacheStats() })
        Button('清理缓存')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .onClick(() => { this.clearCache() })
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder AuthRequiredView(message: string) {
    Column() {
      Text(message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('去我的页面配置')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.tc.changeIndex(3) })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder NotificationErrorView() {
    Column() {
      Text(this.notificationError)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.loadNotifications(true) })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder EmptyNoticeView() {
    Column() {
      Text('暂无通知')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder NotificationCard(item: V2exNotification) {
    Column({ space: ThemeConstants.SPACE_XS }) {
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
        Text(DateUtils.toDateString(item.created))
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

  @Builder NotificationSwipeEnd(item: V2exNotification) {
    Row() {
      Button('删除')
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .height(40)
        .fontColor(Color.White)
        .backgroundColor(Color.Red)
        .onClick(() => { this.confirmDeleteNotification(item) })
    }
    .height('100%')
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    .justifyContent(FlexAlign.Center)
  }

  private confirmDeleteNotification(item: V2exNotification): void {
    const id = item.id || 0
    if (id <= 0 || this.isNotificationDeleting) {
      return
    }
    AlertDialog.show({
      title: '删除通知',
      message: '确定删除这条通知吗？',
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: () => { this.deleteNotification(id) }
      }
    })
  }

  private deleteNotification(notificationId: number): void {
    if (!this.authTokenConfigured || !this.authToken || this.isNotificationDeleting) {
      return
    }
    this.isNotificationDeleting = true
    this.apiV2.deleteNotification(this.authToken, notificationId)
      .then(() => {
        this.notifications = this.notifications.filter(item => item.id !== notificationId)
        promptAction.openToast({ message: '已删除' }).catch((_error: Error) => { })
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '删除失败' }).catch((_error: Error) => { })
      })
      .finally(() => {
        this.isNotificationDeleting = false
      })
  }

  private loadAuthSnapshot(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.load(context)
      .then((snapshot) => {
        this.authToken = snapshot.token
        this.tokenDraft = ''
        if (snapshot.token) {
          this.refreshAuthProfile(snapshot.token)
          this.refreshTokenInfo(snapshot.token)
        }
      })
      .catch((error: Error) => {
        this.authError = error.message
      })
  }

  private verifyAndSaveToken(): void {
    const token = this.tokenDraft.trim() || this.authToken
    if (!token) {
      this.authError = '请输入 Personal Access Token'
      return
    }
    this.isAuthLoading = true
    this.authError = ''
    this.api.getAuthenticatedMember(token)
      .then((profile: V2exAuthenticatedMember) => {
        const username = profile.username || ''
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext
        this.authProfile = profile
        this.authToken = token
        this.storedUsername = username
        return AuthSettings.saveToken(context, token, username)
      })
      .then(() => {
        this.tokenDraft = ''
        this.refreshTokenInfo(token)
        this.loadNotifications(true)
      })
      .catch((error: Error) => {
        this.authError = error.message || 'Token 验证失败'
      })
      .finally(() => {
        this.isAuthLoading = false
      })
  }

  private refreshAuthProfile(token: string): void {
    this.api.getAuthenticatedMember(token)
      .then((profile: V2exAuthenticatedMember) => {
        this.authProfile = profile
        this.storedUsername = profile.username || this.storedUsername
      })
      .catch((error: Error) => {
        this.authError = error.message || '登录状态验证失败'
      })
  }

  private refreshTokenInfo(token: string): void {
    this.tokenInfoError = ''
    this.api.getTokenInfo(token)
      .then((info: V2exTokenInfo) => {
        if (info && info.success === false) {
          this.tokenInfo = null
          this.tokenInfoError = info.message || 'Token 信息获取失败'
          return
        }
        this.tokenInfo = info
        this.tokenInfoError = ''
      })
      .catch((error: Error) => {
        this.tokenInfo = null
        this.tokenInfoError = error.message || 'Token 信息获取失败'
      })
  }

  private clearAuth(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.clear(context)
      .then(() => {
        this.authToken = ''
        this.tokenDraft = ''
        this.authProfile = null
        this.tokenInfo = null
        this.tokenInfoError = ''
        this.authError = ''
        this.notifications = []
        this.notificationError = ''
        this.notificationPage = 1
        this.notificationHasMore = true
        this.isNotificationLoadingMore = false
      })
      .catch((error: Error) => {
        this.authError = error.message
      })
  }

  private logoutAll(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.isAuthLoading = false
    this.isSessionValidating = false
    this.authError = ''
    this.sessionError = ''

    Promise.all([
      AuthSettings.clear(context).catch((error: Error) => { this.authError = error.message || '清除 Token 失败' }),
      AuthSessionSettings.clear(context).catch((error: Error) => { this.sessionError = error.message || '清除会话失败' }),
      CookieJarSettings.clear(context).catch((error: Error) => { this.sessionError = error.message || '清除 Cookie 失败' })
    ])
      .finally(() => {
        this.authToken = ''
        this.tokenDraft = ''
        this.authProfile = null
        this.tokenInfo = null
        this.tokenInfoError = ''
        this.notifications = []
        this.notificationError = ''
        this.notificationPage = 1
        this.notificationHasMore = true
        this.isNotificationLoadingMore = false
      })
  }

  private loadNotifications(force: boolean = false): void {
    if (!this.authTokenConfigured || !this.authToken || this.isNotificationLoading || this.isNotificationLoadingMore) {
      return
    }
    if (this.notifications.length > 0 && !force) {
      return
    }
    this.isNotificationLoading = true
    this.notificationError = ''
    this.notificationPage = 1
    this.notificationHasMore = true
    this.api.getNotifications(this.authToken, 1)
      .then((items: V2exNotification[]) => {
        this.notifications = items
        this.notificationHasMore = items.length >= this.NOTIFICATION_PAGE_SIZE
      })
      .catch((error: Error) => {
        this.notificationError = error.message || '通知加载失败'
        this.notificationHasMore = false
      })
      .finally(() => {
        this.isNotificationLoading = false
      })
  }

  private loadMoreNotifications(): void {
    if (!this.authTokenConfigured || !this.authToken || this.isNotificationLoading || this.isNotificationLoadingMore || !this.notificationHasMore) {
      return
    }
    const nextPage = this.notificationPage + 1
    this.isNotificationLoadingMore = true
    this.notificationError = ''
    this.api.getNotifications(this.authToken, nextPage)
      .then((items: V2exNotification[]) => {
        if (!items || items.length === 0) {
          this.notificationHasMore = false
          return
        }
        const existing = new Set<number>(this.notifications.map(item => item.id))
        const unique = items.filter(item => item && item.id > 0 && !existing.has(item.id))
        if (unique.length === 0) {
          this.notificationHasMore = false
          return
        }
        this.notifications = this.notifications.concat(unique)
        this.notificationPage = nextPage
        this.notificationHasMore = items.length >= this.NOTIFICATION_PAGE_SIZE
      })
      .catch((error: Error) => {
        this.notificationError = error.message || '加载更多失败'
        this.notificationHasMore = false
      })
      .finally(() => {
        this.isNotificationLoadingMore = false
      })
  }

  private loadSavedTopics(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadSavedTopics(context)
      .then((items: SavedTopic[]) => {
        this.savedTopics = items
      })
      .catch((error: Error) => {
        console.error('load saved topics failed: ' + error.message)
      })
  }

  private loadSavedNodes(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadSavedNodes(context)
      .then((items: SavedNode[]) => {
        this.savedNodes = items
      })
      .catch((error: Error) => {
        console.error('load saved nodes failed: ' + error.message)
      })
  }

  private loadViewedTopics(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.loadViewedTopics(context)
      .then((items: ViewedTopic[]) => {
        this.viewedTopics = items
      })
      .catch((error: Error) => {
        console.error('load viewed topics failed: ' + error.message)
      })
  }

  private loadTopicReadStates(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.syncTopicReadStates(context)
      .catch((error: Error) => {
        console.error('sync topic read states failed: ' + error.message)
      })
  }

  private loadCacheStats(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CacheSettings.loadStats(context)
      .then((stats: CacheStats) => {
        this.cacheStats = stats
      })
      .catch((error: Error) => {
        console.error('load cache stats failed: ' + error.message)
      })
  }

  private clearCache(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CacheSettings.clear(context)
      .then(() => {
        this.cacheMessage = '已清理'
        this.loadCacheStats()
      })
      .catch((error: Error) => {
        this.cacheMessage = error.message || '清理失败'
      })
  }

  private notificationTitle(item: V2exNotification): string {
    return item.topic_title || item.title || item.member?.username || '通知'
  }

  private notificationBody(item: V2exNotification): string {
    return item.text || item.content || item.payload || item.content_rendered || item.payload_rendered || ''
  }
}
