import { V2exReply } from '../network/NetworkTypes'
import { ReplyCardStyleState, connectReplyCardStyle } from '../state/ReplyCardStyleState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { TimeAgo } from './TimeAgo'
import { MarkdownContent } from './MarkdownContent'
import { ReplyCardActions } from './reply/ReplyCardActions'
import { ReplyCardHeader } from './reply/ReplyCardHeader'
import { ReplyCardLayoutPolicy } from './reply/ReplyCardLayoutPolicy'
@ComponentV2
export struct ReplyCard {
  @Require @Param reply: V2exReply;
  @Param floor: number = 1;
  @Param isOp: boolean = false;
  @Param isThanked: boolean = false;
  @Param isThankPending: boolean = false;
  @Param threadLevel: number = 0;
  @Param relationLabel: string = '';
  @Param displayContent: string = '';
  @Param isWrongReference: boolean = false;
  @Param isDuplicateThreadItem: boolean = false;
  @Param childReplies: V2exReply[] = [];
  @Param embedded: boolean = false;
  @Param opMemberId: number = 0;
  @Param hideLeadingMention: boolean = false;
  @Local private cardWidth: number = 0;
  @Local private threadGuideHeights: Record<string, number> = {};
  @Event onUserClick?: (reply: V2exReply) => void;
  @Event onActionsClick?: (reply: V2exReply) => void;
  @Event onContextClick?: (reply: V2exReply) => void;
  @Event onMentionClick?: (reply: V2exReply) => void;
  @Event onReplyClick?: (reply: V2exReply) => void;
  @Event onThankClick?: (reply: V2exReply) => void;
  @Event onIgnoreClick?: (reply: V2exReply) => void;
  @Event onReportClick?: (reply: V2exReply) => void;
  @Event onCopyUserClick?: (reply: V2exReply) => void;
  @Event onCopyContentClick?: (reply: V2exReply) => void;
  @Event isReplyThanked?: (reply: V2exReply) => boolean;
  @Event isReplyThankPending?: (reply: V2exReply) => boolean;
  @Event onImageClick?: (url: string) => void;
  @Event onLinkClick?: (url: string) => void;
  @Event onMentionUserClick?: (username: string) => void;
  // V2 mirror of REPLY_CARD_STYLE; ReplyCardStyleSettings.apply() dual-writes this @Trace
  // field alongside the legacy AppStorage key still read by the V1 SettingsPage.
  private replyStyleState: ReplyCardStyleState = connectReplyCardStyle();

  private isCompact(): boolean {
    return this.replyStyleState.replyCardStyle === 'compact'
  }

  // Compact mode packs the timestamp + action buttons into the header row; once the measured card
  // width drops below the policy threshold (narrow phones, deeply-threaded 楼中楼 replies) that row
  // overflows, so the header stacks the timestamp under the username and folds the buttons into a menu.
  private isHeaderNarrow(): boolean {
    return this.isCompact() && ReplyCardLayoutPolicy.compactHeaderStacked(this.cardWidth)
  }

  private threadIndent(): number {
    return ReplyCardLayoutPolicy.threadIndent(this.threadLevel, this.cardWidth)
  }

  private contentSource(): string {
    const override = (this.displayContent || '').trim()
    if (override) {
      return this.displayContent
    }
    const rendered = (this.reply.content_rendered || '').trim()
    // V2EX web collapses ordinary whitespace in rendered reply HTML. Render the
    // same source when it is available so single source newlines do not become
    // app-only hard line breaks, and linked embedded images keep source order.
    if (rendered.length > 0) {
      return this.reply.content_rendered
    }
    return this.reply.content
  }

  private visibleMentionPrefix(reply: V2exReply): string {
    const users = reply.replyUsers || []
    if (users.length === 0 || (reply.threadLevel || 0) <= 0) {
      return ''
    }
    const content = (reply.content || '').trimStart()
    const first = users[0] || ''
    if (first && this.startsWithMention(content, first)) {
      return ''
    }
    return `${users.map((name: string) => `@${name}`).join(' ')} `
  }

  private startsWithMention(content: string, username: string): boolean {
    const source = (content || '').trimStart()
    const name = (username || '').trim()
    if (!source || !name) {
      return false
    }
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const rawMention = new RegExp(`^@${escaped}(?:$|\\s|#|[：:，,。.!?])`, 'i')
    if (rawMention.test(source)) {
      return true
    }
    const markdownMemberLink = new RegExp(
      `^\\[@?${escaped}\\]\\((?:https?:\\/\\/(?:www\\.)?v2ex\\.(?:com|co))?\\/member\\/${escaped}(?:[?#][^)]*)?\\)(?:$|\\s|#|[：:，,。.!?])`,
      'i',
    )
    return markdownMemberLink.test(source)
  }

