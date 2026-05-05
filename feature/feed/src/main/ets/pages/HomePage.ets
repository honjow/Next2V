import { FeedViewModel } from '../viewmodel/FeedViewModel'
import {
  V2exTopic, TopicCard, LoadingFooter, TopicDetailParams, ThemeConstants,
  StorageKeys, PullRefresh, ApiConstants, TabItem, ApiService, NodeTopicListParams,
  UserProfileParams, CacheSettings
} from 'shared'
import type { TopicReadState } from 'shared'
import { common } from '@kit.AbilityKit'

@Component
export struct HomePage {
  @Consume('ns') ns: NavPathStack
  @StorageLink('feedTab') feedTab: string = 'tech'
  @StorageProp('topAvoidHeight') topH: number = 107
  private readonly TAB_ITEMS: TabItem[] = ApiConstants.TAB_ITEMS
  private readonly TBH: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly BB_H: number = ApiConstants.TAB_BAR_HEIGHT
  private swiperController: SwiperController = new SwiperController()
  private horizontalPan: PanGestureOptions = new PanGestureOptions({
    direction: PanDirection.Horizontal,
    distance: 1
  })
  private isHorizontalSwiping: boolean = false

  aboutToAppear(): void {
    AppStorage.setOrCreate('listScrollEnabled', true)
  }

  private setListScrollEnabled(enabled: boolean): void {
    AppStorage.setOrCreate('listScrollEnabled', enabled)
  }

  private lockListScrollIfHorizontal(event: GestureEvent): void {
    if (Math.abs(event.offsetX) <= Math.abs(event.offsetY)) {
      return
    }
    this.isHorizontalSwiping = true
    this.setListScrollEnabled(false)
  }

  private unlockListScrollAfterHorizontalPan(): void {
    if (!this.isHorizontalSwiping) {
      return
    }
    this.isHorizontalSwiping = false
    this.setListScrollEnabled(true)
  }

  private tabKeyToIndex(key: string): number {
    let idx = this.TAB_ITEMS.findIndex(t => t.key === key)
    return idx < 0 ? 0 : idx
  }

  build() {
    Column() {
      Swiper(this.swiperController) {
        ForEach(this.TAB_ITEMS, (tab: TabItem) => {
          FeedListPage({ tabKey: tab.key })
        }, (tab: TabItem) => tab.key)
      }
      .index(this.tabKeyToIndex(this.feedTab))
      .cachedCount(1)
      .nestedScroll(SwiperNestedScrollMode.SELF_ONLY)
      .indicator(false)
      .onAnimationStart((index: number, targetIndex: number, extraInfo: SwiperAnimationEvent) => {
        this.setListScrollEnabled(false)
      })
      .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
        this.setListScrollEnabled(false)
      })
      .onAnimationEnd((index: number, extraInfo: SwiperAnimationEvent) => {
        this.setListScrollEnabled(true)
      })
      .onChange((i: number) => {
        const key = this.TAB_ITEMS[i].key
        if (key !== this.feedTab) {
          this.feedTab = key
        }
      })
      .layoutWeight(1)
    }
    .width('100%').height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    .parallelGesture(
      PanGesture(this.horizontalPan)
        .onActionStart((event: GestureEvent) => {
          this.lockListScrollIfHorizontal(event)
        })
        .onActionUpdate((event: GestureEvent) => {
          this.lockListScrollIfHorizontal(event)
        })
        .onActionEnd((event: GestureEvent) => {
          this.unlockListScrollAfterHorizontalPan()
        })
        .onActionCancel(() => {
          this.unlockListScrollAfterHorizontalPan()
        })
    )
  }
}

