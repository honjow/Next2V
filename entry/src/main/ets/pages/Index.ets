import {
  HdsNavigation, HdsNavDestination, HdsTabs, HdsTabsController, HdsTabsFloatingStyle,
  hdsMaterial, HdsNavigationTitleMode, ScrollEffectType, BlurStrategy
} from '@kit.UIDesignKit'
import { common } from '@kit.AbilityKit'
import {
  ApiDomainSettings, HttpClient, ThemeConstants, StorageKeys, ApiConstants, TabItem,
  AuthSettings, ApiService, DateUtils
}
  from 'shared'
import type { V2exAuthenticatedMember, V2exNotification } from 'shared'
import { HomePage } from 'feed'
import { TopicDetailPage } from 'detail'
import { DiscoverPage, NodeTopicPage } from 'node'
import { UserProfilePage } from 'user'
import { ComponentContent } from '@kit.ArkUI'

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
  @StorageLink(StorageKeys.AUTH_TOKEN_CONFIGURED) authTokenConfigured: boolean = false
  @StorageLink(StorageKeys.AUTH_USERNAME) storedUsername: string = ''
  @State private authToken: string = ''
  @State private tokenDraft: string = ''
  @State private authProfile: V2exAuthenticatedMember | null = null
  @State private authError: string = ''
  @State private isAuthLoading: boolean = false
  @State private notifications: V2exNotification[] = []
  @State private notificationError: string = ''
  @State private isNotificationLoading: boolean = false
  private http: HttpClient = HttpClient.getInstance()
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.loadAuthSnapshot()
  }

  @Builder pm(name: string, param: Object) {
    if (name === 'TopicDetail') {
      HdsNavDestination() { TopicDetailPage({ topicId: (param as Record<string, Object>)['topicId'] as number }) }
        .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'NodeTopicList') {
      HdsNavDestination() {
        NodeTopicPage({ nodeName: (param as Record<string, Object>)['nodeName'] as string, nodeTitle: (param as Record<string, Object>)['nodeTitle'] as string })
      }.titleBar(this.navDestTitleBarOpts())
    } else if (name === 'UserProfile') {
      HdsNavDestination() { UserProfilePage({ username: (param as Record<string, Object>)['username'] as string }) }
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
          })
          if (this.notifications.length === 0) {
            ListItem() { this.EmptyNoticeView() }
          }
          ListItem() { Column() { Blank().height(this.bottomH + this.FLOAT_H) } }
        }
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
          Column() {
            Text('API 域名').fontSize(ThemeConstants.FONT_SIZE_BODY).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text(`当前: ${this.useCoDomain ? 'v2ex.co' : 'v2ex.com'}`)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_XS })
            Row({ space: ThemeConstants.SPACE_SM }) {
              Button('v2ex.com').fontSize(ThemeConstants.FONT_SIZE_TAG)
                .onClick(() => { this.updateApiDomain(false) })
              Button('v2ex.co').fontSize(ThemeConstants.FONT_SIZE_TAG)
                .onClick(() => { this.updateApiDomain(true) })
            }.margin({ top: ThemeConstants.SPACE_SM })
          }
            .padding(ThemeConstants.SPACE_LG).width('100%').alignItems(HorizontalAlign.Start).borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM }).height(130)

        ListItem() {
          Column() {
            Text('关于 Next2V').fontSize(ThemeConstants.FONT_SIZE_BODY).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text('版本 0.1.0').fontSize(ThemeConstants.FONT_SIZE_TAG).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_XS })
          }
            .padding(ThemeConstants.SPACE_LG).width('100%').alignItems(HorizontalAlign.Start).borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM }).height(80)
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
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ApiDomainSettings.save(context, useCoDomain).catch((error: Error) => {
      console.error('save api domain failed: ' + error.message)
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
        Text(this.authTokenConfigured ? '已配置' : '未配置')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor(this.authTokenConfigured ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_secondary'))
      }
      .width('100%')
      if (this.authProfile || this.storedUsername) {
        Text(this.authProfile?.username || this.storedUsername)
          .fontSize(ThemeConstants.FONT_SIZE_HEADING)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
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
          .enabled(!this.isAuthLoading)
          .onClick(() => { this.verifyAndSaveToken() })
        if (this.authTokenConfigured) {
          Button('退出')
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .onClick(() => { this.clearAuth() })
        }
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

  private loadAuthSnapshot(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.load(context)
      .then((snapshot) => {
        this.authToken = snapshot.token
        this.tokenDraft = ''
        if (snapshot.token) {
          this.refreshAuthProfile(snapshot.token)
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

  private clearAuth(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.clear(context)
      .then(() => {
        this.authToken = ''
        this.tokenDraft = ''
        this.authProfile = null
        this.authError = ''
        this.notifications = []
        this.notificationError = ''
      })
      .catch((error: Error) => {
        this.authError = error.message
      })
  }

  private loadNotifications(force: boolean = false): void {
    if (!this.authTokenConfigured || !this.authToken || this.isNotificationLoading) {
      return
    }
    if (this.notifications.length > 0 && !force) {
      return
    }
    this.isNotificationLoading = true
    this.notificationError = ''
    this.api.getNotifications(this.authToken)
      .then((items: V2exNotification[]) => {
        this.notifications = items
      })
      .catch((error: Error) => {
        this.notificationError = error.message || '通知加载失败'
      })
      .finally(() => {
        this.isNotificationLoading = false
      })
  }

  private notificationTitle(item: V2exNotification): string {
    return item.topic_title || item.title || item.member?.username || '通知'
  }

  private notificationBody(item: V2exNotification): string {
    return item.text || item.content || item.payload || item.content_rendered || item.payload_rendered || ''
  }
}