  private childDisplayContent(reply: V2exReply): string {
    if (
      this.hideLeadingMention &&
      (reply.hiddenLeadingMentionContent || '').trim() &&
      (reply.threadLevel || 0) > 0 &&
      (reply.replyUsers || []).length === 1
    ) {
      if ((reply.hiddenLeadingMentionRenderedContent || '').trim()) {
        return reply.hiddenLeadingMentionRenderedContent || ''
      }
      return reply.hiddenLeadingMentionContent || ''
    }
    const prefix = this.visibleMentionPrefix(reply)
    if (prefix) {
      return `${prefix}${reply.content || ''}`
    }
    return ''
  }

  private childIsThanked(reply: V2exReply): boolean {
    if (this.isReplyThanked) {
      return this.isReplyThanked(reply)
    }
    return false
  }

  private childIsThankPending(reply: V2exReply): boolean {
    if (this.isReplyThankPending) {
      return this.isReplyThankPending(reply)
    }
    return false
  }

  private childKey(reply: V2exReply): string {
    return reply.renderKey || reply.id.toString()
  }

  private childMeasuredHeight(reply: V2exReply): number {
    return this.threadGuideHeights[this.childKey(reply)] || 0
  }

  private childGuideHeight(reply: V2exReply, index: number): number {
    const height = this.childMeasuredHeight(reply)
    if (index >= this.childReplies.length - 1) {
      return Math.max(0, height - ReplyCardLayoutPolicy.THREAD_GUIDE_END_INSET)
    }
    return height
  }

  private childReplyBottomGap(index: number): number {
    if (!this.isCompact() || index >= this.childReplies.length - 1) {
      return 0
    }
    return ReplyCardLayoutPolicy.COMPACT_CHILD_REPLY_GAP
  }

  private childReplyListTopGap(): number {
    if (!this.isCompact() || this.childReplies.length === 0) {
      return 0
    }
    return ReplyCardLayoutPolicy.COMPACT_CHILD_REPLY_GAP
  }

  private updateChildGuideHeight(reply: V2exReply, area: Area): void {
    const height = typeof area.height === 'number'
      ? area.height
      : Number.parseFloat(area.height as string)
    if (Number.isNaN(height) || Math.abs(height - this.childMeasuredHeight(reply)) < 0.5) {
      return
    }
    // V2 @Local triggers on reference change, not in-place key mutation, so rebuild the record
    // to re-render the thread-guide Divider height (the V1 @State self-assign relied on
    // every-assignment refresh, which @Local does not provide for an unchanged reference).
    // ArkTS forbids object spread (arkts-no-spread), so copy the existing keys explicitly.
    const next: Record<string, number> = {}
    const existingKeys: string[] = Object.keys(this.threadGuideHeights)
    for (const existingKey of existingKeys) {
      next[existingKey] = this.threadGuideHeights[existingKey]
    }
    next[this.childKey(reply)] = height
    this.threadGuideHeights = next
  }

  private cardBackground(): ResourceColor | Color {
    if (this.embedded) {
      return Color.Transparent
    }
    return $r('sys.color.ohos_id_color_card_bg')
  }