@Component
struct FeedListPage {
  @Consume('ns') ns: NavPathStack
  @StorageLink('listScrollEnabled') listScrollEnabled: boolean = true
  @StorageLink(StorageKeys.TOPIC_READ_STATES) topicReadStates: string = '[]'
  @Prop tabKey: string = 'tech'
  @State vm: FeedViewModel = new FeedViewModel()
  @StorageProp('topAvoidHeight') topH: number = 107
  @StorageProp('bottomAvoidHeight') bottomH: number = 0
  private readonly FLOAT_H: number = ThemeConstants.FLOAT_BAR_HEIGHT
  private readonly GAP: number = ThemeConstants.SPACE_SM
  private readonly PULL_THRESHOLD: number = 40
  private readonly TBH: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly BB_H: number = ApiConstants.TAB_BAR_HEIGHT
  private scroller: Scroller = new Scroller()
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.vm.setLoader(() => this.api.getTabTopics(this.tabKey))
    this.vm.setCacheHandlers(
      () => CacheSettings.loadTopicList(context, `tab:${this.tabKey}`),
      (topics: V2exTopic[]) => CacheSettings.saveTopicList(context, `tab:${this.tabKey}`, topics)
    )
    this.vm.loadCachedData()
    this.vm.loadData()
  }

  build() {
    Column() {
      if (this.vm.dataSource.totalCount() > 0) {
        PullRefresh({
          scroller: this.scroller,
          indicatorTop: this.TBH + this.BB_H,
          threshold: this.PULL_THRESHOLD,
          onRefresh: async () => { await this.vm.refresh() }
        }) {
          List({ space: this.GAP, scroller: this.scroller }) {
            ListItem() { Column() { Blank().height(this.topH + this.TBH + this.BB_H) } }
              .clip(false)
            LazyForEach(this.vm.dataSource, (item: V2exTopic) => {
              ListItem() {
                TopicCard({
                  item: item,
                  isUnread: this.isTopicUnread(item),
                  onUserClick: () => {
                    let p: UserProfileParams = { username: item.member.username }
                    this.ns.pushPathByName('UserProfile', p as Object)
                  },
                  onNodeClick: () => {
                    let p: NodeTopicListParams = { nodeName: item.node.name, nodeTitle: item.node.title }
                    this.ns.pushPathByName('NodeTopicList', p as Object)
                  }
                })
              }
                .onClick(() => {
                  let p: TopicDetailParams = { topicId: item.id }
                  this.ns.pushPathByName('TopicDetail', p as Object)
                })
            }, (item: V2exTopic) => item.id.toString())
            ListItem() { Column() { Blank().height(this.bottomH + this.FLOAT_H) } }
          }
          .enableScrollInteraction(this.listScrollEnabled)
          .scrollBar(BarState.Off)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          .width('100%').height('100%')
          .padding({ left: this.GAP, right: this.GAP })
          .clip(false)
          .edgeEffect(EdgeEffect.None)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
        }
      } else {
        Column() {
          LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE)
          Text(this.vm.errorMessage ? this.vm.errorMessage : '加载中...')
            .fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_secondary')).margin({ top: ThemeConstants.SPACE_SM })
          if (this.vm.errorMessage) Button('重试')
            .margin({ top: ThemeConstants.SPACE_LG })
            .onClick(() => this.vm.loadData())
        }.justifyContent(FlexAlign.Center).width('100%').height('100%')
      }
    }
    .width('100%').height('100%')
  }

  private isTopicUnread(topic: V2exTopic): boolean {
    if (topic.id <= 0) {
      return false
    }
    const lastTouched = topic.last_touched || topic.last_modified || topic.created
    const state = this.findReadState(topic.id)
    if (!state) {
      return true
    }
    return lastTouched > state.touchedAt
  }

  private findReadState(topicId: number): TopicReadState | null {
    try {
      const parsed = JSON.parse(this.topicReadStates || '[]') as TopicReadState[]
      if (!Array.isArray(parsed)) {
        return null
      }
      for (let i = 0; i < parsed.length; i++) {
        if (parsed[i].id === topicId) {
          return parsed[i]
        }
      }
      return null
    } catch (_e) {
      return null
    }
  }
}
