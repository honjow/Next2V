import {
  HdsNavigation, HdsNavDestination, HdsTabs, HdsTabsController, HdsTabsFloatingStyle,
  hdsMaterial, HdsNavigationTitleMode, ScrollEffectType, BlurStrategy
} from '@kit.UIDesignKit'
import { HttpClient } from 'shared'
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
          barBottomMargin: 20,
          systemMaterialEffect: { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }
        } as HdsTabsFloatingStyle)
        .onChange((i: number) => { this.ct = i })
    }
      .titleBar(this.titleBarOptions())
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
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
        .fontSize(22).renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
        .fontColor([this.ct === idx ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_secondary')])
      Text(title).fontSize(10).fontColor(this.ct === idx ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_secondary'))
    }
      .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center).width('100%').height('100%')
      .padding({ top: 6, bottom: 4 })
  }

  // NotifyPage 和 MePage 较为简单，保留在 Index 文件内
  @StorageProp('topAvoidHeight') topH: number = 107
  @StorageProp('bottomAvoidHeight') bottomH: number = 0
  private readonly TBH: number = 56
  private readonly FLOAT_H: number = 76

  @Builder NotifyPage() {
    Column() {
      Text('通知').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
      Text('登录后可查看').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
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
            Text('API 域名').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text(`当前: ${this.useCoDomain ? 'v2ex.co' : 'v2ex.com'}`)
              .fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ top: 4 })
            Row({ space: 8 }) {
              Button('v2ex.com').fontSize(11)
                .onClick(() => { this.http.setBaseUrl('https://www.v2ex.com'); this.useCoDomain = false })
              Button('v2ex.co').fontSize(11)
                .onClick(() => { this.http.setBaseUrl('https://www.v2ex.co'); this.useCoDomain = true })
            }.margin({ top: 8 })
          }
            .padding(16).width('100%').alignItems(HorizontalAlign.Start).borderRadius(8)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
          .margin({ left: 12, right: 12, top: 12 }).height(130)

        ListItem() {
          Column() {
            Text('关于 Next2V').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text('版本 0.1.0').fontSize(11).fontColor($r('sys.color.font_secondary')).margin({ top: 4 })
          }
            .padding(16).width('100%').alignItems(HorizontalAlign.Start).borderRadius(8)
            .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        }
          .margin({ left: 12, right: 12, top: 8 }).height(80)
      }
        .scrollBar(BarState.Off)
        .padding({ top: this.topH + this.TBH, bottom: this.bottomH + this.FLOAT_H })
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