  build() {
    Row() {
      Column() {
        ReplyCardHeader({
          reply: this.reply,
          floor: this.floor,
          isOp: this.isOp,
          isDuplicateThreadItem: this.isDuplicateThreadItem,
          isCompact: this.isCompact(),
          isNarrow: this.isHeaderNarrow(),
          isThanked: this.isThanked,
          isThankPending: this.isThankPending,
          onUserClick: this.onUserClick,
          onActionsClick: this.onActionsClick,
          onContextClick: this.onContextClick,
          onReplyClick: this.onReplyClick,
          onThankClick: this.onThankClick,
          onIgnoreClick: this.onIgnoreClick,
          onReportClick: this.onReportClick,
          onCopyUserClick: this.onCopyUserClick,
          onCopyContentClick: this.onCopyContentClick,
        })

        if (this.contentSource()) {
          Column() {
            MarkdownContent({
              source: this.contentSource(),
              topMargin: ReplyCardLayoutPolicy.CONTENT_GAP,
              onImageClick: this.onImageClick,
              onLinkClick: this.onLinkClick,
              onMentionClick: this.onMentionUserClick,
            })
          }.width('100%')
        }

        if (!this.isCompact()) {
          Row() {
            TimeAgo({ timestamp: this.reply.created })
            Blank()
            ReplyCardActions({
              reply: this.reply,
              isThanked: this.isThanked,
              isThankPending: this.isThankPending,
              onActionsClick: this.onActionsClick,
              onContextClick: this.onContextClick,
              onReplyClick: this.onReplyClick,
              onThankClick: this.onThankClick,
              onIgnoreClick: this.onIgnoreClick,
              onReportClick: this.onReportClick,
              onCopyUserClick: this.onCopyUserClick,
              onCopyContentClick: this.onCopyContentClick,
            })
          }
          .width('100%')
          .margin({ top: ReplyCardLayoutPolicy.ACTIONS_GAP })
          .alignItems(VerticalAlign.Center)
        }

        if (this.childReplies.length > 0) {
          Column() {
            ForEach(
              this.childReplies,
              (child: V2exReply, index: number) => {
                Row() {
                  if (this.childGuideHeight(child, index) > 0) {
                    Divider()
                      .vertical(true)
                      .strokeWidth(ReplyCardLayoutPolicy.THREAD_GUIDE_LINE_WIDTH)
                      .color($r('sys.color.ohos_id_color_list_separator'))
                      .height(this.childGuideHeight(child, index))
                      .margin({ right: ReplyCardLayoutPolicy.THREAD_GUIDE_CONTENT_GAP })
                  } else {
                    Column()
                      .width(ReplyCardLayoutPolicy.THREAD_GUIDE_LINE_WIDTH)
                      .margin({ right: ReplyCardLayoutPolicy.THREAD_GUIDE_CONTENT_GAP })
                  }
                  Column() {
                    ReplyCard({
                      reply: child,
                      floor: child.floor || 0,
                      isOp: this.opMemberId > 0 && child.member.id === this.opMemberId,
                      isThanked: this.childIsThanked(child),
                      isThankPending: this.childIsThankPending(child),
                      threadLevel: child.threadLevel || 0,
                      relationLabel: '',
                      displayContent: this.childDisplayContent(child),
                      childReplies: child.threadChildren || [],
                      embedded: true,
                      opMemberId: this.opMemberId,
                      hideLeadingMention: this.hideLeadingMention,
                      isWrongReference: !!child.isWrongReference,
                      isDuplicateThreadItem: !!child.isDuplicateThreadItem,
                      onUserClick: this.onUserClick,
                      onActionsClick: this.onActionsClick,
                      onContextClick: this.onContextClick,
                      onMentionClick: this.onMentionClick,
                      onReplyClick: this.onReplyClick,
                      onThankClick: this.onThankClick,
                      onIgnoreClick: this.onIgnoreClick,
                      onReportClick: this.onReportClick,
                      onCopyUserClick: this.onCopyUserClick,
                      onCopyContentClick: this.onCopyContentClick,
                      isReplyThanked: this.isReplyThanked,
                      isReplyThankPending: this.isReplyThankPending,
                      onImageClick: this.onImageClick,
                      onLinkClick: this.onLinkClick,
                      onMentionUserClick: this.onMentionUserClick,
                    })
                    if (this.childReplyBottomGap(index) > 0) {
                      Blank()
                        .height(this.childReplyBottomGap(index))
                    }
                  }
                  .layoutWeight(1)
                  .onAreaChange((_oldValue: Area, newValue: Area) => {
                    this.updateChildGuideHeight(child, newValue)
                  })
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
              },
              (child: V2exReply) => this.childKey(child),
            )
          }
          .width('100%')
          .margin({ top: this.childReplyListTopGap() })
        }
      }
      .padding({
        left: ReplyCardLayoutPolicy.leftPadding(this.embedded, this.threadLevel),
        right: ReplyCardLayoutPolicy.rightPadding(this.embedded),
        top: ReplyCardLayoutPolicy.topPadding(this.embedded),
        bottom: ReplyCardLayoutPolicy.bottomPadding(this.embedded),
      })
      .layoutWeight(1)
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor(this.cardBackground())
    }
    .width('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      if (typeof newValue.width === 'number') {
        this.cardWidth = newValue.width
      } else if (typeof newValue.width === 'string') {
        const parsed = Number.parseFloat(newValue.width)
        this.cardWidth = Number.isNaN(parsed) ? 0 : parsed
      }
    })
  }
}
