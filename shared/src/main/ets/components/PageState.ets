import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct PageLoadingState {
  @Param stateHeight: number = 0
  @Param expand: boolean = true

  build() {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE)
        .height(ThemeConstants.LOADING_SIZE)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(this.stateHeight > 0 ? this.stateHeight : 0)
    .layoutWeight(this.expand ? 1 : 0)
  }
}

@ComponentV2
export struct PageErrorState {
  @Param message: ResourceStr = $r('app.string.common_load_failed')
  @Param retryLabel: ResourceStr = $r('app.string.common_retry')
  @Param secondaryLabel: ResourceStr = ''
  @Param expand: boolean = true
  @Event retryAction?: () => void
  @Event secondaryAction?: () => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.message || $r('app.string.common_load_failed'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Row({ space: ThemeConstants.SPACE_SM }) {
        Button(this.retryLabel)
          .type(ButtonType.Capsule)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .onClick(() => {
            if (this.retryAction) {
              this.retryAction()
            }
          })
        if (this.secondaryLabel) {
          Button(this.secondaryLabel)
            .type(ButtonType.Capsule)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .onClick(() => {
              if (this.secondaryAction) {
                this.secondaryAction()
              }
            })
        }
      }
      .justifyContent(FlexAlign.Center)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(this.expand ? 1 : 0)
  }
}

@ComponentV2
export struct PageLoginRequiredState {
  @Param message: ResourceStr = $r('app.string.login_required_continue')
  @Param actionLabel: ResourceStr = $r('app.string.login_action')
  @Param expand: boolean = true
  @Event action?: () => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button(this.actionLabel)
        .type(ButtonType.Capsule)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .onClick(() => {
          if (this.action) {
            this.action()
          }
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(this.expand ? 1 : 0)
  }
}

@ComponentV2
export struct CardEmptyState {
  @Param message: ResourceStr = ''
  @Param expand: boolean = true

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding(ThemeConstants.SPACE_LG)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(this.expand ? 1 : 0)
  }
}
