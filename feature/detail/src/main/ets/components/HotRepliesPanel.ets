import {
  AppStrings,
  MarkdownContent,
  ReplyCard,
  ThemeConstants,
  UserName,
  V2exReply,
} from 'shared'

const HOT_REPLY_THREAD_GUIDE_LINE_WIDTH: number = 0.5
const HOT_REPLY_THREAD_GUIDE_CONTENT_GAP: number = 6
const HOT_REPLY_THREAD_GUIDE_END_INSET: number = 8

@ComponentV2
export struct HotRepliesPanel {
  @Param replies: V2exReply[] = [];
  @Param opMemberId: number = 0;
  @Param expanded: boolean = true;
  @Local private childGuideHeights: Record<string, number> = {};
  @Event onExpandedChange?: (expanded: boolean) => void;
  @Event onJumpClick?: (reply: V2exReply) => void;
  @Event onContextClick?: (reply: V2exReply) => void;
  @Event onReplyClick?: (reply: V2exReply) => void;
  @Event onThankClick?: (reply: V2exReply) => void;
  @Event onIgnoreClick?: (reply: V2exReply) => void;
  @Event onReportClick?: (reply: V2exReply) => void;
  @Event onCopyUserClick?: (reply: V2exReply) => void;
  @Event onCopyContentClick?: (reply: V2exReply) => void;
  @Event isReplyThanked?: (reply: V2exReply) => boolean;
  @Event isReplyThankPending?: (reply: V2exReply) => boolean;
  @Event onUserClick?: (username: string) => void;
  @Event onImageClick?: (url: string) => void;
  @Event onLinkClick?: (url: string) => void;

  private headerText(): string {
    return AppStrings.format(
      AppStrings.text($r('app.string.hot_replies_header_format'), 'Top replies · {0}'),
      [`${this.replies.length}`],
    )
  }

  private contentSource(reply: V2exReply): string {
    const rendered = (reply.content_rendered || '').trim()
    if (rendered.length > 0) {
      return reply.content_rendered
    }
    return reply.content || ''
  }

  private childContentSource(reply: V2exReply): string {
    const hiddenRendered = (reply.hiddenLeadingMentionRenderedContent || '').trim()
    if (hiddenRendered.length > 0) {
      return reply.hiddenLeadingMentionRenderedContent || ''
    }
    const hidden = (reply.hiddenLeadingMentionContent || '').trim()
    if (hidden.length > 0) {
      return reply.hiddenLeadingMentionContent || ''
    }
    return this.contentSource(reply)
  }

  private replyKey(reply: V2exReply): string {
    return reply.renderKey || reply.id.toString()
  }

  private childMeasuredHeight(reply: V2exReply): number {
    return this.childGuideHeights[this.replyKey(reply)] || 0
  }

  private childGuideHeight(reply: V2exReply, isLast: boolean): number {
    const height = this.childMeasuredHeight(reply)
    if (height <= 0) {
      return 0
    }
    if (isLast) {
      return Math.max(0, height - HOT_REPLY_THREAD_GUIDE_END_INSET)
    }
    return height
  }

  private updateChildGuideHeight(reply: V2exReply, area: Area): void {
    const height = typeof area.height === 'number'
      ? area.height
      : Number.parseFloat(area.height as string)
    if (Number.isNaN(height) || Math.abs(height - this.childMeasuredHeight(reply)) < 0.5) {
      return
    }
    const next: Record<string, number> = {}
    const existingKeys: string[] = Object.keys(this.childGuideHeights)
    for (const existingKey of existingKeys) {
      next[existingKey] = this.childGuideHeights[existingKey]
    }
    next[this.replyKey(reply)] = height
    this.childGuideHeights = next
  }

  private toggleExpanded(): void {
    const next = !this.expanded
    if (this.onExpandedChange) {
      this.onExpandedChange(next)
    }
  }

  private jumpToReply(reply: V2exReply): void {
    if (this.onJumpClick) {
      this.onJumpClick(reply)
    }
  }

  private isOp(reply: V2exReply): boolean {
    return this.opMemberId > 0 && reply.member.id === this.opMemberId
  }

  private replyThanked(reply: V2exReply): boolean {
    if (this.isReplyThanked) {
      return this.isReplyThanked(reply)
    }
    return false
  }

  private replyThankPending(reply: V2exReply): boolean {
    if (this.isReplyThankPending) {
      return this.isReplyThankPending(reply)
    }
    return false
  }

  private runReplyAction(reply: V2exReply, action?: (reply: V2exReply) => void): void {
    if (action) {
      action(reply)
    }
  }

  private openUser(username: string): void {
    if (this.onUserClick) {
      this.onUserClick(username)
    }
  }

  private openImage(url: string): void {
    if (this.onImageClick) {
      this.onImageClick(url)
    }
  }

  private openLink(url: string): void {
    if (this.onLinkClick) {
      this.onLinkClick(url)
    }
  }

