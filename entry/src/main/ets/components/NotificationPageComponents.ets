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

@ComponentV2
export struct NotificationAuthRequiredState {
  @Param message: string = ''
  @Event onLoginClick?: () => void

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button(AppStrings.text($r('app.string.notification_go_login'), 'Login'))
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

@ComponentV2
export struct NotificationErrorState {
  @Param message: string = ''
  @Event onRetryClick?: () => void

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button(AppStrings.text($r('app.string.common_retry'), 'Retry'))
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

@ComponentV2
export struct NotificationCard {
  @Param item: V2exNotification = { id: 0 }
  @Param kindTag: string = ''
  @Param readTag: string = ''
  @Param titleText: string = ''
  @Param bodyText: string = ''
  @Param replyContent: string = ''
  @Param replyRenderedContent: string = ''
  @Param memberName: string = ''
  @Param avatarUrl: string = ''

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
              AppStrings.text($r('app.string.notification_tag_unread'), 'Unread'),
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
    .backgroundColor($r('app.color.card_background'))
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
        return AppStrings.text($r('app.string.notification_kind_reply'), 'Reply')
      case KIND_MENTION:
        return AppStrings.text($r('app.string.notification_kind_mention'), 'Mention')
      case KIND_THANKS:
        return AppStrings.text($r('app.string.notification_kind_thanks'), 'Thanks')
      case KIND_FAVORITE:
        return AppStrings.text($r('app.string.notification_kind_favorite'), 'Favorite')
      case KIND_FOLLOW:
        return AppStrings.text($r('app.string.notification_kind_follow'), 'Follow')
      case KIND_SYSTEM:
        return AppStrings.text($r('app.string.notification_kind_system'), 'System')
      case KIND_NOTIFICATION:
        return AppStrings.text($r('app.string.notification_kind_notification'), 'Notification')
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

@ComponentV2
export struct NotificationDeleteSwipeAction {
  @Param item: V2exNotification = { id: 0 }
  @Event onDeleteClick?: (item: V2exNotification) => void

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
