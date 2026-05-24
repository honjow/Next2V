import {
  Avatar,
  DateUtils,
  MarkdownContent,
  ThemeConstants,
  V2exNotification
} from 'shared'
import { AppStrings } from 'shared'
import {
  READ_TAG_UNREAD,
  KIND_REPLY, KIND_MENTION, KIND_THANKS, KIND_FAVORITE,
  KIND_FOLLOW, KIND_SYSTEM, KIND_NOTIFICATION
} from '../viewmodel/NotificationCenterViewModel'

@Component
export struct NotificationAuthRequiredState {
  @Prop message: string = ''
  onLoginClick?: () => void

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button(AppStrings.text(AppStrings.R_NOTIFICATION_GO_LOGIN, 'Login'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => {
          if (this.onLoginClick) {
            this.onLoginClick()
          }
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }
}

@Component
export struct NotificationErrorState {
  @Prop message: string = ''
  onRetryClick?: () => void

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button(AppStrings.text(AppStrings.R_COMMON_RETRY, 'Retry'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => {
          if (this.onRetryClick) {
            this.onRetryClick()
          }
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }
}

@Component
export struct NotificationCard {
  @Prop item: V2exNotification = { id: 0 }
  @Prop kindTag: string = ''
  @Prop readTag: string = ''
  @Prop titleText: string = ''
  @Prop bodyText: string = ''
  @Prop replyContent: string = ''
  @Prop replyRenderedContent: string = ''
  @Prop memberName: string = ''
  @Prop avatarUrl: string = ''

  build() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Avatar({
        url: this.avatarUrl,
        avatarSize: ThemeConstants.AVATAR_SIZE_REPLY,
        placeholder: this.memberName
      })
      Column({ space: ThemeConstants.SPACE_SM }) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          this.NotificationTag(
            this.kindTagDisplay(this.kindTag),
            $r('sys.color.ohos_id_color_sub_background'),
            $r('sys.color.font_secondary')
          )
          if (this.readTag) {
            this.NotificationTag(
              AppStrings.text(AppStrings.R_NOTIFICATION_TAG_UNREAD, 'Unread'),
              this.readTag === READ_TAG_UNREAD ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_sub_background'),
              this.readTag === READ_TAG_UNREAD ? Color.White : $r('sys.color.font_secondary')
            )
          }
          if (this.memberName) {
            Text(this.memberName)
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)

        Text(this.titleText)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.replyPreviewSource()) {
          this.ReplyPreview()
        } else if (this.bodyText) {
          Text(this.bodyText)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        if (this.item.created) {
          Text(DateUtils.toRelativeTime(this.item.created))
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder private ReplyPreview() {
    Column() {
      MarkdownContent({
        source: this.replyPreviewSource(),
        topMargin: 0
      })
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_MD,
      top: ThemeConstants.SPACE_SM,
      bottom: ThemeConstants.SPACE_SM
    })
    .borderRadius(ThemeConstants.RADIUS_SM)
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private replyPreviewSource(): string {
    return this.replyRenderedContent || this.replyContent
  }

  private kindTagDisplay(code: string): string {
    switch (code) {
      case KIND_REPLY:
        return AppStrings.text(AppStrings.R_NOTIFICATION_KIND_REPLY, 'Reply')
      case KIND_MENTION:
        return AppStrings.text(AppStrings.R_NOTIFICATION_KIND_MENTION, 'Mention')
      case KIND_THANKS:
        return AppStrings.text(AppStrings.R_NOTIFICATION_KIND_THANKS, 'Thanks')
      case KIND_FAVORITE:
        return AppStrings.text(AppStrings.R_NOTIFICATION_KIND_FAVORITE, 'Favorite')
      case KIND_FOLLOW:
        return AppStrings.text(AppStrings.R_NOTIFICATION_KIND_FOLLOW, 'Follow')
      case KIND_SYSTEM:
        return AppStrings.text(AppStrings.R_NOTIFICATION_KIND_SYSTEM, 'System')
      case KIND_NOTIFICATION:
        return AppStrings.text(AppStrings.R_NOTIFICATION_KIND_NOTIFICATION, 'Notification')
      default:
        return code
    }
  }

  @Builder private NotificationTag(text: string, backgroundColor: ResourceColor, foregroundColor: ResourceColor) {
    if (text) {
      Text(text)
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .fontColor(foregroundColor)
        .padding({
          left: ThemeConstants.SPACE_SM,
          right: ThemeConstants.SPACE_SM,
          top: ThemeConstants.SPACE_XS / 2,
          bottom: ThemeConstants.SPACE_XS / 2
        })
        .borderRadius(ThemeConstants.RADIUS_SM)
        .backgroundColor(backgroundColor)
    }
  }
}

@Component
export struct NotificationDeleteSwipeAction {
  @Prop item: V2exNotification = { id: 0 }
  onDeleteClick?: (item: V2exNotification) => void

  build() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(ThemeConstants.ICON_SIZE_SM)
          .fontColor([Color.White])
      }
      .width(48)
      .height(40)
      .backgroundColor(Color.Red)
      .onClick(() => {
        if (this.onDeleteClick) {
          this.onDeleteClick(this.item)
        }
      })
    }
    .height('100%')
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    .justifyContent(FlexAlign.Center)
  }
}
