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
  onCopyUserClick?: () => void
  onImageClick?: (url: string) => void
  onLinkClick?: (url: string) => void
  onContentLongPress?: () => void
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string = ReadingSettings.DENSITY_STANDARD

  private verticalPadding(): number {
    if (this.readingDensity === ReadingSettings.DENSITY_COMPACT) {
      return ThemeConstants.SPACE_SM
    }
    if (this.readingDensity === ReadingSettings.DENSITY_COMFORTABLE) {
      return ThemeConstants.SPACE_LG
    }
    return ThemeConstants.SPACE_MD
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
            onLinkClick: this.onLinkClick
          })
        }
        .width('100%')
        .gesture(
          LongPressGesture({ duration: 650 })
            .onAction(() => {
              if (this.onContentLongPress) { this.onContentLongPress() }
            })
        )
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

        if (this.onActionsClick) {
          Button() {
            SymbolGlyph($r('sys.symbol.ellipsis_bubble'))
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor([$r('sys.color.font_secondary')])
          }
          .type(ButtonType.Normal)
          .width(30)
          .height(28)
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onClick(() => {
            if (this.onActionsClick) { this.onActionsClick() }
          })
        } else {
          if (this.onContextClick) {
            Button() {
              SymbolGlyph($r('sys.symbol.ellipsis_bubble'))
                .fontSize(ThemeConstants.FONT_SIZE_META)
                .fontColor([$r('sys.color.font_secondary')])
            }
            .type(ButtonType.Normal)
            .width(30)
            .height(28)
            .borderRadius(ThemeConstants.RADIUS_SM)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .onClick(() => {
              if (this.onContextClick) { this.onContextClick() }
            })
          }

          if (this.onMentionClick) {
            Button() {
              Text('@')
                .fontSize(ThemeConstants.FONT_SIZE_META)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_secondary'))
            }
            .type(ButtonType.Normal)
            .width(30)
            .height(28)
            .borderRadius(ThemeConstants.RADIUS_SM)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .margin({ left: ThemeConstants.SPACE_XS })
            .onClick(() => {
              if (this.onMentionClick) { this.onMentionClick() }
            })
          }

          if (this.onCopyUserClick) {
            Button() {
              SymbolGlyph($r('sys.symbol.plus_square_on_square'))
                .fontSize(ThemeConstants.FONT_SIZE_META)
                .fontColor([$r('sys.color.font_secondary')])
            }
            .type(ButtonType.Normal)
            .width(30)
            .height(28)
            .borderRadius(ThemeConstants.RADIUS_SM)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .margin({ left: ThemeConstants.SPACE_XS })
            .onClick(() => {
              if (this.onCopyUserClick) { this.onCopyUserClick() }
            })
          }
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
      bottom: this.verticalPadding()
    })
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}
