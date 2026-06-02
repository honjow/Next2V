import { ThemeConstants } from 'shared'

/**
 * Swipe-to-end actions for the blocked lists page, mirroring NotificationDeleteSwipeAction's
 * red icon button. These carry only the target id; the page owns the optimistic
 * remove / network call / rollback so the component stays a dumb trigger.
 */
@ComponentV2
export struct UnblockMemberSwipeAction {
  @Param memberId: number = 0;
  @Event onUnblock?: (memberId: number) => void;

  build() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.minus_circle'))
          .fontSize(ThemeConstants.ICON_SIZE_SM)
          .fontColor([Color.White])
      }
      .width(48)
      .height(40)
      .backgroundColor(Color.Red)
      .onClick(() => {
        if (this.onUnblock) {
          this.onUnblock(this.memberId)
        }
      })
    }
    .height('100%')
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    .justifyContent(FlexAlign.Center)
  }
}
@ComponentV2
export struct UnignoreTopicSwipeAction {
  @Param topicId: number = 0;
  @Event onUnignore?: (topicId: number) => void;

  build() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.eye'))
          .fontSize(ThemeConstants.ICON_SIZE_SM)
          .fontColor([Color.White])
      }
      .width(48)
      .height(40)
      .backgroundColor(Color.Red)
      .onClick(() => {
        if (this.onUnignore) {
          this.onUnignore(this.topicId)
        }
      })
    }
    .height('100%')
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    .justifyContent(FlexAlign.Center)
  }
}
