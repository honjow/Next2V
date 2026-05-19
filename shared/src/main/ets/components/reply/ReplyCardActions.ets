import { V2exReply } from '../../network/NetworkTypes'
import { ThemeConstants } from '../../theme/ThemeConstants'
import { SymbolGlyphModifier } from '@kit.ArkUI'

@Component
export struct ReplyCardActions {
  @Prop reply: V2exReply;
  @Prop isThanked: boolean = false;
  @Prop isThankPending: boolean = false;
  onActionsClick?: (reply: V2exReply) => void;
  onContextClick?: (reply: V2exReply) => void;
  onReplyClick?: (reply: V2exReply) => void;
  onThankClick?: (reply: V2exReply) => void;
  onIgnoreClick?: (reply: V2exReply) => void;
  onReportClick?: (reply: V2exReply) => void;
  onCopyUserClick?: (reply: V2exReply) => void;
  onCopyContentClick?: (reply: V2exReply) => void;
  @State private actionsMenuShown: boolean = false;
  @State contextIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.ellipsis_bubble'));
  @State copyUserIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.person'));
  @State copyContentIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.doc_plaintext'));
  @State ignoreIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark'));
  @State reportIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.exclamationmark_triangle'));

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
        MenuItem({ content: '查看上下文', symbolStartIcon: this.contextIcon }).onClick(
          () => {
            this.runContextAction(this.onContextClick)
          },
        )
      }

      if (this.onCopyUserClick) {
        MenuItem({ content: '复制用户名', symbolStartIcon: this.copyUserIcon }).onClick(() => {
          this.runContextAction(this.onCopyUserClick)
        })
      }

      if (this.onCopyContentClick) {
        MenuItem({ content: '复制回复内容', symbolStartIcon: this.copyContentIcon }).onClick(
          () => {
            this.runContextAction(this.onCopyContentClick)
          },
        )
      }

      if (this.onIgnoreClick) {
        MenuItem({ content: '忽略回复', symbolStartIcon: this.ignoreIcon }).onClick(() => {
          this.runContextAction(this.onIgnoreClick)
        })
      }

      if (this.onReportClick) {
        MenuItem({
          content: '举报回复',
          symbolStartIcon: this.reportIcon,
        }).onClick(() => {
          this.runContextAction(this.onReportClick)
        })
      }
    }
  }

  @Builder
  ThankButton() {
    if (this.onThankClick) {
      Button() {
        Row({ space: ThemeConstants.SPACE_XS }) {
          SymbolGlyph(this.isThanked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontColor([
              this.isThanked || this.reply.thanks > 0 ? '#E84026' : $r('sys.color.font_secondary'),
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
      .enabled(!this.isThankPending)
      .onClick(() => {
        if (this.onThankClick && !this.isThankPending) {
          this.onThankClick(this.reply)
        }
      })
    }
  }

  @Builder
  ReplyButton() {
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
  }

  @Builder
  MoreButton() {
    if (this.hasContextMenuActions()) {
      Button() {
        SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
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
        SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
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

  build() {
    Row() {
      this.ThankButton()
      this.ReplyButton()
      this.MoreButton()
    }
    .alignItems(VerticalAlign.Center)
  }
}
