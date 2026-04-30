import {
  HdsNavigation, HdsNavDestination, HdsTabs, HdsTabsController, HdsTabsFloatingStyle,
  hdsMaterial, HdsNavigationTitleMode, ScrollEffectType, BlurStrategy
} from '@kit.UIDesignKit'
import {
  V2exTopic, V2exNode, V2exReply, V2exMemberProfile,
  TopicCard, LoadingFooter, ThemeConstants, ApiService,
  TopicDetailParams, NodeTopicListParams, UserProfileParams, HttpClient
} from 'shared'
import { FeedViewModel } from 'feed'

@Entry
@Component
struct Index {
  @Provide('ns') ns: NavPathStack = new NavPathStack()
  private tc: HdsTabsController = new HdsTabsController()
  private tabTitles: string[] = ['首页', '发现', '通知', '我的']
  @State ct: number = 0
  @State homeVM: FeedViewModel = new FeedViewModel()
  @State discoverNodes: V2exNode[] = []
  @State discoverLoading: boolean = false
  private dApi: ApiService = new ApiService()
  // HdsNavigationTitleMode.MINI 标题栏固定高度（官方文档值，SDK 未导出常量）
  private readonly MINI_TITLE_BAR_HEIGHT: number = 56
  @StorageProp('topAvoidHeight') topAvoidHeight: number = 107
  @StorageProp('bottomAvoidHeight') bottomAvoidHeight: number = 0
  // 悬浮 TabBar 高度(HdsTabs barFloatingStyle) + barBottomMargin(20)
  private readonly TAB_BAR_HEIGHT: number = 76
  // 卡片间距
  private readonly CARD_GAP: number = 8
  @State useCoDomain: boolean = false
  private http: HttpClient = HttpClient.getInstance()

  aboutToAppear(): void {
    this.homeVM.loadData()
    this.loadDiscover()
  }

  async loadDiscover(): Promise<void> {
    this.discoverLoading = true
    try { this.discoverNodes = await this.dApi.getAllNodes() } catch (e) {}
    this.discoverLoading = false
  }

  @Builder pm(name: string, param: Object) {
    if (name === 'TopicDetail') {
      HdsNavDestination() { TopicDetailContent({ topicId: (param as Record<string, Object>)['topicId'] as number }) }
      .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'NodeTopicList') {
      HdsNavDestination() { NodeTopicContent({ nodeName: (param as Record<string, Object>)['nodeName'] as string, nodeTitle: (param as Record<string, Object>)['nodeTitle'] as string }) }
      .titleBar(this.navDestTitleBarOpts())
    } else if (name === 'UserProfile') {
      HdsNavDestination() { UserProfileContent({ username: (param as Record<string, Object>)['username'] as string }) }
      .titleBar(this.navDestTitleBarOpts())
    }
  }

