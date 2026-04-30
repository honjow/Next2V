import { HdsNavigation, HdsTabs, HdsTabsController, HdsTabsFloatingStyle, hdsMaterial } from '@kit.UIDesignKit'
import {
  V2exTopic, V2exNode, V2exReply, V2exMemberProfile,
  TopicCard, LoadingFooter,
  ThemeConstants, ApiService, TopicDetailParams,
  NodeTopicListParams, UserProfileParams, HttpClient
} from 'shared'
import { FeedViewModel } from 'feed'

@Entry
@Component
struct Index {
  @Provide('ns') ns: NavPathStack = new NavPathStack()
  private tc: HdsTabsController = new HdsTabsController()
  @State ct: number = 0
  @State iconEmphasize: ResourceColor = $r('sys.color.ohos_id_color_activated')
  @State iconSecondary: ResourceColor = $r('sys.color.font_secondary')

  /** Push 页面路由表：name → HdsNavDestination 包裹的内容页 */
  @Builder pm(name: string, param: Object) {
    if (name === 'TopicDetail') { NavDestination() { TopicDetailContent({ topicId: (param as Record<string, Object>)['topicId'] as number }) } }
    else if (name === 'NodeTopicList') { NavDestination() { NodeTopicContent({ nodeName: (param as Record<string, Object>)['nodeName'] as string, nodeTitle: (param as Record<string, Object>)['nodeTitle'] as string }) } }
    else if (name === 'UserProfile') { NavDestination() { UserProfileContent({ username: (param as Record<string, Object>)['username'] as string }) } }
  }

  build() {
    HdsNavigation(this.ns) {
      Column() {
        HdsTabs({ controller: this.tc, index: this.ct }) {
          TabContent() { HomePage() }.tabBar(this.TabBuilder($r('sys.symbol.house_fill'), '首页', 0))
          TabContent() { DiscoverPage() }.tabBar(this.TabBuilder($r('sys.symbol.square_fill_grid_2x2'), '发现', 1))
          TabContent() { NotifyPage() }.tabBar(this.TabBuilder($r('sys.symbol.bell_fill'), '通知', 2))
          TabContent() { MePage() }.tabBar(this.TabBuilder($r('sys.symbol.person_fill'), '我的', 3))
        }
        .barOverlap(true).barPosition(BarPosition.End)
        .barFloatingStyle({
          barBottomMargin: 20,
          systemMaterialEffect: { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }
        } as HdsTabsFloatingStyle)
        .onChange((i: number) => { this.ct = i })
      }
      .width('100%').height('100%')
      .padding({ top: 44 })   // 手动留出状态栏高度（全屏模式系统不自动内縮）
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])  // 底部延伸至手势条
    }
    .navDestination(this.pm).mode(NavigationMode.Stack).height('100%')
  }

  /** 自定义 Tab 栏：SymbolGlyph 矢量图标 + 文字，支持 active/inactive 状态 */
  @Builder TabBuilder(icon: Resource, title: string, idx: number) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(22)
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
        .fontColor([this.ct === idx ? this.iconEmphasize : this.iconSecondary])
      Text(title)
        .fontSize(10)
        .fontColor(this.ct === idx ? this.iconEmphasize : this.iconSecondary)
    }
    .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
    .width('100%').height('100%')
    .padding({ top: 6, bottom: 4 })
  }
}

// ========== Tab 内容页（无 NavDestination）==========

