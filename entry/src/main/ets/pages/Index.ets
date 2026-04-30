import {
  HdsNavigation, HdsNavDestination, HdsTabs, HdsTabsController, HdsTabsFloatingStyle,
  hdsMaterial, HdsNavigationTitleMode, ScrollEffectType, BlurStrategy
} from '@kit.UIDesignKit'
import { HttpClient, ThemeConstants, StorageKeys } from 'shared'
import { HomePage } from 'feed'
import { TopicDetailPage } from 'detail'
import { DiscoverPage, NodeTopicPage } from 'node'
import { UserProfilePage } from 'user'

@Entry
@Component
struct Index {
  @Provide('ns') ns: NavPathStack = new NavPathStack()
  private tc: HdsTabsController = new HdsTabsController()
  private tabTitles: string[] = ['首页', '发现', '通知', '我的']
  @State ct: number = 0
  @State useCoDomain: boolean = false
  private http: HttpClient = HttpClient.getInstance()

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
        .barFloatingStyle({
          barBottomMargin: ThemeConstants.SPACE_XL,
          systemMaterialEffect: { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }
        } as HdsTabsFloatingStyle)
        .onChange((i: number) => { this.ct = i })
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
    return { 'avoidLayoutSafeArea': true }
  }

  private titleBarOptions(): Record<string, Object> {
    let titleInfo: Record<string, Object> = { 'mainTitle': this.tabTitles[this.ct] }
    let content: Record<string, Object> = { 'title': titleInfo }
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
      Text('通知').fontSize(ThemeConstants.FONT_SIZE_HEADING + 2).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Text('登录后可查看').fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_SM })
    }
      .justifyContent(FlexAlign.Center).width('100%').height('100%')
      .padding({ top: this.topH + this.TBH, bottom: this.bottomH + this.FLOAT_H })
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder MePage() {
    Column() {
      List() {
        ListItem() {
          Column() {
            Text('API 域名').fontSize(ThemeConstants.FONT_SIZE_BODY).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text(`当前: ${this.useCoDomain ? 'v2ex.co' : 'v2ex.com'}`)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_XS })
            Row({ space: ThemeConstants.SPACE_SM }) {
              Button('v2ex.com').fontSize(ThemeConstants.FONT_SIZE_TAG)
                .onClick(() => { this.http.setBaseUrl('https://www.v2ex.com'); this.useCoDomain = false })
              Button('v2ex.co').fontSize(ThemeConstants.FONT_SIZE_TAG)
                .onClick(() => { this.http.setBaseUrl('https://www.v2ex.co'); this.useCoDomain = true })
            }.margin({ top: ThemeConstants.SPACE_SM })
          }
            .padding(ThemeConstants.SPACE_LG).width('100%').alignItems(HorizontalAlign.Start).borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_MD }).height(130)

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
}
