import { DetailViewModel } from '../viewmodel/DetailViewModel'
import { common } from '@kit.AbilityKit'
import {
  V2exReply, Avatar, ReplyCard, TimeAgo, PullRefresh, ThemeConstants, MarkdownContent,
  NodeTopicListParams, UserProfileParams, CollectionSettings, CacheSettings, V2exTopic, AuthSettings, LoadingFooter
} from 'shared'

@Component
export struct TopicDetailPage {
  @Prop topicId: number = 0
  @State v: DetailViewModel = new DetailViewModel(0)
  @Consume('ns') stack: NavPathStack
  @StorageProp('topAvoidHeight') topH: number = 0
  private scroller: Scroller = new Scroller()
  @State listScrollEnabled: boolean = true
  @State isSavedLater: boolean = false

  aboutToAppear(): void {
    this.v = new DetailViewModel(this.topicId)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.v.setCacheHandlers(
      () => CacheSettings.loadTopicDetail(context, this.topicId),
      (topic: V2exTopic | null, replies: V2exReply[]) => CacheSettings.saveTopicDetail(context, this.topicId, topic, replies)
    )
    this.v.loadCachedData()
    AuthSettings.load(context)
      .then((snapshot) => {
        this.v.setToken(snapshot.token || '')
      })
      .catch((_error: Error) => {
        this.v.setToken('')
      })
      .finally(() => {
        this.v.load().then(() => { this.recordViewedTopic() })
      })
    this.loadSavedState()
  }

  build() {
    Column() {
      if (this.v.isLoading && this.v.topic === null) {
        this.LoadingView()
      } else if (this.v.errorMessage && this.v.topic === null) {
        this.ErrorView()
      } else if (this.v.topic !== null) {
        this.ContentView()
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder LoadingView() {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE_LARGE)
        .height(ThemeConstants.LOADING_SIZE_LARGE)
        .color($r('sys.color.ohos_id_color_activated'))
      Text('加载中...')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: ThemeConstants.SPACE_MD })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%').height('100%')
  }

  @Builder ErrorView() {
    Column() {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
        .fontSize(48)
        .fontColor([$r('sys.color.font_secondary')])
      Text(this.v.errorMessage || '加载失败')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: ThemeConstants.SPACE_MD })
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.v.load() })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%').height('100%')
  }

  @Builder ContentView() {
    PullRefresh({
      scroller: this.scroller,
      indicatorTop: this.topH + ThemeConstants.TITLE_BAR_HEIGHT / 2,
      threshold: 40,
      onRefresh: async () => { await this.v.load() },
      onScrollEnableChange: (enabled: boolean) => { this.listScrollEnabled = enabled }
    }) {
      List({ space: ThemeConstants.SPACE_SM - 2, scroller: this.scroller }) {
        // 顶部安全区占位
        ListItem() { Column() { Blank().height(this.topH + ThemeConstants.TITLE_BAR_HEIGHT) } }
          .clip(false)

        // 主楼卡片
        ListItem() {
          this.TopicCard()
        }

        // 回复分隔
        ListItem() {
          this.ReplyDivider()
        }

        // 回复列表
        LazyForEach(this.v.replyDataSource, (reply: V2exReply, index: number) => {
          ListItem() {
            ReplyCard({
              reply: reply,
              floor: index + 1,
              isOp: this.v.topic !== null && reply.member.id === this.v.topic!.member.id,
              onUserClick: () => {
                let p: UserProfileParams = { username: reply.member.username }
                this.stack.pushPathByName('UserProfile', p as Object)
              }
            })
          }
        }, (reply: V2exReply) => reply.id.toString())

        if (this.v.repliesUseV2) {
          ListItem() {
            LoadingFooter({ isLoading: this.v.isRepliesLoadingMore, hasMore: this.v.repliesHasMore })
          }
        }

        // 底部留白
        ListItem() { Column() { Blank().height(ThemeConstants.SPACE_XL) } }
      }
      .enableScrollInteraction(this.listScrollEnabled)
      .onReachEnd(() => {
        if (this.v.repliesUseV2) {
          this.v.loadMoreRepliesV2()
        }
      })
      .scrollBar(BarState.Off)
      .width('100%').height('100%')
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
      .clip(false)
      .edgeEffect(EdgeEffect.None)
    }
  }

  @Builder TopicCard() {
    Column() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Avatar({ url: this.v.topic!.member.avatar_normal, avatarSize: ThemeConstants.AVATAR_SIZE_REPLY })
          .onClick(() => {
            let p: UserProfileParams = { username: this.v.topic!.member.username }
            this.stack.pushPathByName('UserProfile', p as Object)
          })

        Text(this.v.topic!.member.username)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            let p: UserProfileParams = { username: this.v.topic!.member.username }
            this.stack.pushPathByName('UserProfile', p as Object)
          })

        Text('·')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor($r('sys.color.font_secondary'))

        TimeAgo({ timestamp: this.v.topic!.created })

        Blank()

        Text(this.v.topic!.node.title)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.ohos_id_color_activated'))
          .padding({
            left: ThemeConstants.SPACE_SM,
            right: ThemeConstants.SPACE_SM,
            top: 2,
            bottom: 2
          })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onClick(() => {
            let p: NodeTopicListParams = {
              nodeName: this.v.topic!.node.name,
              nodeTitle: this.v.topic!.node.title
            }
            this.stack.pushPathByName('NodeTopicList', p as Object)
          })

        Text(this.isSavedLater ? '已存' : '稍后读')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor(this.isSavedLater ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_secondary'))
          .padding({
            left: ThemeConstants.SPACE_SM,
            right: ThemeConstants.SPACE_SM,
            top: 2,
            bottom: 2
          })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onClick(() => { this.toggleSavedLater() })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.v.topic!.title)
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(28)
        .width('100%')
        .margin({ top: ThemeConstants.SPACE_MD })

      // 正文
      if (this.v.topic!.content) {
        MarkdownContent({ source: this.v.topic!.content })
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder ReplyDivider() {
    Row() {
      if (this.v.repliesUseV2 && this.v.topic !== null && this.v.topic!.replies > 0) {
        Text(`已加载 ${this.v.repliesLoaded} / ${this.v.topic!.replies} 条回复`)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor($r('sys.color.font_secondary'))
      } else {
        Text(`共 ${this.v.replyDataSource.totalCount()} 条回复`)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_MD,
      bottom: ThemeConstants.SPACE_SM
    })
  }

  private loadSavedState(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.isTopicSaved(context, this.topicId)
      .then((saved: boolean) => {
        this.isSavedLater = saved
      })
      .catch((error: Error) => {
        console.error('load saved topic state failed: ' + error.message)
      })
  }

  private toggleSavedLater(): void {
    if (this.v.topic === null) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const request = this.isSavedLater
      ? CollectionSettings.removeTopic(context, this.v.topic.id)
      : CollectionSettings.saveTopic(context, this.v.topic)
    request
      .then(() => {
        this.isSavedLater = !this.isSavedLater
      })
      .catch((error: Error) => {
        console.error('toggle saved topic failed: ' + error.message)
      })
  }

  private recordViewedTopic(): void {
    if (this.v.topic === null) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.recordViewedTopic(context, this.v.topic)
      .catch((error: Error) => {
        console.error('record viewed topic failed: ' + error.message)
      })
  }
}