@Component struct HomePage {
  @Consume('ns') stack: NavPathStack
  @State vm: FeedViewModel = new FeedViewModel()
  aboutToAppear(): void { this.vm.loadData() }
  build() {
    Column() {
      if (this.vm.dataSource.totalCount()>0) {
        Refresh({refreshing:$$this.vm.isRefreshing}){List({space:ThemeConstants.SPACE_XS}){LazyForEach(this.vm.dataSource,(item:V2exTopic)=>{ListItem(){TopicCard({item:item,onUserClick:()=>{let p:UserProfileParams={username:item.member.username};this.stack.pushPathByName('UserProfile',p as Object)}})}.onClick(()=>{let p:TopicDetailParams={topicId:item.id};this.stack.pushPathByName('TopicDetail',p as Object)})},(item:V2exTopic)=>item.id.toString());ListItem(){LoadingFooter({isLoading:false,hasMore:false})}}.backgroundColor($r('sys.color.ohos_id_color_sub_background')).width('100%').height('100%')}.onRefreshing(()=>this.vm.refresh())
      }else{Column(){LoadingProgress().width(32).height(32);Text(this.vm.errorMessage?'加载失败':'加载中...').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({top:12});if(this.vm.errorMessage)Button('重试').margin({top:16}).onClick(()=>this.vm.loadData())}.justifyContent(FlexAlign.Center).width('100%').height('100%')}
    }.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}

@Component struct DiscoverPage {
  @Consume('ns') stack: NavPathStack
  @State nodes: V2exNode[]=[]; @State loading: boolean=false
  private api: ApiService=new ApiService()
  aboutToAppear():void{this.load()}
  async load():Promise<void>{this.loading=true;try{this.nodes=await this.api.getAllNodes()}catch(e){}finally{this.loading=false}}
  build(){Column(){if(this.loading){LoadingProgress().width(32).height(32)}else{Scroll(){GridRow({columns:{sm:2,md:4,lg:6},gutter:{x:8,y:8}}){ForEach(this.nodes,(node:V2exNode)=>{GridCol({span:{sm:1,md:2,lg:2}}){Column(){Text(node.title).fontSize(14).fontColor($r('sys.color.font_primary')).maxLines(1);Text(`${node.topics} 主题`).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({top:4})}.alignItems(HorizontalAlign.Center).padding(12).width('100%').borderRadius(8).backgroundColor($r('sys.color.ohos_id_color_foreground_contrary')).onClick(()=>{let p:NodeTopicListParams={nodeName:node.name,nodeTitle:node.title};this.stack.pushPathByName('NodeTopicList',p as Object)})}})}.padding(12).width('100%')}}}.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))}
}

