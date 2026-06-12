import {
  AppStrings,
  ReplyCard,
  ThemeConstants,
  V2exReply,
} from 'shared'

@ComponentV2
export struct HotRepliesPanel {
  @Param replies: V2exReply[] = [];
  @Param opMemberId: number = 0;
  @Param expanded: boolean = true;
  @Param childRepliesDefaultExpanded: boolean = false;
  @Param childRepliesExpandedByKey: Record<string, boolean> = {};
  @Event onExpandedChange?: (expanded: boolean) => void;
  @Event onChildRepliesExpandedChange?: (reply: V2exReply, expanded: boolean) => void;
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

  private replyKey(reply: V2exReply): string {
    return reply.renderKey || reply.id.toString()
  }

  private childRepliesStateKey(reply: V2exReply): string {
    if (reply.id > 0) {
      return reply.id.toString()
    }
    return this.replyKey(reply)
  }

  private isChildRepliesExpanded(reply: V2exReply): boolean {
    const cached = this.childRepliesExpandedByKey[this.childRepliesStateKey(reply)]
    if (cached === true || cached === false) {
      return cached
    }
    return this.childRepliesDefaultExpanded
  }

  private setChildRepliesExpanded(reply: V2exReply, expanded: boolean): void {
    if (this.onChildRepliesExpandedChange) {
      this.onChildRepliesExpandedChange(reply, expanded)
    }
  }

  private toggleExpanded(): void {
    const next = !this.expanded
    if (this.onExpandedChange) {
      this.getUIContext().animateTo(
        { duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut },
        () => {
          if (this.onExpandedChange) {
            this.onExpandedChange(next)
          }
        },
      )
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
        childReplies: reply.threadChildren || [],
        embedded: true,
        opMemberId: this.opMemberId,
        hideLeadingMention: true,
        childAvatarVisible: false,
        childRepliesExpandable: true,
        childRepliesExpanded: this.isChildRepliesExpanded(reply),
        onChildRepliesExpandedChange: (target: V2exReply, expanded: boolean) => {
          this.setChildRepliesExpanded(target, expanded)
        },
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
          .transition(TransitionEffect.OPACITY)
        }
      }
      .width('100%')
    }
  }
}
