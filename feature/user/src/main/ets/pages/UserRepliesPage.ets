import { UserRepliesViewModel } from '../viewmodel/UserViewModel'
import {
  DateUtils, MarkdownContent, NodeTopicListParams, SecondaryListScaffold, ThemeConstants, TopicDetailParams,
  UserProfileParams, V2exRoute, V2exUrlRouter, V2exUserReply
} from 'shared'
import { common, Want } from '@kit.AbilityKit'

@Component
export struct UserRepliesPage {
  @Prop username: string = ''
  @Consume('ns') stack: NavPathStack
  @State vm: UserRepliesViewModel = new UserRepliesViewModel(this.username)

  aboutToAppear(): void { this.vm.load() }

  build() {
    Column() {
      SecondaryListScaffold({
        onReachEnd: () => {
          this.vm.loadMore()
        }
      }) {
        if (this.vm.isLoading && this.vm.replyDataSource.totalCount() === 0) {
          ListItem() { this.LoadingView() }
        } else if (this.vm.errorMessage && this.vm.replyDataSource.totalCount() === 0) {
          ListItem() { this.ErrorView() }
        } else if (this.vm.replyDataSource.totalCount() === 0) {
          ListItem() { this.EmptyText('暂无回复') }
        } else {
          LazyForEach(this.vm.replyDataSource, (reply: V2exUserReply) => {
            ListItem() {
              this.ReplyItem(reply)
            }
            .onClick(() => {
              let p: TopicDetailParams = { topicId: reply.topic_id, targetFloor: reply.target_floor }
              this.stack.pushPathByName('TopicDetail', p as Object)
            })
          }, (reply: V2exUserReply) => `${reply.topic_id}-${reply.target_floor}-${reply.created}`)

          if (this.vm.isLoadingMore) {
            ListItem() { this.LoadingView(80) }
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder ReplyItem(reply: V2exUserReply) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_XS }) {
        Text(reply.topic_author || this.username)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        Text('›')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        Text(reply.node_title || reply.node_name)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        if (reply.created > 0) {
          Text(DateUtils.toDateString(reply.created))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .width('100%')

      Text(reply.topic_title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (reply.content) {
        MarkdownContent({
          source: reply.content,
          topMargin: 0,
          onLinkClick: (url: string) => { this.openContentLink(url) },
          onMentionClick: (username: string) => { this.openUserProfile(username) }
        })
      }
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder LoadingView(height: number = 240) {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE)
        .height(ThemeConstants.LOADING_SIZE)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(height)
  }

  @Builder EmptyText(text: string) {
    Text(text)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding(ThemeConstants.SPACE_LG)
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder ErrorView() {
    Column() {
      Text(this.vm.errorMessage || '加载失败')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .type(ButtonType.Capsule)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.vm.load() })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  private openUserProfile(username: string): void {
    const clean = (username || '').trim()
    if (!clean) {
      return
    }
    let p: UserProfileParams = { username: clean }
    this.stack.pushPathByName('UserProfile', p as Object)
  }

  private openContentLink(url: string): void {
    const clean = (url || '').trim()
    const route = V2exUrlRouter.parse(clean)
    if (route) {
      this.openV2exRoute(route)
      return
    }
    this.openInSystemBrowser(clean)
  }

  private openV2exRoute(route: V2exRoute): void {
    if (route.kind === 'topic' && route.topicId && route.topicId > 0) {
      const p: TopicDetailParams = route.targetFloor && route.targetFloor > 0
        ? { topicId: route.topicId, targetFloor: route.targetFloor }
        : { topicId: route.topicId }
      this.stack.pushPathByName('TopicDetail', p as Object)
      return
    }
    if (route.kind === 'member' && route.username) {
      this.openUserProfile(route.username)
      return
    }
    if (route.kind === 'node' && route.nodeName) {
      const p: NodeTopicListParams = { nodeName: route.nodeName, nodeTitle: route.nodeName }
      this.stack.pushPathByName('NodeTopicList', p as Object)
    }
  }

  private openInSystemBrowser(url: string): void {
    const target = (url || '').trim()
    if (!target) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const want: Want = { action: 'ohos.want.action.viewData', uri: target }
    context.startAbility(want).catch((_error: Error) => { })
  }
}
