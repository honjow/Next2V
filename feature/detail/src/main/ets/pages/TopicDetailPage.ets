import { DetailViewModel } from '../viewmodel/DetailViewModel'
import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { systemShare } from '@kit.ShareKit'
import {
  V2exReply, Avatar, ReplyCard, TimeAgo, ThemeConstants, MarkdownContent, PullRefreshListScaffold,
  NodeTopicListParams, UserProfileParams, ImagePreviewParams, CollectionSettings, CacheSettings, V2exTopic, AuthSettings,
  LoadingFooter, HttpClient, StorageKeys, ApiService, CookieJarSettings, V2exToggleAction, ReadingSettings
} from 'shared'

interface ReplyEditorParams {
  topicId: number
  topicTitle: string
  initialContent?: string
}

interface ReplyContextItem {
  reply: V2exReply
  floor: number
  label: string
  selected: boolean
}

@Component
export struct TopicDetailPage {
  @Prop topicId: number = 0
  @Prop targetFloor: number = 0
  @State v: DetailViewModel = new DetailViewModel(0)
  @Consume('ns') stack: NavPathStack
  @StorageLink(StorageKeys.TOPIC_DETAIL_ACTION) @Watch('onTopicActionCommand') topicActionCommand: string = ''
  @StorageLink(StorageKeys.ACCOUNT_WRITE_ENABLED) writeEnabled: boolean = false
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ThemeConstants.FONT_SIZE_BODY
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string = ReadingSettings.DENSITY_STANDARD
  private scroller: Scroller = new Scroller()
  @State listScrollEnabled: boolean = true
  @State isSavedLater: boolean = false
  @State private isSiteFavorited: boolean = false
  @State private isSiteFavoriteLoading: boolean = false
  @State private jumpFloorText: string = ''
  @State private contextReply: V2exReply | null = null
  @State private selectionTitle: string = ''
  @State private selectionText: string = ''
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
  private hasJumpedToTargetFloor: boolean = false

