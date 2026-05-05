import { vibrator } from '@kit.SensorServiceKit'
import { ThemeConstants } from '../theme/ThemeConstants'

const PULL_START_DRAG_VP: number = 4
const PULL_RESISTANCE_FACTOR: number = 0.8
const OPACITY_THRESHOLD_FACTOR: number = 0.5
const HAPTIC_HD_INTENSITY: number = 60
const HAPTIC_FALLBACK_DURATION: number = 30
const DIRECTION_LOCK_VP: number = 6

@Component
export struct PullRefresh {
  @BuilderParam content: () => void
  scroller: Scroller = new Scroller()
  onRefresh: () => Promise<void> = async () => {}
  onScrollEnableChange: (enabled: boolean) => void = (_) => {}
  @Prop indicatorTop: number = 0
  @Prop threshold: number = 80

  @State pullOffset: number = 0
  @State refreshState: number = 0
  private hapticFired: boolean = false
  private touchStartX: number = 0
  private touchStartY: number = 0
  private touchStartPullOffset: number = 0
  private isTracking: boolean = false
  private isHorizontalGesture: boolean = false

  private isListAtTop(): boolean {
    return this.scroller.currentOffset().yOffset <= 0
  }

  private bounceBack(target: number = 0): void {
    this.onScrollEnableChange(true)
    this.getUIContext().animateTo({ duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut }, () => {
      this.pullOffset = target
    })
    if (target === 0) {
      setTimeout(() => {
        this.refreshState = 0
        this.hapticFired = false
      }, ThemeConstants.ANIM_STATE_RESET_MS)
    }
  }

  private onPullEnd(): void {
    if (this.pullOffset >= this.threshold && this.refreshState !== 2) {
      this.onScrollEnableChange(true)
      this.getUIContext().animateTo({ duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut }, () => {
        this.pullOffset = ThemeConstants.TITLE_BAR_HEIGHT
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
    setTimeout(() => this.bounceBack(0), ThemeConstants.ANIM_DONE_DELAY_MS)
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
          intensity: HAPTIC_HD_INTENSITY,
        }, { usage: 'physicalFeedback' })
      } else {
        vibrator.startVibration({
          type: 'time',
          duration: HAPTIC_FALLBACK_DURATION,
        }, { usage: 'physicalFeedback' })
      }
    } catch (e) {
    }
  }

  private resetTouchState(): void {
    this.isTracking = false
    this.isHorizontalGesture = false
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
          this.touchStartX = event.touches[0].x
          this.touchStartY = event.touches[0].y
          this.touchStartPullOffset = this.pullOffset
          this.resetTouchState()
          return
        }

        if (event.type === TouchType.Move) {
          let deltaX = event.touches[0].x - this.touchStartX
          let deltaY = event.touches[0].y - this.touchStartY
          if (this.isHorizontalGesture) {
            return
          }
          if (!this.isTracking) {
            if (Math.abs(deltaX) > DIRECTION_LOCK_VP && Math.abs(deltaX) > Math.abs(deltaY)) {
              this.isHorizontalGesture = true
              return
            }
            if (deltaY > PULL_START_DRAG_VP && this.isListAtTop()) {
              this.isTracking = true
              this.onScrollEnableChange(false)
            } else {
              return
            }
          }
          this.pullOffset = Math.max(0, this.touchStartPullOffset + deltaY * PULL_RESISTANCE_FACTOR)
          if (this.pullOffset >= this.threshold) {
            this.refreshState = 1
            this.triggerHaptic()
          } else {
            this.refreshState = 0
          }
        }

        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          if (this.isTracking) {
            if (this.pullOffset > 0) {
              this.onPullEnd()
            } else {
              this.onScrollEnableChange(true)
            }
          }
          this.resetTouchState()
        }
      })

      Column() {
        Row() {
          LoadingProgress()
            .width(ThemeConstants.INDICATOR_SIZE).height(ThemeConstants.INDICATOR_SIZE)
        }
        .width('100%').height(ThemeConstants.TITLE_BAR_HEIGHT).justifyContent(FlexAlign.Center)
        .opacity(this.pullOffset >= this.threshold * OPACITY_THRESHOLD_FACTOR ?
          Math.min((this.pullOffset - this.threshold * OPACITY_THRESHOLD_FACTOR) / (this.threshold * OPACITY_THRESHOLD_FACTOR), 1) : 0)
      }
      .position({ y: this.indicatorTop + this.pullOffset / 2 })
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%').height('100%')
    .clip(false)
  }
}