  build() {
    HdsNavigation(this.ns) {
      HdsTabs({ controller: this.tc, index: this.ct }) {
        TabContent() { this.HomePage() }.tabBar(this.TabIcon('首页', 0))
        TabContent() { this.DiscoverPage() }.tabBar(this.TabIcon('发现', 1))
        TabContent() { this.NotifyPage() }.tabBar(this.TabIcon('通知', 2))
        TabContent() { this.MePage() }.tabBar(this.TabIcon('我的', 3))
      }
      .barOverlap(true).barPosition(BarPosition.End).barMode(BarMode.Fixed)
      .barFloatingStyle({ barBottomMargin: 20, systemMaterialEffect: { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE } } as HdsTabsFloatingStyle)
      .onChange((i: number) => { this.ct = i })
    }
    .titleBar(this.titleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
    .navDestination(this.pm).mode(NavigationMode.Stack).width('100%').height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  /** HdsNavDestination 的 titleBar：avoidLayoutSafeArea 使标题栏避开状态栏 */
  private navDestTitleBarOpts(): Record<string, Object> {
    return { 'avoidLayoutSafeArea': true }
  }

  private titleBarOptions(): Record<string, Object> {
    let titleInfo: Record<string, Object> = { 'mainTitle': this.tabTitles[this.ct] }
    let content: Record<string, Object> = { 'title': titleInfo }
    let mat: Record<string, Object> = { 'materialType': hdsMaterial.MaterialType.ADAPTIVE, 'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE }
    let scrollOpts: Record<string, Object> = { 'enableScrollEffect': true, 'scrollEffectType': ScrollEffectType.GRADIENT_BLUR }
    let style: Record<string, Object> = { 'systemMaterialEffect': mat, 'scrollEffectOpts': scrollOpts }
    // enableComponentSafeArea: false → titleBar 渐变模糊生效，但内容安全区需手动处理
    return { 'avoidLayoutSafeArea': true, 'enableComponentSafeArea': false, 'blurStrategy': BlurStrategy.ENABLE, 'content': content, 'style': style }
  }

  @Builder TabIcon(title: string, idx: number) {
    Column() {
      SymbolGlyph(idx===0 ? $r('sys.symbol.house_fill') : idx===1 ? $r('sys.symbol.square_fill_grid_2x2') : idx===2 ? $r('sys.symbol.bell_fill') : $r('sys.symbol.person_fill'))
        .fontSize(22).renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
        .fontColor([this.ct===idx ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_secondary')])
      Text(title).fontSize(10).fontColor(this.ct===idx ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_secondary'))
    }.alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center).width('100%').height('100%').padding({ top: 6, bottom: 4 })
  }

  @Builder HomePage() {
    Column() {
      if (this.homeVM.dataSource.totalCount() > 0) {
        Refresh({ refreshing: $$this.homeVM.isRefreshing }) {
          List({ space: this.CARD_GAP }) {
            // 顶部留白：状态栏(系统API) + MINI titleBar(官方文档常量)
            ListItem() { Column() { Blank().height(this.topAvoidHeight + this.MINI_TITLE_BAR_HEIGHT) } }
            LazyForEach(this.homeVM.dataSource, (item: V2exTopic) => {
              ListItem() { TopicCard({ item: item }) }
              .onClick(() => { let p: TopicDetailParams = { topicId: item.id }; this.ns.pushPathByName('TopicDetail', p as Object) })
            }, (item: V2exTopic) => item.id.toString())
            // 底部留白：手势条(bottomAvoidHeight) + 悬浮TabBar(TAB_BAR_HEIGHT)
            ListItem() { Column() { Blank().height(this.bottomAvoidHeight + this.TAB_BAR_HEIGHT) } }
          }.backgroundColor($r('sys.color.ohos_id_color_sub_background')).width('100%').height('100%').padding({ left: this.CARD_GAP, right: this.CARD_GAP })
        }.onRefreshing(() => this.homeVM.refresh())
      } else {
        Column() { LoadingProgress().width(32).height(32); Text(this.homeVM.errorMessage ? '加载失败' : '加载中...').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({ top: 8 }); if (this.homeVM.errorMessage) Button('重试').margin({ top: 16 }).onClick(() => this.homeVM.loadData()) }.justifyContent(FlexAlign.Center).width('100%').height('100%')
      }
    }.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder DiscoverPage() {
    Column() {
      if (this.discoverLoading) { LoadingProgress().width(32).height(32) }
      else { Scroll() { GridRow({ columns: { sm: 2, md: 4, lg: 6 }, gutter: { x: 8, y: 8 } }) { ForEach(this.discoverNodes, (node: V2exNode) => { GridCol({ span: { sm: 1, md: 2, lg: 2 } }) { Column() { Text(node.title).fontSize(14).fontColor($r('sys.color.font_primary')).maxLines(1); Text(`${node.topics} 主题`).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ top: 4 }) }.alignItems(HorizontalAlign.Center).padding(12).width('100%').borderRadius(8).backgroundColor($r('sys.color.ohos_id_color_card_bg')).onClick(() => { let p: NodeTopicListParams = { nodeName: node.name, nodeTitle: node.title }; this.ns.pushPathByName('NodeTopicList', p as Object) }) }}) }.padding({ left: this.CARD_GAP, right: this.CARD_GAP, top: this.topAvoidHeight + this.MINI_TITLE_BAR_HEIGHT, bottom: this.bottomAvoidHeight + this.TAB_BAR_HEIGHT }).width('100%') } }
    }.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder NotifyPage() {
    Column() { Text('通知').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary')); Text('登录后可查看').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({ top: 8 }) }.justifyContent(FlexAlign.Center).width('100%').height('100%').padding({ top: this.topAvoidHeight + this.MINI_TITLE_BAR_HEIGHT, bottom: this.bottomAvoidHeight + this.TAB_BAR_HEIGHT }).backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder MePage() {
    Column() { Scroll() { List() { ListItem() { Column() { Text('API 域名').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')); Text(`当前: ${this.useCoDomain ? 'v2ex.co' : 'v2ex.com'}`).fontSize(8).fontColor($r('sys.color.font_secondary')).margin({ top: 4 }); Row({ space: 8 }) { Button('v2ex.com').fontSize(11).onClick(() => { this.http.setBaseUrl('https://www.v2ex.com'); this.useCoDomain = false }); Button('v2ex.co').fontSize(11).onClick(() => { this.http.setBaseUrl('https://www.v2ex.co'); this.useCoDomain = true }) }.margin({ top: 8 }) }.padding(16).width('100%').alignItems(HorizontalAlign.Start).borderRadius(8).backgroundColor($r('sys.color.ohos_id_color_card_bg')) }.margin({ left: 8, right: 8, top: 8 }).height(130); ListItem() { Column() { Text('关于 Next2V').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary')); Text('版本 0.1.0').fontSize(11).fontColor($r('sys.color.font_secondary')).margin({ top: 4 }) }.padding(16).width('100%').alignItems(HorizontalAlign.Start).borderRadius(8).backgroundColor($r('sys.color.ohos_id_color_card_bg')) }.margin({ left: 8, right: 8, top: 8 }).height(80) }.padding({ top: this.topAvoidHeight + this.MINI_TITLE_BAR_HEIGHT, bottom: this.bottomAvoidHeight + this.TAB_BAR_HEIGHT }) } }.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}

// ========== Push 页面 ==========

@Component struct TopicDetailContent {
  @Prop topicId:number=0; @State t:V2exTopic|null=null; @State r:V2exReply[]=[]; @State l:boolean=true
  @StorageProp('topAvoidHeight') topH: number = 107
  private a:ApiService=new ApiService()
  aboutToAppear():void{this.load()}
  async load():Promise<void>{this.l=true;try{let x=await this.a.getTopicById(this.topicId);if(x.length>0)this.t=x[0];this.r=await this.a.getReplies(this.topicId)}catch(e){}finally{this.l=false}}
  build(){Column(){if(this.l){Column(){LoadingProgress().width(36).height(36);Text('加载中...').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({top:12})}.justifyContent(FlexAlign.Center).width('100%').height('100%')}else if(this.t!==null){List(){ListItem(){Column(){Blank().height(this.topH + 56)}};ListItem(){Column(){Text(this.t!.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary')).lineHeight(28).width('100%');Row({space:8}){Text(this.t!.member.username).fontSize(13).fontColor($r('sys.color.font_secondary'));Text('·').fontSize(13).fontColor($r('sys.color.font_secondary'));Text(this.t!.node.title).fontSize(13).fontColor($r('sys.color.ohos_id_color_activated'))}.width('100%').margin({top:12})}.padding(16).width('100%')};ListItem(){Text('共 '+this.r.length+' 条回复').fontSize(13).fontColor($r('sys.color.font_secondary')).padding({left:12,right:12,top:16,bottom:16}).width('100%')};ForEach(this.r,(reply:V2exReply,index:number)=>{ListItem(){Column(){Row({space:8}){Text(reply.member.username).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'));Text('#'+(index+1)).fontSize(11).fontColor($r('sys.color.font_secondary'));Blank();if(this.t!==null&&reply.member.id===this.t!.member.id){Text('楼主').fontSize(10).fontColor($r('sys.color.ohos_id_color_activated')).padding({left:6,right:6,top:1,bottom:1}).borderRadius(3).backgroundColor($r('sys.color.ohos_id_color_sub_background'))}}.width('100%');Text(reply.content).fontSize(14).fontColor($r('sys.color.font_primary')).lineHeight(22).margin({top:12}).width('100%')}.padding(16).width('100%').borderRadius(8).backgroundColor($r('sys.color.ohos_id_color_card_bg'))}.margin({left:12,right:12,bottom:6})})}.width('100%').height('100%')}else{Text('加载失败').fontSize(16).fontColor($r('sys.color.font_secondary')).margin({top:100})}}.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))}
}

@Component struct NodeTopicContent {
  @Prop nodeName:string=''; @Prop nodeTitle:string=''
  @Consume('ns') stack:NavPathStack
  @StorageProp('topAvoidHeight') topH: number = 107
  @State topics:V2exTopic[]=[]; @State loading:boolean=false
  private api:ApiService=new ApiService()
  aboutToAppear():void{this.load()}
  async load():Promise<void>{this.loading=true;try{this.topics=await this.api.getTopicsByNode(this.nodeName)}catch(e){}finally{this.loading=false}}
  build(){Column(){if(this.loading){LoadingProgress().width(32).height(32).margin({top:100})}else{List({space:ThemeConstants.SPACE_XS}){ListItem(){Column(){Blank().height(this.topH + 56)}};ForEach(this.topics,(topic:V2exTopic)=>{ListItem(){TopicCard({item:topic})}.onClick(()=>{let p:TopicDetailParams={topicId:topic.id};this.stack.pushPathByName('TopicDetail',p as Object)})})}.width('100%').height('100%')}}.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))}
}

@Component struct UserProfileContent {
  @Prop username:string=''
  @Consume('ns') stack:NavPathStack
  @StorageProp('topAvoidHeight') topH: number = 107
  @State profile:V2exMemberProfile|null=null; @State topics:V2exTopic[]=[]; @State loading:boolean=false
  private api:ApiService=new ApiService()
  aboutToAppear():void{this.load()}
  async load():Promise<void>{this.loading=true;try{this.profile=await this.api.getMember(this.username);this.topics=await this.api.getTopicsByUsername(this.username)}catch(e){}finally{this.loading=false}}
  build(){Column(){if(this.loading){LoadingProgress().width(32).height(32).margin({top:100})}else if(this.profile!==null){List({space:ThemeConstants.SPACE_XS}){ListItem(){Column(){Blank().height(this.topH + 56)}};ListItem(){Column(){Text(this.profile!.username).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'));if(this.profile!.bio)Text(this.profile!.bio).fontSize(14).fontColor($r('sys.color.font_secondary')).margin({top:12})}.padding(16).width('100%').alignItems(HorizontalAlign.Center)};ListItem(){Text('最近主题').fontSize(14).fontColor($r('sys.color.font_secondary')).padding(8)};ForEach(this.topics,(topic:V2exTopic)=>{ListItem(){TopicCard({item:topic})}.onClick(()=>{let p:TopicDetailParams={topicId:topic.id};this.stack.pushPathByName('TopicDetail',p as Object)})})}.width('100%').height('100%')}else{Text('加载失败').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({top:100})}}.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))}
}