  aboutToAppear(): void {
    this.v = new DetailViewModel(this.topicId)
    this.lastReadFloor = 0
    this.hasRestoredReadPosition = false
    this.hasJumpedToTargetFloor = false
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
          this.restoreInitialPosition()
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

  private openReplyEditor(initialContent: string = ''): void {
    const title = (this.v.topic?.title || '').trim()
    let p: ReplyEditorParams = { topicId: this.topicId, topicTitle: title, initialContent: initialContent }
    this.stack.pushPathByName('ReplyEditor', p as Object)
  }

  private bodyFontSize(): number {
    return ReadingSettings.normalizeFontSize(this.readingFontSize)
  }

  private bodyLineHeight(): number {
    return ReadingSettings.normalizeLineHeight(this.readingLineHeight, this.bodyFontSize())
  }

  private topicCardPadding(): number {
    if (this.readingDensity === ReadingSettings.DENSITY_COMPACT) {
      return ThemeConstants.SPACE_MD
    }
    if (this.readingDensity === ReadingSettings.DENSITY_COMFORTABLE) {
      return ThemeConstants.SPACE_XL
    }
    return ThemeConstants.SPACE_LG
  }

  build() {
    Stack() {
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

      if (this.contextReply !== null) {
        this.ReplyContextOverlay()
      }

      if (this.selectionText) {
        this.TextSelectionOverlay()
      }
    }
    .width('100%')
    .height('100%')
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
    PullRefreshListScaffold({
      scroller: this.scroller,
      scrollEnabled: this.listScrollEnabled,
      onRefresh: async () => { await this.v.load() },
      onScrollEnableChange: (enabled: boolean) => { this.listScrollEnabled = enabled },
      onScrollIndex: (_start: number, _end: number, center: number) => { this.updateReadFloor(center) },
      onReachEnd: () => { this.loadMoreReplies() }
    }) {
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
              onContextClick: () => { this.openReplyContext(reply) },
              onMentionClick: () => { this.openReplyEditor(this.getMentionText(reply.member.username)) },
              onCopyUserClick: () => { this.copyToClipboard(reply.member.username || '') },
              onSelectContentClick: () => { this.openTextSelection(this.replySelectionTitle(reply), reply.content || '') },
              onCopyContentClick: () => { this.copyToClipboard(reply.content || '') },
              onImageClick: (url: string) => { this.openImagePreview(url) },
              onLinkClick: (url: string) => { this.openInSystemBrowser(url) },
              onContentLongPress: () => { this.openTextSelection(this.replySelectionTitle(reply), reply.content || '') }
            })
          }
        }, (reply: V2exReply) => reply.id.toString())

        if (this.v.repliesUseV2) {
          ListItem() {
            LoadingFooter({ isLoading: this.v.isRepliesLoadingMore, hasMore: this.v.repliesHasMore })
          }
        }
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
        Column() {
          MarkdownContent({
            source: this.v.topic!.content,
            onImageClick: (url: string) => { this.openImagePreview(url) },
            onLinkClick: (url: string) => { this.openInSystemBrowser(url) }
          })
        }
        .width('100%')
        .gesture(
          LongPressGesture({ duration: 650 })
            .onAction(() => {
              this.openTextSelection('主题正文', this.v.topic!.content || '')
            })
        )
      }
    }
    .padding(this.topicCardPadding())
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder ReplyDivider() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Text(this.replyCountText())
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Row({ space: ThemeConstants.SPACE_XS }) {
        this.ReplyToolButton('楼层', false, () => { this.openJumpToFloorDialog() })
        this.ReplyToolButton('只看楼主', this.v.onlyOp, () => { this.toggleOnlyOp() })
        this.ReplyToolButton('最新', false, () => { this.scrollToLatestReply() })
      }
      .alignItems(VerticalAlign.Center)
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_SM,
      right: ThemeConstants.SPACE_SM,
      top: ThemeConstants.SPACE_SM,
      bottom: ThemeConstants.SPACE_XS
    })
  }

  @Builder ReplyToolButton(label: string, active: boolean, action: () => void) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_TINY)
      .fontColor(active ? Color.White : $r('sys.color.font_secondary'))
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 5, bottom: 5 })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(active ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_button_normal'))
      .onClick(action)
  }

  @Builder ReplyContextOverlay() {
    Column() {
      Blank()
        .width('100%')
        .layoutWeight(1)
        .onClick(() => { this.closeReplyContext() })

      Column({ space: ThemeConstants.SPACE_MD }) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(this.replyContextTitle())
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Blank()

          Button('关闭')
            .type(ButtonType.Normal)
            .height(32)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor($r('sys.color.font_secondary'))
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .borderRadius(ThemeConstants.RADIUS_SM)
            .onClick(() => { this.closeReplyContext() })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Column({ space: ThemeConstants.SPACE_SM }) {
            ForEach(this.buildReplyContextItems(), (item: ReplyContextItem) => {
              this.ReplyContextItemView(item)
            }, (item: ReplyContextItem) => `${item.reply.id}-${item.floor}-${item.label}`)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('72%')
      .padding({
        left: ThemeConstants.SPACE_LG,
        right: ThemeConstants.SPACE_LG,
        top: ThemeConstants.SPACE_LG,
        bottom: ThemeConstants.SPACE_LG
      })
      .borderRadius({ topLeft: ThemeConstants.RADIUS_MD, topRight: ThemeConstants.RADIUS_MD })
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }

  @Builder TextSelectionOverlay() {
    Column() {
      Blank()
        .width('100%')
        .layoutWeight(1)
        .onClick(() => { this.closeTextSelection() })

      Column({ space: ThemeConstants.SPACE_MD }) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(this.selectionTitle || '选择文本')
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Blank()

          Button('复制全部')
            .type(ButtonType.Normal)
            .height(32)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor($r('sys.color.font_primary'))
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .borderRadius(ThemeConstants.RADIUS_SM)
            .onClick(() => { this.copyToClipboard(this.selectionText) })

          Button('关闭')
            .type(ButtonType.Normal)
            .height(32)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor($r('sys.color.font_secondary'))
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .borderRadius(ThemeConstants.RADIUS_SM)
            .onClick(() => { this.closeTextSelection() })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Scroll() {
        Text(this.selectionText)
            .fontSize(this.bodyFontSize())
            .lineHeight(this.bodyLineHeight())
            .fontColor($r('sys.color.font_primary'))
            .width('100%')
            .copyOption(CopyOptions.LocalDevice)
            .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
            .draggable(false)
            .padding(ThemeConstants.SPACE_MD)
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
      .width('100%')
      .height('72%')
      .padding({
        left: ThemeConstants.SPACE_LG,
        right: ThemeConstants.SPACE_LG,
        top: ThemeConstants.SPACE_LG,
        bottom: ThemeConstants.SPACE_LG
      })
      .borderRadius({ topLeft: ThemeConstants.RADIUS_MD, topRight: ThemeConstants.RADIUS_MD })
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }

  @Builder ReplyContextItemView(item: ReplyContextItem) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(item.label)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor(item.selected ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.font_secondary'))
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 2, bottom: 2 })
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))

        Text(`#${item.floor}`)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))

        Text(item.reply.member.username)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Blank()

        TimeAgo({ timestamp: item.reply.created })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.replySnippet(item.reply.content))
        .fontSize(this.bodyFontSize())
        .lineHeight(this.bodyLineHeight())
        .fontColor($r('sys.color.font_primary'))
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor(item.selected ? $r('sys.color.ohos_id_color_button_normal') : $r('sys.color.ohos_id_color_sub_background'))
    .onClick(() => {
      this.jumpToLoadedReplyFloor(item.floor)
      this.closeReplyContext()
    })
  }

  private openReplyContext(reply: V2exReply): void {
    this.contextReply = reply
  }

  private closeReplyContext(): void {
    this.contextReply = null
  }

  private openTextSelection(title: string, content: string): void {
    const text = (content || '').trim()
    if (!text) {
      promptAction.openToast({ message: '暂无可选择内容' }).catch((_error: Error) => { })
      return
    }
    this.selectionTitle = title || '选择文本'
    this.selectionText = text
  }

  private closeTextSelection(): void {
    this.selectionTitle = ''
    this.selectionText = ''
  }

  private replySelectionTitle(reply: V2exReply): string {
    const username = (reply.member.username || '').trim()
    const floor = this.v.getReplyFloor(reply.id)
    if (floor > 0 && username) {
      return `#${floor} ${username}`
    }
    if (floor > 0) {
      return `#${floor} 回复`
    }
    return username || '回复内容'
  }

  private replyContextTitle(): string {
    if (this.contextReply === null) {
      return '回复上下文'
    }
    const floor = this.v.getReplyFloor(this.contextReply.id)
    return floor > 0 ? `#${floor} 回复上下文` : '回复上下文'
  }

  private buildReplyContextItems(): ReplyContextItem[] {
    if (this.contextReply === null) {
      return []
    }
    const selected = this.contextReply
    const selectedFloor = this.v.getReplyFloor(selected.id)
    const replies = this.v.getLoadedRepliesSnapshot()
    const items: ReplyContextItem[] = []
    const seen = new Set<number>()

    const addReply = (reply: V2exReply | null, label: string, selectedItem: boolean): void => {
      if (reply === null || reply.id <= 0 || seen.has(reply.id)) {
        return
      }
      const floor = this.v.getReplyFloor(reply.id)
      if (floor <= 0) {
        return
      }
      seen.add(reply.id)
      items.push({ reply: reply, floor: floor, label: label, selected: selectedItem })
    }

    this.addContextReplyByFloor(replies, selectedFloor - 2, '上文', addReply)
    this.addContextReplyByFloor(replies, selectedFloor - 1, '上文', addReply)
    this.addMentionTargetsBeforeSelection(replies, selectedFloor, selected.content, addReply)
    addReply(selected, '当前回复', true)
    this.addRepliesMentioningSelectedAuthor(replies, selectedFloor, selected.member.username, addReply)
    this.addContextReplyByFloor(replies, selectedFloor + 1, '下文', addReply)
    this.addContextReplyByFloor(replies, selectedFloor + 2, '下文', addReply)

    return items.sort((left: ReplyContextItem, right: ReplyContextItem) => left.floor - right.floor)
  }

  private addContextReplyByFloor(
    replies: V2exReply[],
    floor: number,
    label: string,
    addReply: (reply: V2exReply | null, label: string, selectedItem: boolean) => void
  ): void {
    if (floor <= 0 || floor > replies.length) {
      return
    }
    addReply(replies[floor - 1], label, false)
  }

  private addMentionTargetsBeforeSelection(
    replies: V2exReply[],
    selectedFloor: number,
    content: string,
    addReply: (reply: V2exReply | null, label: string, selectedItem: boolean) => void
  ): void {
    const names = this.extractMentionedUsernames(content)
    names.forEach((name: string) => {
      const target = this.findPreviousReplyByUsername(replies, selectedFloor, name)
      addReply(target, `@${name}`, false)
    })
  }

  private addRepliesMentioningSelectedAuthor(
    replies: V2exReply[],
    selectedFloor: number,
    username: string,
    addReply: (reply: V2exReply | null, label: string, selectedItem: boolean) => void
  ): void {
    const clean = (username || '').trim()
    if (!clean) {
      return
    }
    let added = 0
    for (let i = selectedFloor; i < replies.length && added < 2; i++) {
      const reply = replies[i]
      if (reply && this.contentMentionsUsername(reply.content, clean)) {
        addReply(reply, `提到 @${clean}`, false)
        added++
      }
    }
  }

  private findPreviousReplyByUsername(replies: V2exReply[], selectedFloor: number, username: string): V2exReply | null {
    const clean = (username || '').trim().toLowerCase()
    if (!clean) {
      return null
    }
    for (let i = selectedFloor - 2; i >= 0; i--) {
      const reply = replies[i]
      if (reply && (reply.member.username || '').trim().toLowerCase() === clean) {
        return reply
      }
    }
    return null
  }

  private contentMentionsUsername(content: string, username: string): boolean {
    const clean = (username || '').trim().toLowerCase()
    if (!clean) {
      return false
    }
    return this.extractMentionedUsernames(content).some((name: string) => name.toLowerCase() === clean)
  }

  private extractMentionedUsernames(content: string): string[] {
    const names: string[] = []
    const seen = new Set<string>()
    const parts = (content || '').split('@')
    for (let i = 1; i < parts.length; i++) {
      const name = this.readMentionName(parts[i] || '')
      const key = name.toLowerCase()
      if (name && !seen.has(key)) {
        seen.add(key)
        names.push(name)
      }
    }
    return names
  }

  private readMentionName(raw: string): string {
    let name = ''
    for (let i = 0; i < raw.length; i++) {
      const ch = raw.charAt(i)
      if (this.isMentionNameChar(ch)) {
        name += ch
      } else {
        break
      }
    }
    return name
  }

  private isMentionNameChar(ch: string): boolean {
    return (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch === '_'
  }

  private replySnippet(content: string): string {
    const text = (content || '')
      .replace(/\r/g, '\n')
      .replace(/\n+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
    return text || '（无内容）'
  }

  private jumpToLoadedReplyFloor(floor: number): void {
    if (floor <= 0) {
      return
    }
    if (this.v.onlyOp) {
      this.v.setOnlyOp(false)
    }
    setTimeout(() => {
      try {
        this.scroller.scrollToIndex(2 + floor)
      } catch (_e) {
        // ignore
      }
    }, 0)
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

  private loadMoreReplies(): void {
    if (this.v.repliesUseV2) {
      this.v.loadMoreRepliesV2()
    }
  }

  private replyCountText(): string {
    if (this.v.repliesUseV2 && this.v.topic !== null && this.v.topic!.replies > 0) {
      return `已加载 ${this.v.repliesLoaded} / ${this.v.topic!.replies}`
    }
    return `共 ${this.v.replyDataSource.totalCount()} 条回复`
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

  private restoreInitialPosition(): void {
    const target = Math.floor(this.targetFloor)
    if (target > 0) {
      this.jumpToTargetFloor(target)
      return
    }
    this.restoreReadPosition()
  }

  private jumpToTargetFloor(floor: number): void {
    if (this.hasJumpedToTargetFloor || floor <= 0) {
      return
    }
    this.hasJumpedToTargetFloor = true
    this.ensureRepliesLoaded(floor)
      .then(() => {
        const loaded = this.v.replyDataSource.totalCount()
        if (loaded <= 0) {
          return
        }
        const safeFloor = floor <= loaded ? floor : loaded
        this.jumpToLoadedReplyFloor(safeFloor)
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
    } else if (action === 'selectContent') {
      this.openTextSelection('主题正文', this.v.topic!.content || '')
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
    try {
      let data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content)
      pasteboard.getSystemPasteboard().setDataSync(data)
      promptAction.openToast({ message: '已复制' }).catch((_error: Error) => { })
    } catch (error) {
      promptAction.openToast({ message: (error as Error).message || '复制失败' }).catch((_error: Error) => { })
    }
  }

  private getMentionText(username: string): string {
    const clean = (username || '').trim()
    return clean ? `@${clean} ` : ''
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
