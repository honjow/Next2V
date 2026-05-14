import { V2exReply } from '../network/NetworkTypes'
import { ThemeConstants } from '../theme/ThemeConstants'
import { Avatar } from './Avatar'
import { TimeAgo } from './TimeAgo'
import { MarkdownContent } from './MarkdownContent'
import { ImageUtils } from '../utils/ImageUtils'
@Component
export struct ReplyCard {
  @Prop reply: V2exReply;
  @Prop floor: number = 1;
  @Prop isOp: boolean = false;
  @Prop isThanked: boolean = false;
  @Prop isThankPending: boolean = false;
  @Prop threadLevel: number = 0;
  @Prop relationLabel: string = '';
  @Prop displayContent: string = '';
  @Prop isWrongReference: boolean = false;
  @Prop isDuplicateThreadItem: boolean = false;
  @Prop childReplies: V2exReply[] = [];
  @Prop embedded: boolean = false;
  @Prop opMemberId: number = 0;
  @Prop hideLeadingMention: boolean = false;
  @State private cardWidth: number = 0;
  onUserClick?: (reply: V2exReply) => void;
  onActionsClick?: (reply: V2exReply) => void;
  onContextClick?: (reply: V2exReply) => void;
  onMentionClick?: (reply: V2exReply) => void;
  onReplyClick?: (reply: V2exReply) => void;
  onThankClick?: (reply: V2exReply) => void;
  onIgnoreClick?: (reply: V2exReply) => void;
  onReportClick?: (reply: V2exReply) => void;
  onCopyUserClick?: (reply: V2exReply) => void;
  onCopyContentClick?: (reply: V2exReply) => void;
  isReplyThanked?: (reply: V2exReply) => boolean;
  isReplyThankPending?: (reply: V2exReply) => boolean;
  onImageClick?: (url: string) => void;
  onLinkClick?: (url: string) => void;
  onMentionUserClick?: (username: string) => void;
  @State private actionsMenuShown: boolean = false;

  // ---- 回复卡片边距 ----
  private static readonly PADDING_TOP: number = 12; // 卡片上边距
  private static readonly PADDING_BOTTOM: number = 8; // 卡片下边距（顶层卡片，楼中楼固定为 0）
  private static readonly PADDING_LEFT: number = 16; // 顶层卡片左边距
  private static readonly PADDING_LEFT_EMBEDDED: number = 12; // 楼中楼 ≤1层 左边距
  private static readonly PADDING_LEFT_DEEP: number = 16; // 楼中楼 >1层 左边距
  private static readonly PADDING_RIGHT: number = 16; // 顶层卡片右边距（楼中楼固定为 0）
  private static readonly CONTENT_GAP: number = 8; // 头部（用户名行）与正文之间的间距
  private static readonly ACTIONS_GAP: number = 0; // 正文与底部操作栏（时间/感谢/回复）之间的间距
  private static readonly CHILD_DIVIDER_MARGIN: number = 0; // 楼中楼子回复之间分隔线的上下间距

