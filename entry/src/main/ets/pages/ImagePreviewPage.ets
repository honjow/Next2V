import { ThemeConstants } from 'shared'

@Component
export struct ImagePreviewPage {
  @Prop url: string = ''

  @State private viewportWidth: number = 0
  @State private scaleValue: number = 1
  @State private pinchValue: number = 1

  private clampScale(value: number): number {
    if (!Number.isFinite(value)) {
      return 1
    }
    if (value < 1) {
      return 1
    }
    if (value > 4) {
      return 4
    }
    return value
  }

  private getImageWidth(): number | string {
    if (this.viewportWidth <= 0) {
      return '100%'
    }
    return this.viewportWidth * this.scaleValue
  }

  build() {
    Column() {
      if (!this.url || this.url.trim().length === 0) {
        Column({ space: ThemeConstants.SPACE_SM }) {
          Text('图片地址为空')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(Color.White)
          Text('返回后重试')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor('#B3B3B3')
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .layoutWeight(1)
      } else {
        Scroll() {
          Scroll() {
            Image(this.url.trim())
              .width(this.getImageWidth())
              .objectFit(ImageFit.Contain)
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.viewportWidth = (newValue?.width as number) || 0
    })
    .parallelGesture(
      PinchGesture({ fingers: 2 })
        .onActionStart(() => {
          this.pinchValue = this.scaleValue
        })
        .onActionUpdate((event?: GestureEvent) => {
          if (!event) {
            return
          }
          this.scaleValue = this.clampScale(this.pinchValue * (event.scale as number))
        })
        .onActionEnd(() => {
          this.pinchValue = this.scaleValue
        })
    )
  }
}
