import { DetailViewModel } from '../viewmodel/DetailViewModel'
import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { systemShare } from '@kit.ShareKit'
import {
  V2exReply, Avatar, ReplyCard, TimeAgo, PullRefresh, ThemeConstants, MarkdownContent,
  NodeTopicListParams, UserProfileParams, ImagePreviewParams, CollectionSettings, CacheSettings, V2exTopic, AuthSettings,
  LoadingFooter, HttpClient, StorageKeys, ApiService, CookieJarSettings, V2exToggleAction
} from 'shared'

interface ReplyEditorParams {
  topicId: number
  topicTitle: string
}

@Component
export struct TopicDetailPage {
  @Prop topicId: number = 0
  @State v: DetailViewModel = new DetailViewModel(0)
  @Consume('ns') stack: NavPathStack
  @StorageProp('topAvoidHeight') topH: number = 0
  @StorageLink(StorageKeys.TOPIC_DETAIL_ACTION) @Watch('onTopicActionCommand') topicActionCommand: string = ''
  @StorageLink(StorageKeys.ACCOUNT_WRITE_ENABLED) writeEnabled: boolean = false
  private scroller: Scroller = new Scroller()
  @State listScrollEnabled: boolean = true
  @State isSavedLater: boolean = false
  @State private isSiteFavorited: boolean = false
  @State private isSiteFavoriteLoading: boolean = false
  @State private jumpFloorText: string = ''
  private api: ApiService = new ApiService()
  private jumpFloorDialogController: CustomDialogController | null = new CustomDialogController({
    builder: JumpToFloorDialog({
      floorText: $jumpFloorText,
      cancel: () => { },
      confirm: (value: string) => { this.handleJumpToFloor(value) }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: false,
    cornerRadius: ThemeConstants.RADIUS_MD
  })
  private lastReadFloor: number = 0
  private hasRestoredReadPosition: boolean = false

  aboutToAppear(): void {
    this.v = new DetailViewModel(this.topicId)
    this.lastReadFloor = 0
    this.hasRestoredReadPosition = false
    this.jumpFloorText = ''
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
        this.v.load().then(() => {
          this.recordViewedTopic()
          this.markTopicReadState()
          this.restoreReadPosition()
        })
      })
    this.loadSavedState()
  }

  aboutToDisappear(): void {
    this.persistReadPosition()
  }

  private openImagePreview(url: string): void {
    const normalized = (url || '').trim()
    if (!normalized) {
      return
    }
    let p: ImagePreviewParams = { url: normalized }
    this.stack.pushPathByName('ImagePreview', p as Object)
  }

