import { V2exReply } from '../../network/NetworkTypes'
import { ThemeConstants } from '../../theme/ThemeConstants'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AppStrings } from '../../i18n/AppStrings'

@ComponentV2
export struct ReplyCardActions {
  @Require @Param reply: V2exReply;
  @Param isThanked: boolean = false;
  @Param isThankPending: boolean = false;
  // When the header is too narrow, the three inline buttons (thank / reply / more) collapse into a
  // single overflow menu; thank and reply are then prepended as menu items so nothing is lost.
  @Param collapsed: boolean = false;
  @Param actionButtonSize: number = ThemeConstants.TOUCH_TARGET_SM;
  @Event onActionsClick?: (reply: V2exReply) => void;
  @Event onContextClick?: (reply: V2exReply) => void;
  @Event onReplyClick?: (reply: V2exReply) => void;
  @Event onThankClick?: (reply: V2exReply) => void;
  @Event onIgnoreClick?: (reply: V2exReply) => void;
  @Event onReportClick?: (reply: V2exReply) => void;
  @Event onCopyUserClick?: (reply: V2exReply) => void;
  @Event onCopyContentClick?: (reply: V2exReply) => void;
  @Local private actionsMenuShown: boolean = false;
  @Local thankIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.heart'));
  @Local thankFilledIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.heart_fill'));
  @Local replyIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.arrowshape_turn_up_left'));
  @Local contextIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.ellipsis_bubble'));
  @Local copyUserIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.person'));
  @Local copyContentIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.doc_plaintext'));
  @Local ignoreIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark'));
  @Local reportIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.exclamationmark_triangle'));

  private hasContextMenuActions(): boolean {
    return !!(
      this.onContextClick ||
      this.onCopyUserClick ||
      this.onCopyContentClick ||
      this.onIgnoreClick ||
      this.onReportClick
    )
  }

  private menuHasItems(): boolean {
    if (this.collapsed && (!!this.onThankClick || !!this.onReplyClick)) {
      return true
    }
    return this.hasContextMenuActions()
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
      if (this.collapsed && this.onThankClick) {
        MenuItem({
          content: AppStrings.text($r('app.string.reply_thank_title'), 'Thank reply'),
          symbolStartIcon: this.isThanked || this.reply.thanks > 0 ? this.thankFilledIcon : this.thankIcon,
        }).onClick(() => {
          this.runContextAction((reply: V2exReply) => {
            if (this.onThankClick && !this.isThankPending) {
              this.onThankClick(reply)
            }
          })
        })
      }

      if (this.collapsed && this.onReplyClick) {
        MenuItem({
          content: AppStrings.text($r('app.string.reply_action_reply'), 'Reply'),
          symbolStartIcon: this.replyIcon,
        }).onClick(() => {
          this.runContextAction(this.onReplyClick)
        })
      }

      if (this.onContextClick) {
        MenuItem({
          content: AppStrings.text($r('app.string.reply_view_context'), 'View context'),
          symbolStartIcon: this.contextIcon
        }).onClick(
          () => {
            this.runContextAction(this.onContextClick)
          },
        )
      }

      if (this.onCopyUserClick) {
        MenuItem({ content: $r('app.string.common_copy_username'), symbolStartIcon: this.copyUserIcon }).onClick(() => {
          this.runContextAction(this.onCopyUserClick)
        })
      }

      if (this.onCopyContentClick) {
        MenuItem({
          content: AppStrings.text($r('app.string.reply_copy_content'), 'Copy reply content'),
          symbolStartIcon: this.copyContentIcon
        }).onClick(
          () => {
            this.runContextAction(this.onCopyContentClick)
          },
        )
      }

      if (this.onIgnoreClick) {
        MenuItem({
          content: AppStrings.text($r('app.string.reply_ignore_reply'), 'Ignore reply'),
          symbolStartIcon: this.ignoreIcon
        }).onClick(() => {
          this.runContextAction(this.onIgnoreClick)
        })
      }

      if (this.onReportClick) {
        MenuItem({
          content: AppStrings.text($r('app.string.reply_report_reply'), 'Report reply'),
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
      .constraintSize({ minWidth: this.actionButtonSize })
      .height(this.actionButtonSize)
      .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(Color.Transparent)
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
      .width(this.actionButtonSize)
      .height(this.actionButtonSize)
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
    if (this.menuHasItems()) {
      Button() {
        SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontColor([$r('sys.color.font_secondary')])
      }
      .type(ButtonType.Normal)
      .width(this.actionButtonSize)
      .height(this.actionButtonSize)
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
      .width(this.actionButtonSize)
      .height(this.actionButtonSize)
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
      if (this.collapsed) {
        this.MoreButton()
      } else {
        this.ThankButton()
        this.ReplyButton()
        this.MoreButton()
      }
    }
    .alignItems(VerticalAlign.Center)
  }
}