@Component struct NotifyPage {
  build(){Column(){Text('通知').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'));Text('登录后可查看').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({top:8})}.justifyContent(FlexAlign.Center).width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))}
}

@Component struct MePage {
  @State u:boolean=false
  private h:HttpClient=HttpClient.getInstance()
  build(){Column(){List(){ListItem(){Column(){Text('API 域名').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'));Text(`当前: ${this.u?'v2ex.co':'v2ex.com'}`).fontSize(12).fontColor($r('sys.color.font_secondary')).margin({top:4});Row({space:8}){Button('v2ex.com').fontSize(11).onClick(()=>{this.h.setBaseUrl('https://www.v2ex.com');this.u=false});Button('v2ex.co').fontSize(11).onClick(()=>{this.h.setBaseUrl('https://www.v2ex.co');this.u=true})}.margin({top:8})}.padding(16).width('100%').alignItems(HorizontalAlign.Start).borderRadius(8).backgroundColor($r('sys.color.ohos_id_color_foreground_contrary'))}.margin({left:12,right:12,top:12});ListItem(){Column(){Text('关于 Next2V').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'));Text('版本 0.1.0').fontSize(11).fontColor($r('sys.color.font_secondary')).margin({top:4})}.padding(16).width('100%').alignItems(HorizontalAlign.Start).borderRadius(8).backgroundColor($r('sys.color.ohos_id_color_foreground_contrary'))}.margin({left:12,right:12,top:8})}}.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))}
}

// ========== Push 页面 ==========

@Component struct TopicDetailContent {
  @Prop topicId:number=0
  @State t:V2exTopic|null=null; @State r:V2exReply[]=[]; @State l:boolean=true
  private a:ApiService=new ApiService()
  aboutToAppear():void{this.load()}
  async load():Promise<void>{this.l=true;try{let x=await this.a.getTopicById(this.topicId);if(x.length>0)this.t=x[0];this.r=await this.a.getReplies(this.topicId)}catch(e){}finally{this.l=false}}
  build(){Column(){if(this.l){Column(){LoadingProgress().width(36).height(36);Text('加载中...').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({top:12})}.justifyContent(FlexAlign.Center).width('100%').height('100%')}else if(this.t!==null){List(){ListItem(){Column(){Text(this.t!.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary')).lineHeight(28).width('100%');Row({space:8}){Text(this.t!.member.username).fontSize(13).fontColor($r('sys.color.font_secondary'));Text('·').fontSize(13).fontColor('#ccc');Text(this.t!.node.title).fontSize(13).fontColor('#334455')}.width('100%').margin({top:12})}.padding(16).width('100%')};ListItem(){Text(`共 ${this.r.length} 条回复`).fontSize(13).fontColor($r('sys.color.font_secondary')).padding(16).width('100%')};ForEach(this.r,(reply:V2exReply,index:number)=>{ListItem(){Column(){Row({space:8}){Text(reply.member.username).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'));Text(`#${index+1}`).fontSize(11).fontColor($r('sys.color.font_secondary'));Blank();if(this.t!==null&&reply.member.id===this.t!.member.id){Text('楼主').fontSize(10).fontColor('#334455').padding({left:6,right:6,top:1,bottom:1}).borderRadius(3).backgroundColor('#E5F3FF')}}.width('100%');Text(reply.content).fontSize(14).fontColor($r('sys.color.font_primary')).lineHeight(22).margin({top:8}).width('100%')}.padding(16).width('100%').borderRadius(8).backgroundColor($r('sys.color.ohos_id_color_foreground_contrary'))}.margin({left:12,right:12,bottom:6})})}.width('100%').height('100%')}else{Text('加载失败').fontSize(16).fontColor($r('sys.color.font_secondary')).margin({top:100})}}.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))}
}

@Component struct NodeTopicContent {
  @Prop nodeName:string=''; @Prop nodeTitle:string=''
  @Consume('ns') stack:NavPathStack
  @State topics:V2exTopic[]=[]; @State loading:boolean=false
  private api:ApiService=new ApiService()
  aboutToAppear():void{this.load()}
  async load():Promise<void>{this.loading=true;try{this.topics=await this.api.getTopicsByNode(this.nodeName)}catch(e){}finally{this.loading=false}}
  build(){Column(){if(this.loading){LoadingProgress().width(32).height(32).margin({top:100})}else{List({space:ThemeConstants.SPACE_XS}){ForEach(this.topics,(topic:V2exTopic)=>{ListItem(){TopicCard({item:topic,onUserClick:()=>{let p:UserProfileParams={username:topic.member.username};this.stack.pushPathByName('UserProfile',p as Object)}})}.onClick(()=>{let p:TopicDetailParams={topicId:topic.id};this.stack.pushPathByName('TopicDetail',p as Object)})})}.width('100%').height('100%')}}.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))}
}

@Component struct UserProfileContent {
  @Prop username:string=''
  @Consume('ns') stack:NavPathStack
  @State profile:V2exMemberProfile|null=null; @State topics:V2exTopic[]=[]; @State loading:boolean=false
  private api:ApiService=new ApiService()
  aboutToAppear():void{this.load()}
  async load():Promise<void>{this.loading=true;try{this.profile=await this.api.getMember(this.username);this.topics=await this.api.getTopicsByUsername(this.username)}catch(e){}finally{this.loading=false}}
  build(){Column(){if(this.loading){LoadingProgress().width(32).height(32).margin({top:100})}else if(this.profile!==null){List({space:ThemeConstants.SPACE_XS}){ListItem(){Column(){Text(this.profile!.username).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'));if(this.profile!.bio)Text(this.profile!.bio).fontSize(14).fontColor($r('sys.color.font_secondary')).margin({top:8})}.padding(16).width('100%').alignItems(HorizontalAlign.Center)};ListItem(){Text('最近主题').fontSize(14).fontColor($r('sys.color.font_secondary')).padding(12)};ForEach(this.topics,(topic:V2exTopic)=>{ListItem(){TopicCard({item:topic,onUserClick:()=>{let p:UserProfileParams={username:topic.member.username};this.stack.pushPathByName('UserProfile',p as Object)}})}.onClick(()=>{let p:TopicDetailParams={topicId:topic.id};this.stack.pushPathByName('TopicDetail',p as Object)})})}.width('100%').height('100%')}else{Text('加载失败').fontSize(14).fontColor($r('sys.color.font_secondary')).margin({top:100})}}.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))}
}