  private threadIndent(): number {
    if (this.threadLevel <= 0) return 0
    const availableWidth = this.cardWidth > 0 ? this.cardWidth : 360
    const indentUnit = Math.max(12, Math.min(20, availableWidth * 0.045))
    const minContentWidth = 240
    const maxByWidth = Math.max(
      1,
      Math.min(3, Math.floor((availableWidth - minContentWidth) / indentUnit)),
    )
    return Math.min(this.threadLevel, maxByWidth) * indentUnit
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

  private cardBackground(): ResourceColor | Color {
    if (this.embedded) {
      return Color.Transparent
    }
    return $r('sys.color.ohos_id_color_card_bg')
  }

  private hasContextMenuActions(): boolean {
    return !!(
      this.onContextClick ||
      this.onCopyUserClick ||
      this.onCopyContentClick ||
      this.onIgnoreClick ||
      this.onReportClick
    )
  }

  private runContextAction(action?: (reply: V2exReply) => void): void {
    this.actionsMenuShown = false
    if (action) {
      setTimeout(() => {
        action(this.reply)
      }, 80)
    }
  }

  private showContextMenu(): void {
    this.actionsMenuShown = false
    setTimeout(() => {
      this.actionsMenuShown = true
    }, 20)
  }

  @Builder
  ReplyActionMenu() {
    Menu() {
      if (this.onContextClick) {
        MenuItem({ content: '查看上下文', startIcon: $r('sys.symbol.ellipsis_bubble') }).onClick(
          () => {
            this.runContextAction(this.onContextClick)
          },
        )
      }

      if (this.onCopyUserClick) {
        MenuItem({ content: '复制用户名', startIcon: $r('sys.symbol.person') }).onClick(() => {
          this.runContextAction(this.onCopyUserClick)
        })
      }

      if (this.onCopyContentClick) {
        MenuItem({ content: '复制回复内容', startIcon: $r('sys.symbol.doc_plaintext') }).onClick(
          () => {
            this.runContextAction(this.onCopyContentClick)
          },
        )
      }

      if (this.onIgnoreClick) {
        MenuItem({ content: '忽略回复', startIcon: $r('sys.symbol.xmark') }).onClick(() => {
          this.runContextAction(this.onIgnoreClick)
        })
      }

      if (this.onReportClick) {
        MenuItem({
          content: '举报回复',
          startIcon: $r('sys.symbol.exclamationmark_triangle'),
        }).onClick(() => {
          this.runContextAction(this.onReportClick)
        })
      }
    }
  }

  build() {
    Row() {
      Column() {
        // 头部：头像 + 用户名/OP/楼层 + 时间
        Row({ space: ThemeConstants.SPACE_SM }) {
          Avatar({
            url: ImageUtils.memberAvatarUrl(this.reply.member),
            avatarSize: ThemeConstants.AVATAR_SIZE_REPLY,
          })
            .onClick(() => {
              if (this.onUserClick) {
                this.onUserClick(this.reply)
              }
            })
          Text(this.reply.member.username)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .onClick(() => {
              if (this.onUserClick) {
                this.onUserClick(this.reply)
              }
            })

          if (this.isOp) {
            Text('OP')
              .fontSize(ThemeConstants.FONT_SIZE_TINY)
              .fontColor($r('sys.color.font_on_primary'))
              .padding({
                left: ThemeConstants.SPACE_XS + 2,
                right: ThemeConstants.SPACE_XS + 2,
                top: 1,
                bottom: 1,
              })
              .borderRadius(ThemeConstants.RADIUS_SM)
              .backgroundColor($r('sys.color.ohos_id_color_activated'))
          }

          if (this.isDuplicateThreadItem) {
            Text('DUP')
              .fontSize(ThemeConstants.FONT_SIZE_TINY)
              .fontColor($r('sys.color.font_secondary'))
              .padding({
                left: ThemeConstants.SPACE_XS + 2,
                right: ThemeConstants.SPACE_XS + 2,
                top: 1,
                bottom: 1,
              })
              .borderRadius(ThemeConstants.RADIUS_SM)
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          }
          Blank()
          Text(`#${this.floor}`)
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.contentSource()) {
          Column() {
            MarkdownContent({
              source: this.contentSource(),
              topMargin: ReplyCard.CONTENT_GAP,
              onImageClick: this.onImageClick,
              onLinkClick: this.onLinkClick,
              onMentionClick: this.onMentionUserClick,
            })
          }.width('100%')
        }

        // 底部：时间 + 操作
        Row() {
          TimeAgo({ timestamp: this.reply.created })
          Blank()

          if (this.onThankClick) {
            Button() {
              Row({ space: ThemeConstants.SPACE_XS }) {
                SymbolGlyph(this.isThanked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
                  .fontSize(ThemeConstants.FONT_SIZE_TITLE)
                  .fontColor([
                    this.isThanked || this.reply.thanks > 0
                      ? '#E84026'
                      : $r('sys.color.font_secondary'),
                  ])
                if (this.reply.thanks > 0) {
                  Text(`${this.reply.thanks}`)
                    .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                    .fontColor('#E84026')
                }
              }.alignItems(VerticalAlign.Center)
            }
            .type(ButtonType.Normal)
            .constraintSize({ minWidth: ThemeConstants.TOUCH_TARGET_SM })
            .height(ThemeConstants.TOUCH_TARGET_SM)
            .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
            .borderRadius(ThemeConstants.RADIUS_ROUND)
            .backgroundColor(Color.Transparent)
            .opacity(this.isThankPending ? 0.45 : 1)
            .enabled(!this.isThankPending)
            .onClick(() => {
              if (this.onThankClick && !this.isThankPending) {
                this.onThankClick(this.reply)
              }
            })
          }

          if (this.onReplyClick) {
            Button() {
              SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left'))
                .fontSize(ThemeConstants.FONT_SIZE_TITLE)
                .fontColor([$r('sys.color.font_secondary')])
            }
            .type(ButtonType.Normal)
            .width(ThemeConstants.TOUCH_TARGET_SM)
            .height(ThemeConstants.TOUCH_TARGET_SM)
            .borderRadius(ThemeConstants.RADIUS_ROUND)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              if (this.onReplyClick) {
                this.onReplyClick(this.reply)
              }
            })
          }

          if (this.hasContextMenuActions()) {
            Button() {
              SymbolGlyph($r('sys.symbol.ellipsis_bubble'))
                .fontSize(ThemeConstants.FONT_SIZE_TITLE)
                .fontColor([$r('sys.color.font_secondary')])
            }
            .type(ButtonType.Normal)
            .width(ThemeConstants.TOUCH_TARGET_SM)
            .height(ThemeConstants.TOUCH_TARGET_SM)
            .borderRadius(ThemeConstants.RADIUS_ROUND)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showContextMenu()
            })
            .bindContextMenu(this.actionsMenuShown, this.ReplyActionMenu, {
              placement: Placement.TopRight,
              aboutToDisappear: () => {
                this.actionsMenuShown = false
              },
            })
          } else if (this.onActionsClick) {
            Button() {
              SymbolGlyph($r('sys.symbol.ellipsis_bubble'))
                .fontSize(ThemeConstants.FONT_SIZE_TITLE)
                .fontColor([$r('sys.color.font_secondary')])
            }
            .type(ButtonType.Normal)
            .width(ThemeConstants.TOUCH_TARGET_SM)
            .height(ThemeConstants.TOUCH_TARGET_SM)
            .borderRadius(ThemeConstants.RADIUS_ROUND)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              if (this.onActionsClick) {
                this.onActionsClick(this.reply)
              }
            })
          }
        }
        .width('100%')
        .margin({ top: ReplyCard.ACTIONS_GAP })
        .alignItems(VerticalAlign.Center)

        if (this.childReplies.length > 0) {
          Column() {
            ForEach(
              this.childReplies,
              (child: V2exReply) => {
                Column() {
                  Divider()
                    .strokeWidth(0.5)
                    .color($r('sys.color.ohos_id_color_list_separator'))
                    .margin({
                      top: ReplyCard.CHILD_DIVIDER_MARGIN,
                      bottom: ReplyCard.CHILD_DIVIDER_MARGIN,
                    })
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
                }.width('100%')
              },
              (child: V2exReply) => child.renderKey || child.id.toString(),
            )
          }.width('100%')
        }
      }
      .padding({
        left: this.embedded
          ? this.threadLevel > 1
            ? ReplyCard.PADDING_LEFT_DEEP
            : ReplyCard.PADDING_LEFT_EMBEDDED
          : ReplyCard.PADDING_LEFT,
        right: this.embedded ? 0 : ReplyCard.PADDING_RIGHT,
        top: ReplyCard.PADDING_TOP,
        bottom: this.embedded ? 0 : ReplyCard.PADDING_BOTTOM,
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
