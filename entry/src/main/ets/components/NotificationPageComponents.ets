import {
  DateUtils,
  ThemeConstants,
  V2exNotification
} from 'shared'

@Component
export struct NotificationAuthRequiredState {
  @Prop message: string = ''
  onLoginClick?: () => void

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('去登录')
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
      Button('重试')
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
export struct NotificationSummaryCard {
  @Prop count: number = 0
  @Prop errorText: string = ''
  @Prop kindSummary: string = ''
  @Prop cacheUpdatedAt: number = 0
  @Prop loadedFromCache: boolean = false
  @Prop sourceLabel: string = ''

  build() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(`${this.count} 条通知`)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        if (this.errorText && this.count > 0) {
          Text(this.errorText)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          if (this.kindSummary) {
            Text(this.kindSummary)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.cacheUpdatedAt > 0) {
            Text(`${this.loadedFromCache ? '缓存于' :
              '更新于'} ${DateUtils.toDateString(this.cacheUpdatedAt)}${this.sourceLabel ? ' · ' + this.sourceLabel : ''}`)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else if (this.sourceLabel) {
            Text(`来源: ${this.sourceLabel}`)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}

@Component
export struct NotificationCard {
  @Prop item: V2exNotification = { id: 0 }
  @Prop kindTag: string = ''
  @Prop readTag: string = ''
  @Prop titleText: string = ''
  @Prop bodyText: string = ''

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        this.NotificationTag(
          this.kindTag,
          $r('sys.color.ohos_id_color_sub_background'),
          $r('sys.color.font_secondary')
        )
        if (this.readTag) {
          this.NotificationTag(
            this.readTag,
            this.readTag === '未读' ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_sub_background'),
            this.readTag === '未读' ? Color.White : $r('sys.color.font_secondary')
          )
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
      Text(this.bodyText)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.item.created) {
        Text(DateUtils.toRelativeTime(this.item.created))
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder private NotificationTag(text: string, backgroundColor: ResourceColor, foregroundColor: ResourceColor) {
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

@Component
export struct NotificationDeleteSwipeAction {
  @Prop item: V2exNotification = { id: 0 }
  onDeleteClick?: (item: V2exNotification) => void

  build() {
    Row() {
      Button('删除')
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .height(40)
        .fontColor(Color.White)
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
