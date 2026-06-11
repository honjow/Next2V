import {
  AppStrings,
  MarkdownContent,
  ReplyCard,
  ThemeConstants,
  UserName,
  V2exReply,
} from 'shared'

@ComponentV2
export struct HotRepliesPanel {
  @Param replies: V2exReply[] = [];
  @Param minThanks: number = 3;
  @Param opMemberId: number = 0;
  @Param expanded: boolean = true;
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

  private thresholdText(): string {
    return AppStrings.format(
      AppStrings.text($r('app.string.hot_replies_threshold_format'), '≥ {0} likes'),
      [`${this.minThanks}`],
    )
  }

  private jumpText(reply: V2exReply): string {
    return AppStrings.format(
      AppStrings.text($r('app.string.hot_replies_jump_format'), 'Go to #{0}'),
      [`${reply.floor || 0}`],
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
      Text(this.thresholdText())
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
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

      Row() {
        Blank()
        Text(this.jumpText(reply))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .onClick(() => {
            this.jumpToReply(reply)
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
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
    Column({ space: ThemeConstants.SPACE_SM }) {
      ForEach(
        reply.threadChildren || [],
        (child: V2exReply) => {
          this.ChildReply(child, 1)
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
  private ChildReply(reply: V2exReply, level: number) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Divider()
        .vertical(true)
        .strokeWidth(0.5)
        .color($r('sys.color.ohos_id_color_list_separator'))
        .height(ThemeConstants.SPACE_XL)
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
          Column({ space: ThemeConstants.SPACE_SM }) {
            ForEach(
              reply.threadChildren || [],
              (child: V2exReply) => {
                this.ChildReply(child, level + 1)
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
    .padding({ left: Math.min(level, 3) * ThemeConstants.SPACE_SM })
  }

  build() {
    if (this.replies.length > 0) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        this.Header()
        if (this.expanded) {
          Column({ space: ThemeConstants.SPACE_MD }) {
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