  private openReplyEditor(): void {
    const title = (this.v.topic?.title || '').trim()
    let p: ReplyEditorParams = { topicId: this.topicId, topicTitle: title }
    this.stack.pushPathByName('ReplyEditor', p as Object)
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
              floor: this.getFloorForReply(reply.id, index),
              isOp: this.v.topic !== null && reply.member.id === this.v.topic!.member.id,
              onUserClick: () => {
                let p: UserProfileParams = { username: reply.member.username }
                this.stack.pushPathByName('UserProfile', p as Object)
              },
              onImageClick: (url: string) => { this.openImagePreview(url) }
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
      .onScrollIndex((_start: number, _end: number, center: number) => {
        this.updateReadFloor(center)
      })
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
        MarkdownContent({ source: this.v.topic!.content, onImageClick: (url: string) => { this.openImagePreview(url) } })
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder ReplyDivider() {
    Column({ space: ThemeConstants.SPACE_SM }) {
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
        Blank()
      }
      .width('100%')

      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        this.ReplyActionChip('只看楼主', this.v.onlyOp, () => { this.toggleOnlyOp() })
        this.ReplyActionChip('楼层', false, () => { this.openJumpToFloorDialog() })
        this.ReplyActionChip('最新', false, () => { this.scrollToLatestReply() })
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_MD,
      bottom: ThemeConstants.SPACE_SM
    })
  }

  @Builder ReplyActionChip(label: string, active: boolean, action: () => void) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor(active ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_secondary'))
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 4, bottom: 4 })
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
      .onClick(action)
  }

  private scrollToTop(): void {
    try {
      this.scroller.scrollEdge(Edge.Top)
    } catch (_e) {
      // ignore
    }
  }

  private scrollToLatestReply(): void {
    const count = this.v.replyDataSource.totalCount()
    if (count <= 0) {
      return
    }
    const listIndex = 2 + count
    try {
      this.scroller.scrollToIndex(listIndex)
    } catch (_e) {
      // ignore
    }
  }

  private toggleOnlyOp(): void {
    this.v.setOnlyOp(!this.v.onlyOp)
  }

  private getFloorForReply(replyId: number, index: number): number {
    const floor = this.v.getReplyFloor(replyId)
    return floor > 0 ? floor : (index + 1)
  }

  private openJumpToFloorDialog(): void {
    if (this.v.topic === null) {
      return
    }
    this.jumpFloorText = ''
    this.jumpFloorDialogController?.open()
  }

  private handleJumpToFloor(value: string): void {
    const raw = (value || '').trim()
    const floor = parseInt(raw, 10)
    if (!raw || isNaN(floor) || floor <= 0) {
      promptAction.openToast({ message: '请输入有效楼层号' }).catch((_error: Error) => { })
      return
    }
    const maxFloor = this.v.topic !== null ? this.v.topic!.replies : 0
    const targetFloor = maxFloor > 0 && floor > maxFloor ? maxFloor : floor
    this.ensureRepliesLoaded(targetFloor)
      .then(() => {
        const loaded = this.v.replyDataSource.totalCount()
        if (loaded <= 0) {
          return
        }
        const safeFloor = targetFloor <= loaded ? targetFloor : loaded
        const listIndex = 2 + safeFloor
        try {
          this.scroller.scrollToIndex(listIndex)
        } catch (_e) {
          // ignore
        }
      })
      .catch((_error: Error) => {
        // ignore
      })
  }

  private updateReadFloor(centerIndex: number): void {
    const replyIndex = centerIndex - 3
    if (replyIndex < 0 || replyIndex >= this.v.replyDataSource.totalCount()) {
      return
    }
    try {
      const reply = this.v.replyDataSource.getData(replyIndex)
      const floor = this.v.getReplyFloor(reply.id)
      if (floor > 0) {
        this.lastReadFloor = floor
      }
    } catch (_e) {
      // ignore
    }
  }

  private persistReadPosition(): void {
    if (this.topicId <= 0 || this.lastReadFloor <= 0) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.saveTopicReadFloor(context, this.topicId, this.lastReadFloor)
      .catch((error: Error) => {
        console.error('save read position failed: ' + error.message)
      })
  }

  private restoreReadPosition(): void {
    if (this.hasRestoredReadPosition || this.topicId <= 0) {
      return
    }
    this.hasRestoredReadPosition = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.getTopicReadFloor(context, this.topicId)
      .then(async (floor: number) => {
        if (floor <= 0) {
          return
        }
        await this.ensureRepliesLoaded(floor)
        const loaded = this.v.replyDataSource.totalCount()
        if (loaded <= 0) {
          return
        }
        const targetFloor = floor <= loaded ? floor : loaded
        const listIndex = 2 + targetFloor
        setTimeout(() => {
          try {
            this.scroller.scrollToIndex(listIndex)
          } catch (_e) {
            // ignore
          }
        }, 0)
      })
      .catch((_error: Error) => {
        // ignore
      })
  }

  private async ensureRepliesLoaded(targetFloor: number): Promise<void> {
    if (targetFloor <= 0 || !this.v.repliesUseV2) {
      return
    }
    let guard = 0
    while (this.v.replyDataSource.totalCount() < targetFloor && this.v.repliesHasMore && guard < 20) {
      guard++
      await this.v.loadMoreRepliesV2()
    }
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

  private markTopicReadState(): void {
    if (this.v.topic === null) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.markTopicRead(context, this.v.topic.id, this.v.topic.last_touched)
      .catch((error: Error) => {
        console.error('mark topic read failed: ' + error.message)
      })
  }

  onTopicActionCommand(_propName: string): void {
    const raw = (this.topicActionCommand || '').trim()
    if (!raw) {
      return
    }
    const action = raw.split(':').pop() || ''
    this.handleTopicAction(action)
  }

  private handleTopicAction(action: string): void {
    if (action === 'reply') {
      this.openReplyEditor()
      return
    }
    if (this.v.topic === null) {
      promptAction.openToast({ message: '主题仍在加载' }).catch((_error: Error) => { })
      return
    }
    if (action === 'siteFavorite') {
      this.prepareSiteFavoriteToggle()
      return
    }
    if (action === 'saveLater') {
      this.toggleSavedLater()
    } else if (action === 'copyTitle') {
      this.copyToClipboard(this.v.topic!.title || '')
    } else if (action === 'copyLink') {
      this.copyToClipboard(this.getTopicUrl())
    } else if (action === 'share') {
      this.shareTopic()
    } else if (action === 'openBrowser') {
      this.openInSystemBrowser(this.getTopicUrl())
    } else if (action === 'copyContent') {
      this.copyToClipboard(this.v.topic!.content || '')
    }
  }

  private prepareSiteFavoriteToggle(): void {
    if (this.isSiteFavoriteLoading) {
      return
    }
    if (!this.writeEnabled) {
      promptAction.openToast({ message: '写入操作开关未开启，站内收藏不可用' }).catch((_error: Error) => { })
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      promptAction.openToast({ message: '请先登录' }).catch((_error: Error) => { })
      return
    }
    this.isSiteFavoriteLoading = true
    this.api.getTopicFavoriteToggleActionWithCookie(cookie, this.topicId)
      .then((toggle) => {
        this.isSiteFavorited = toggle.currentlyOn
        this.confirmSiteFavoriteToggle(cookie, toggle)
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '解析站内收藏失败' }).catch((_error: Error) => { })
      })
      .finally(() => {
        this.isSiteFavoriteLoading = false
      })
  }

  private confirmSiteFavoriteToggle(cookie: string, toggle: V2exToggleAction): void {
    const title = (this.v.topic?.title || '').trim()
    const verb = this.isSiteFavorited ? '取消收藏' : '收藏'
    AlertDialog.show({
      title: '站内收藏',
      message: title ? `确定${verb}《${title}》吗？` : `确定${verb}该主题吗？`,
      primaryButton: { value: '取消', action: () => { } },
      secondaryButton: {
        value: verb,
        action: () => { this.executeSiteFavoriteToggle(cookie, toggle) }
      }
    })
  }

  private executeSiteFavoriteToggle(cookie: string, toggle: V2exToggleAction): void {
    if (this.isSiteFavoriteLoading) {
      return
    }
    this.isSiteFavoriteLoading = true
    this.api.executeTopicFavoriteToggleWithCookie(cookie, this.topicId, toggle)
      .then((favorited: boolean) => {
        this.isSiteFavorited = favorited
        promptAction.openToast({ message: favorited ? '已收藏' : '已取消收藏' }).catch((_error: Error) => { })
      })
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '操作失败' }).catch((_error: Error) => { })
      })
      .finally(() => {
        this.isSiteFavoriteLoading = false
      })
  }

  private copyToClipboard(text: string): void {
    const content = (text || '').trim()
    if (!content) {
      return
    }
    let data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content)
    pasteboard.getSystemPasteboard().setDataSync(data)
    promptAction.openToast({ message: '已复制' }).catch((_error: Error) => { })
  }

  private openInSystemBrowser(url: string): void {
    const target = (url || '').trim()
    if (!target) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const want: Want = { action: 'ohos.want.action.viewData', uri: target }
    context.startAbility(want)
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '打开失败' }).catch((_error: Error) => { })
      })
  }

  private shareTopic(): void {
    if (this.v.topic === null) {
      return
    }
    const title = (this.v.topic.title || 'V2EX 主题').trim()
    const url = this.getTopicUrl()
    const data = new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      title: title,
      description: title,
      content: url
    })
    const controller = new systemShare.ShareController(data)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    controller.show(context, {
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT
    })
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '分享失败' }).catch((_error: Error) => { })
      })
  }

  private getTopicUrl(): string {
    const baseUrl = HttpClient.getInstance().getBaseUrl()
    if (this.v.topic !== null) {
      const raw = (this.v.topic!.url || '').trim()
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return raw
      }
      if (raw.startsWith('/')) {
        return `${baseUrl}${raw}`
      }
    }
    return `${baseUrl}/t/${this.topicId}`
  }
}

@CustomDialog
struct JumpToFloorDialog {
  controller?: CustomDialogController
  @Link floorText: string
  cancel: () => void = () => { }
  confirm: (value: string) => void = (_value: string) => { }

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text('跳转楼层')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      TextInput({ placeholder: '输入楼层号', text: this.floorText })
        .type(InputType.Number)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(ThemeConstants.RADIUS_MD)
        .onChange((value: string) => { this.floorText = value })
      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            if (this.controller != undefined) {
              this.controller.close()
            }
            this.cancel()
          })
        Button('跳转')
          .layoutWeight(1)
          .height(40)
          .onClick(() => {
            const value = this.floorText
            if (this.controller != undefined) {
              this.controller.close()
            }
            this.confirm(value)
          })
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .width('100%')
  }
}
