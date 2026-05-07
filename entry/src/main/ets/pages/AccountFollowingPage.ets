import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  Avatar,
  CookieJarSettings,
  SecondaryListScaffold,
  ThemeConstants,
  TopicCard,
  type NodeTopicListParams,
  type TopicDetailParams,
  type UserProfileParams,
  type V2exAccountMemberListItem,
  type V2exFavoriteNode,
  type V2exTopic
} from 'shared'

@Component
export struct AccountFollowingPage {
  @Consume('ns') stack: NavPathStack

  @State private members: V2exAccountMemberListItem[] = []
  @State private nodes: V2exFavoriteNode[] = []
  @State private topics: V2exTopic[] = []
  @State private errorMessage: string = ''
  @State private isLoading: boolean = false

  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.refresh()
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        if (!CookieJarSettings.getCurrentCookie()) {
          ListItem() { this.LoginRequiredView() }
        } else if (this.isLoading && this.members.length === 0 && this.nodes.length === 0 && this.topics.length === 0) {
          ListItem() { this.LoadingView() }
        } else if (this.errorMessage && this.members.length === 0 && this.nodes.length === 0 && this.topics.length === 0) {
          ListItem() { this.ErrorView() }
        } else {
          ListItem() { this.SectionHeader('关注用户') }
          if (this.members.length === 0) {
            ListItem() { this.EmptyText('暂无关注用户') }
          } else {
            ForEach(this.members, (item: V2exAccountMemberListItem) => {
              ListItem() { this.MemberRow(item) }
                .onClick(() => { this.openUser(item.username) })
            }, (item: V2exAccountMemberListItem) => `following-${item.username}`)
          }

          ListItem() { this.SectionHeader('收藏节点') }
            .margin({ top: ThemeConstants.SPACE_MD })
          if (this.nodes.length === 0) {
            ListItem() { this.EmptyText('暂无收藏节点') }
          } else {
            ForEach(this.nodes, (item: V2exFavoriteNode) => {
              ListItem() { this.NodeRow(item) }
                .onClick(() => { this.openNode(item) })
            }, (item: V2exFavoriteNode) => `following-node-${item.name}`)
          }

          ListItem() { this.SectionHeader('收藏主题') }
            .margin({ top: ThemeConstants.SPACE_MD })
          if (this.topics.length === 0) {
            ListItem() { this.EmptyText('暂无收藏主题') }
          } else {
            ForEach(this.topics, (item: V2exTopic) => {
              ListItem() { TopicCard({ item: item }) }
                .onClick(() => { this.openTopic(item.id) })
            }, (item: V2exTopic) => `following-topic-${item.id}`)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder private SectionHeader(title: string) {
    Text(title)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_XS })
  }

  @Builder private MemberRow(item: V2exAccountMemberListItem) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Avatar({ url: item.avatar, avatarSize: 42 })
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.username)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder private NodeRow(item: V2exFavoriteNode) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.title || item.name)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.name)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder private LoadingView() {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE)
        .height(ThemeConstants.LOADING_SIZE)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder private LoginRequiredView() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text('登录后可查看关注与收藏')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('去登录')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .onClick(() => { this.stack.pushPathByName('V2exNativeLogin', null) })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder private ErrorView() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.errorMessage)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .onClick(() => { this.refresh(true) })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder private EmptyText(text: string) {
    Text(text)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontColor($r('sys.color.font_secondary'))
      .textAlign(TextAlign.Center)
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  private refresh(force: boolean = false): void {
    if (this.isLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.members = []
      this.nodes = []
      this.topics = []
      this.errorMessage = ''
      return
    }
    this.isLoading = true
    this.errorMessage = ''
    Promise.all([
      this.api.getFollowingMembersWithCookie(cookie),
      this.api.getMyFavoriteNodesWithCookie(cookie),
      this.api.getMyTopicsWithCookie(cookie, 1)
    ])
      .then((result) => {
        this.members = result[0]
        this.nodes = result[1]
        this.topics = result[2]
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '加载失败'
        this.members = []
        this.nodes = []
        this.topics = []
      })
      .finally(() => {
        this.isLoading = false
        if (!force && this.errorMessage) {
          promptAction.openToast({ message: this.errorMessage }).catch((_error: Error) => { })
        }
      })
  }

  private openUser(username: string): void {
    const p: UserProfileParams = { username: username }
    this.stack.pushPathByName('UserProfile', p as Object)
  }

  private openNode(item: V2exFavoriteNode): void {
    const p: NodeTopicListParams = { nodeName: item.name, nodeTitle: item.title }
    this.stack.pushPathByName('NodeTopicList', p as Object)
  }

  private openTopic(topicId: number): void {
    const p: TopicDetailParams = { topicId: topicId }
    this.stack.pushPathByName('TopicDetail', p as Object)
  }
}