  @Builder
  private Header() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      SymbolGlyph($r('sys.symbol.heart_fill'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor([ThemeConstants.BRAND_PRIMARY])
      Text(this.headerText())
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Blank()
      SymbolGlyph(
        this.expanded
          ? $r('sys.symbol.arrowtriangle_up_fill')
          : $r('sys.symbol.arrowtriangle_down_fill'),
      )
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_MD,
      top: ThemeConstants.SPACE_XS,
      bottom: ThemeConstants.SPACE_XS,
    })
    .onClick(() => {
      this.toggleExpanded()
    })
  }

  @Builder
  private ReplyItem(reply: V2exReply) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      ReplyCard({
        reply: reply,
        floor: reply.floor || 0,
        isOp: this.isOp(reply),
        isThanked: this.replyThanked(reply),
        isThankPending: this.replyThankPending(reply),
        threadLevel: 0,
        relationLabel: '',
        displayContent: '',
        childReplies: [],
        embedded: true,
        opMemberId: this.opMemberId,
        hideLeadingMention: true,
        isWrongReference: !!reply.isWrongReference,
        isDuplicateThreadItem: false,
        onUserClick: (target: V2exReply) => {
          this.openUser(target.member.username)
        },
        onContextClick: (target: V2exReply) => {
          this.runReplyAction(target, this.onContextClick)
        },
        onMentionClick: (target: V2exReply) => {
          this.runReplyAction(target, this.onReplyClick)
        },
        onReplyClick: (target: V2exReply) => {
          this.runReplyAction(target, this.onReplyClick)
        },
        onThankClick: (target: V2exReply) => {
          this.runReplyAction(target, this.onThankClick)
        },
        onIgnoreClick: (target: V2exReply) => {
          this.runReplyAction(target, this.onIgnoreClick)
        },
        onReportClick: (target: V2exReply) => {
          this.runReplyAction(target, this.onReportClick)
        },
        onCopyUserClick: (target: V2exReply) => {
          this.runReplyAction(target, this.onCopyUserClick)
        },
        onCopyContentClick: (target: V2exReply) => {
          this.runReplyAction(target, this.onCopyContentClick)
        },
        onFloorClick: (target: V2exReply) => {
          this.jumpToReply(target)
        },
        isReplyThanked: (target: V2exReply) => {
          return this.replyThanked(target)
        },
        isReplyThankPending: (target: V2exReply) => {
          return this.replyThankPending(target)
        },
        onImageClick: (url: string) => {
          this.openImage(url)
        },
        onLinkClick: (url: string) => {
          this.openLink(url)
        },
        onMentionUserClick: (username: string) => {
          this.openUser(username)
        },
      })

      if ((reply.threadChildren || []).length > 0) {
        this.ChildReplyGroup(reply)
      }
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_SM,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_MD,
      bottom: ThemeConstants.SPACE_MD,
    })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  private ChildReplyGroup(reply: V2exReply) {
    Column() {
      ForEach(
        reply.threadChildren || [],
        (child: V2exReply, index: number) => {
          this.ChildReply(child, 1, index >= (reply.threadChildren || []).length - 1)
        },
        (child: V2exReply) => this.replyKey(child),
      )
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: 0,
      top: ThemeConstants.SPACE_SM,
      bottom: 0,
    })
  }

  @Builder
  private ChildReply(reply: V2exReply, level: number, isLast: boolean) {
    Row() {
      if (this.childGuideHeight(reply, isLast) > 0) {
        Divider()
          .vertical(true)
          .strokeWidth(HOT_REPLY_THREAD_GUIDE_LINE_WIDTH)
          .color($r('sys.color.ohos_id_color_list_separator'))
          .height(this.childGuideHeight(reply, isLast))
          .margin({ right: HOT_REPLY_THREAD_GUIDE_CONTENT_GAP })
      } else {
        Column()
          .width(HOT_REPLY_THREAD_GUIDE_LINE_WIDTH)
          .margin({ right: HOT_REPLY_THREAD_GUIDE_CONTENT_GAP })
      }
      Column({ space: ThemeConstants.SPACE_XS }) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          UserName({
            username: reply.member.username,
            fontSize: ThemeConstants.FONT_SIZE_META,
            fontWeight: FontWeight.Medium,
            isPro: (reply.member.pro || 0) > 0,
            isMod: (reply.member.mod || 0) > 0,
            showUserMarks: false,
            onUserClick: () => {
              this.openUser(reply.member.username)
            },
          })
            .layoutWeight(1)
          Text(`#${reply.floor || 0}`)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .onClick(() => {
              this.jumpToReply(reply)
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.childContentSource(reply).length > 0) {
          MarkdownContent({
            source: this.childContentSource(reply),
            topMargin: 0,
            onImageClick: (url: string) => {
              this.openImage(url)
            },
            onLinkClick: (url: string) => {
              this.openLink(url)
            },
            onMentionClick: (username: string) => {
              this.openUser(username)
            },
          })
        }

        if ((reply.threadChildren || []).length > 0) {
          Column() {
            ForEach(
              reply.threadChildren || [],
              (child: V2exReply, index: number) => {
                this.ChildReply(child, level + 1, index >= (reply.threadChildren || []).length - 1)
              },
              (child: V2exReply) => this.replyKey(child),
            )
          }
          .width('100%')
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({
      left: Math.min(level, 3) * ThemeConstants.SPACE_SM,
      bottom: isLast ? 0 : ThemeConstants.SPACE_SM,
    })
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateChildGuideHeight(reply, newValue)
    })
  }

  build() {
    if (this.replies.length > 0) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        this.Header()
        if (this.expanded) {
          Column({ space: ThemeConstants.SPACE_SM - 2 }) {
            ForEach(
              this.replies,
              (reply: V2exReply) => {
                this.ReplyItem(reply)
              },
              (reply: V2exReply) => this.replyKey(reply),
            )
          }
          .width('100%')
        }
      }
      .width('100%')
    }
  }
}
