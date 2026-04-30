import { vibrator } from '@kit.SensorServiceKit'

@Component
export struct PullRefresh {
  @BuilderParam content: () => void
  scroller: Scroller = new Scroller()
  onRefresh: () => Promise<void> = async () => {}
  onScrollEnableChange: (enabled: boolean) => void = (_) => {}
  @Prop indicatorTop: number = 0
  @Prop threshold: number = 80

  @State pullOffset: number = 0
  @State refreshState: number = 0 // 0:idle 1:canRls 2:refreshing 3:done
  private hapticFired: boolean = false
  private touchStartY: number = 0
  private touchStartPullOffset: number = 0
  private isTracking: boolean = false

  private isListAtTop(): boolean {
    return this.scroller.currentOffset().yOffset <= 0
  }

  private bounceBack(target: number = 0): void {
    this.onScrollEnableChange(true)
    animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
      this.pullOffset = target
    })
    if (target === 0) {
      setTimeout(() => {
        this.refreshState = 0
        this.hapticFired = false
      }, 420)
    }
  }

  private onPullEnd(): void {
    if (this.pullOffset >= this.threshold && this.refreshState !== 2) {
      this.onScrollEnableChange(true)
      animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.pullOffset = 56
      })
      this.refreshState = 2
      this.doRefresh()
    } else if (this.pullOffset > 0) {
      this.bounceBack(0)
    }
  }

  private async doRefresh(): Promise<void> {
    await this.onRefresh()
    this.refreshState = 3
    setTimeout(() => this.bounceBack(0), 200)
  }

  private triggerHaptic(): void {
    if (this.hapticFired) return
    this.hapticFired = true
    try {
      if (vibrator.isHdHapticSupported()) {
        vibrator.startVibration({
          type: 'preset',
          effectId: 'haptic.effect.soft',
          count: 1,
          intensity: 60,
        }, { usage: 'physicalFeedback' })
      } else {
        vibrator.startVibration({
          type: 'time',
          duration: 30,
        }, { usage: 'physicalFeedback' })
      }
    } catch (e) {
      // ignore
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        this.content()
      }
      .offset({ y: this.pullOffset })
      .onTouch((event: TouchEvent) => {
        if (this.refreshState >= 2) return

        if (event.type === TouchType.Down) {
          this.touchStartY = event.touches[0].y
          this.touchStartPullOffset = this.pullOffset
          return
        }

        if (event.type === TouchType.Move) {
          let deltaY = event.touches[0].y - this.touchStartY
          if (!this.isTracking) {
            // Only start tracking when actually pulling down at the top
            if ( deltaY > 4 && this.isListAtTop()) {
              this.isTracking = true
              this.onScrollEnableChange(false)
            } else {
              return
            }
          }
          this.pullOffset = Math.max(0, this.touchStartPullOffset + deltaY * 0.8)
          if (this.pullOffset >= this.threshold) {
            this.refreshState = 1
            this.triggerHaptic()
          } else {
            this.refreshState = 0
          }
        }

        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          if (this.isTracking) {
            this.isTracking = false
            if (this.pullOffset > 0) {
              this.onPullEnd()
            } else {
              this.onScrollEnableChange(true)
            }
          }
        }
      })

      Column() {
        Row() {
          LoadingProgress()
            .width(28).height(28)
        }
        .width('100%').height(56).justifyContent(FlexAlign.Center)
        .opacity(this.pullOffset >= this.threshold * 0.5 ?
          Math.min((this.pullOffset - this.threshold * 0.5) / (this.threshold * 0.5), 1) : 0)
      }
      .position({ y: this.indicatorTop + this.pullOffset / 2 })
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%').height('100%')
    .clip(false)
  }
}
