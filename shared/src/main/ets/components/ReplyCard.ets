import { V2exReply } from '../network/NetworkTypes'
import { StorageKeys } from '../constants/StorageKeys'
import { ReadingSettings } from '../settings/ReadingSettings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { Avatar } from './Avatar'
import { TimeAgo } from './TimeAgo'
import { MarkdownContent } from './MarkdownContent'

@Component
export struct ReplyCard {
  @Prop reply: V2exReply
  @Prop floor: number = 1
  @Prop isOp: boolean = false
  onUserClick?: () => void
  onActionsClick?: () => void
  onContextClick?: () => void
  onMentionClick?: () => void
  onReplyClick?: () => void
  onCopyUserClick?: () => void
  onCopyContentClick?: () => void
  onImageClick?: (url: string) => void
  onLinkClick?: (url: string) => void
  onMentionUserClick?: (username: string) => void
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string = ReadingSettings.DENSITY_STANDARD
  @State private actionsMenuShown: boolean = false

  private verticalPadding(): number {
    if (this.readingDensity === ReadingSettings.DENSITY_COMPACT) {
      return ThemeConstants.SPACE_SM
    }
    if (this.readingDensity === ReadingSettings.DENSITY_COMFORTABLE) {
      return ThemeConstants.SPACE_LG
    }
    return ThemeConstants.SPACE_MD
  }

  private bottomPadding(): number {
    if (this.readingDensity === ReadingSettings.DENSITY_COMPACT) {
      return ThemeConstants.SPACE_XS + 2
    }
    if (this.readingDensity === ReadingSettings.DENSITY_COMFORTABLE) {
      return ThemeConstants.SPACE_MD
    }
    return ThemeConstants.SPACE_SM
  }

  private contentTopMargin(): number {
    if (this.readingDensity === ReadingSettings.DENSITY_COMPACT) {
      return ThemeConstants.SPACE_XS
    }
    if (this.readingDensity === ReadingSettings.DENSITY_COMFORTABLE) {
      return ThemeConstants.SPACE_MD
    }
    return ThemeConstants.SPACE_SM
  }

  private hasContextMenuActions(): boolean {
    return !!(this.onContextClick || this.onMentionClick || this.onCopyUserClick ||
      this.onCopyContentClick)
  }

  private runContextAction(action?: () => void): void {
    this.actionsMenuShown = false
    if (action) {
      action()
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
        MenuItem({ content: '查看上下文' })
          .onClick(() => { this.runContextAction(this.onContextClick) })
      }

      if (this.onMentionClick) {
        MenuItem({ content: '提到用户' })
          .onClick(() => { this.runContextAction(this.onMentionClick) })
      }

      if (this.onCopyUserClick) {
        MenuItem({ content: '复制用户名' })
          .onClick(() => { this.runContextAction(this.onCopyUserClick) })
      }

      if (this.onCopyContentClick) {
        MenuItem({ content: '复制回复内容' })
          .onClick(() => { this.runContextAction(this.onCopyContentClick) })
      }
    }
  }

  build() {
    Column() {
      // 头部：头像 + 用户名/OP/楼层 + 时间
      Row({ space: ThemeConstants.SPACE_SM }) {
        Avatar({ url: this.reply.member.avatar_mini, avatarSize: ThemeConstants.AVATAR_SIZE_REPLY })
          .onClick(() => {
            if (this.onUserClick) { this.onUserClick() }
          })

        Text(this.reply.member.username)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            if (this.onUserClick) { this.onUserClick() }
          })

        if (this.isOp) {
          Text('OP')
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_on_primary'))
            .padding({
              left: ThemeConstants.SPACE_XS + 2,
              right: ThemeConstants.SPACE_XS + 2,
              top: 1,
              bottom: 1
            })
            .borderRadius(ThemeConstants.RADIUS_SM)
            .backgroundColor($r('sys.color.ohos_id_color_activated'))
        }

        Blank()

        Text(`#${this.floor}`)
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.reply.content) {
        Column() {
          MarkdownContent({
            source: this.reply.content,
            topMargin: this.contentTopMargin(),
            onImageClick: this.onImageClick,
            onLinkClick: this.onLinkClick,
            onMentionClick: this.onMentionUserClick
          })
        }
        .width('100%')
      }

      // 底部：时间 + 感谢数
      Row() {
        TimeAgo({ timestamp: this.reply.created })

        if (this.reply.thanks > 0) {
          Text('·')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
          SymbolGlyph($r('sys.symbol.heart_fill'))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor([$r('sys.color.font_emphasize')])
          Text(` ${this.reply.thanks}`)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_emphasize'))
        }

        Blank()

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
            if (this.onReplyClick) { this.onReplyClick() }
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
            }
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
            if (this.onActionsClick) { this.onActionsClick() }
          })
        }
      }
      .width('100%')
      .margin({ top: ThemeConstants.SPACE_SM })
      .alignItems(VerticalAlign.Center)
    }
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: this.verticalPadding(),
      bottom: this.bottomPadding()
    })
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
