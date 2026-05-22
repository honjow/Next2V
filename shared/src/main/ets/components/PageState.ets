import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct PageLoadingState {
  @Prop stateHeight: number = 0
  @Prop expand: boolean = true

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

@Component
export struct PageErrorState {
  @Prop message: ResourceStr = AppStrings.R_COMMON_LOAD_FAILED
  @Prop retryLabel: ResourceStr = AppStrings.R_COMMON_RETRY
  @Prop secondaryLabel: ResourceStr = ''
  @Prop expand: boolean = true
  retryAction?: () => void
  secondaryAction?: () => void

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.message || AppStrings.R_COMMON_LOAD_FAILED)
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

@Component
export struct PageLoginRequiredState {
  @Prop message: ResourceStr = AppStrings.R_LOGIN_REQUIRED_CONTINUE
  @Prop actionLabel: ResourceStr = AppStrings.R_LOGIN_ACTION
  @Prop expand: boolean = true
  action?: () => void

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

@Component
export struct CardEmptyState {
  @Prop message: ResourceStr = ''
  @Prop expand: boolean = true

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding(ThemeConstants.SPACE_LG)
        .borderRadius(ThemeConstants.RADIUS_CARD)
        .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(this.expand ? 1 : 0)
  }
}
