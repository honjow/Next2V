import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

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
  private language: LanguageState = connectLanguageState()

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.localeAwareResource(this.message || $r('app.string.common_load_failed')))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Row({ space: ThemeConstants.SPACE_SM }) {
        Button(this.localeAwareResource(this.retryLabel))
          .type(ButtonType.Capsule)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .onClick(() => {
            if (this.retryAction) {
              this.retryAction()
            }
          })
        if (this.secondaryLabel) {
          Button(this.localeAwareResource(this.secondaryLabel))
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

  private localeAwareResource(resource: ResourceStr): ResourceStr {
    if (this.language.effectiveLocale.length >= 0) {
      return resource
    }
    return resource
  }
}

@ComponentV2
export struct PageLoginRequiredState {
  @Param message: ResourceStr = $r('app.string.login_required_continue')
  @Param actionLabel: ResourceStr = $r('app.string.login_action')
  @Param expand: boolean = true
  @Event action?: () => void
  private language: LanguageState = connectLanguageState()

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.localeAwareResource(this.message))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button(this.localeAwareResource(this.actionLabel))
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

  private localeAwareResource(resource: ResourceStr): ResourceStr {
    if (this.language.effectiveLocale.length >= 0) {
      return resource
    }
    return resource
  }
}

@ComponentV2
export struct CardEmptyState {
  @Param message: ResourceStr = ''
  private language: LanguageState = connectLanguageState()
  @Param expand: boolean = true

  build() {
    Column() {
      Text(this.localeAwareResource(this.message))
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

  private localeAwareResource(resource: ResourceStr): ResourceStr {
    if (this.language.effectiveLocale.length >= 0) {
      return resource
    }
    return resource
  }
}
