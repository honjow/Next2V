import { vibrator } from '@kit.SensorServiceKit'
import { ThemeConstants } from '../theme/ThemeConstants'

const PULL_START_DRAG_VP: number = 4
const PULL_RESISTANCE_FACTOR: number = 0.8
const DEFAULT_PULL_REFRESH_THRESHOLD: number = 120
const OPACITY_THRESHOLD_FACTOR: number = 0.5
const HAPTIC_HD_INTENSITY: number = 80
const HAPTIC_FALLBACK_DURATION: number = 30
const DIRECTION_LOCK_VP: number = 6
@ComponentV2
export struct PullRefresh {
  @BuilderParam content: () => void;
  @Param scroller: Scroller = new Scroller();
  @Event onRefresh: () => Promise<void> = async () => {};
  @Event onBottomRefresh: () => Promise<void> = async () => {};
  @Param canStartBottomRefresh: () => boolean = () => false;
  @Event onScrollEnableChange: (enabled: boolean) => void = (_) => {};
  @Param indicatorTop: number = 0;
  @Param threshold: number = DEFAULT_PULL_REFRESH_THRESHOLD;
  @Param bottomIndicatorBottom: number = ThemeConstants.SPACE_XL;

  @Local pullOffset: number = 0;
  @Local bottomPullOffset: number = 0;
  @Local refreshState: number = 0;
  @Local bottomRefreshState: number = 0;
  @Local containerHeight: number = 0;
  private hapticFired: boolean = false;
  private touchStartX: number = 0;
  private touchStartY: number = 0;
  private touchStartPullOffset: number = 0;
  private touchStartBottomPullOffset: number = 0;
  private topEdgeDragStartY: number = 0;
  private bottomEdgeDragStartY: number = 0;
  private isTracking: boolean = false;
  private isBottomTracking: boolean = false;
  private isHorizontalGesture: boolean = false;

  private isListAtTop(): boolean {
    return this.scroller.currentOffset().yOffset <= 0
  }

  // Pixel-true bottom check for MANUAL pull-up (force refresh) gesture only.
  // Auto pagination uses List.onReachEnd/onScrollIndex which fire when the
  // last item enters the viewport — that signal is intentionally looser and
  // must NOT gate the manual pull-up indicator, otherwise the user sees the
  // bottom indicator flash while the list is still mid-scroll.
  private isListAtBottom(): boolean {
    try {
      return this.scroller.isAtEnd()
    } catch (_e) {
      return false
    }
  }

  private bounceBack(target: number = 0): void {
    this.onScrollEnableChange(true)
    this.getUIContext().animateTo(
      { duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut },
      () => {
        this.pullOffset = target
      },
    )
    if (target === 0) {
      setTimeout(() => {
        this.refreshState = 0
        this.hapticFired = false
      }, ThemeConstants.ANIM_STATE_RESET_MS)
    }
  }

  private bounceBottomBack(target: number = 0): void {
    this.onScrollEnableChange(true)
    this.getUIContext().animateTo(
      { duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut },
      () => {
        this.bottomPullOffset = target
      },
    )
    if (target === 0) {
      setTimeout(() => {
        this.bottomRefreshState = 0
        this.hapticFired = false
      }, ThemeConstants.ANIM_STATE_RESET_MS)
    }
  }

  private onPullEnd(): void {
    if (this.pullOffset >= this.threshold && this.refreshState !== 2) {
      this.onScrollEnableChange(true)
      this.getUIContext().animateTo(
        { duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut },
        () => {
          this.pullOffset = ThemeConstants.TITLE_BAR_HEIGHT
        },
      )
      this.refreshState = 2
      this.doRefresh()
    } else if (this.pullOffset > 0) {
      this.bounceBack(0)
    }
  }

  private onBottomPullEnd(): void {
    if (this.bottomPullOffset >= this.threshold && this.bottomRefreshState !== 2) {
      this.onScrollEnableChange(true)
      this.getUIContext().animateTo(
        { duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut },
        () => {
          this.bottomPullOffset = ThemeConstants.TITLE_BAR_HEIGHT
        },
      )
      this.bottomRefreshState = 2
      this.doBottomRefresh()
    } else if (this.bottomPullOffset > 0) {
      this.bounceBottomBack(0)
    }
  }

  private async doRefresh(): Promise<void> {
    await this.onRefresh()
    this.refreshState = 3
    setTimeout(() => this.bounceBack(0), ThemeConstants.ANIM_DONE_DELAY_MS)
  }

  private async doBottomRefresh(): Promise<void> {
    await this.onBottomRefresh()
    this.bottomRefreshState = 3
    setTimeout(() => this.bounceBottomBack(0), ThemeConstants.ANIM_DONE_DELAY_MS)
  }

  private triggerHaptic(): void {
    if (this.hapticFired) return
    this.hapticFired = true
    try {
      if (vibrator.isHdHapticSupported()) {
        vibrator.startVibration(
          {
            type: 'preset',
            effectId: 'haptic.effect.soft',
            count: 1,
            intensity: HAPTIC_HD_INTENSITY,
          },
          { usage: 'physicalFeedback' },
        )
      } else {
        vibrator.startVibration(
          {
            type: 'time',
            duration: HAPTIC_FALLBACK_DURATION,
          },
          { usage: 'physicalFeedback' },
        )
      }
    } catch (e) {}
  }

  private resetTouchState(): void {
    this.isTracking = false
    this.isBottomTracking = false
    this.isHorizontalGesture = false
    this.topEdgeDragStartY = 0
    this.bottomEdgeDragStartY = 0
  }

  private areaLength(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }

  private bottomIndicatorY(): number {
    // Mirror the top refresh indicator: keep the node mounted and derive its
    // absolute position from the current pull offset so drag and rebound share
    // one coordinate formula.
    return Math.max(
      0,
      this.containerHeight -
        this.bottomIndicatorBottom -
        this.bottomPullOffset / 2 -
        ThemeConstants.TITLE_BAR_HEIGHT / 2 +
        ThemeConstants.SPACE_SM,
    )
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        this.content()
      }
      .offset({ y: this.pullOffset - this.bottomPullOffset })
      .onTouch((event: TouchEvent) => {
        if (this.refreshState >= 2 || this.bottomRefreshState >= 2) return

        if (event.type === TouchType.Down) {
          this.touchStartX = event.touches[0].x
          this.touchStartY = event.touches[0].y
          this.touchStartPullOffset = this.pullOffset
          this.touchStartBottomPullOffset = this.bottomPullOffset
          this.resetTouchState()
          return
        }

        if (event.type === TouchType.Move) {
          let deltaX = event.touches[0].x - this.touchStartX
          let deltaY = event.touches[0].y - this.touchStartY
          if (this.isHorizontalGesture) {
            return
          }
          if (!this.isTracking && !this.isBottomTracking) {
            if (Math.abs(deltaX) > DIRECTION_LOCK_VP && Math.abs(deltaX) > Math.abs(deltaY)) {
              this.isHorizontalGesture = true
              return
            }
            if (deltaY > PULL_START_DRAG_VP && this.isListAtTop()) {
              this.isTracking = true
              this.topEdgeDragStartY = event.touches[0].y - PULL_START_DRAG_VP
              this.touchStartPullOffset = 0
              this.onScrollEnableChange(false)
            } else if (
              deltaY < -PULL_START_DRAG_VP &&
              this.isListAtBottom() &&
              this.canStartBottomRefresh()
            ) {
              this.isBottomTracking = true
              this.bottomEdgeDragStartY = event.touches[0].y + PULL_START_DRAG_VP
              this.touchStartBottomPullOffset = 0
              this.onScrollEnableChange(false)
            } else {
              return
            }
          }
          if (this.isTracking) {
            const topPullDelta = event.touches[0].y - this.topEdgeDragStartY
            this.pullOffset = Math.max(
              0,
              this.touchStartPullOffset + topPullDelta * PULL_RESISTANCE_FACTOR,
            )
            if (this.pullOffset >= this.threshold) {
              this.refreshState = 1
              this.triggerHaptic()
            } else {
              this.refreshState = 0
            }
          } else if (this.isBottomTracking) {
            const bottomPullDelta = this.bottomEdgeDragStartY - event.touches[0].y
            this.bottomPullOffset = Math.max(
              0,
              this.touchStartBottomPullOffset + bottomPullDelta * PULL_RESISTANCE_FACTOR,
            )
            if (this.bottomPullOffset >= this.threshold) {
              this.bottomRefreshState = 1
              this.triggerHaptic()
            } else {
              this.bottomRefreshState = 0
            }
          }
        }

        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          if (this.isTracking) {
            if (this.pullOffset > 0) {
              this.onPullEnd()
            } else {
              this.onScrollEnableChange(true)
            }
          } else if (this.isBottomTracking) {
            if (this.bottomPullOffset > 0) {
              this.onBottomPullEnd()
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
            .width(ThemeConstants.INDICATOR_SIZE)
            .height(ThemeConstants.INDICATOR_SIZE)
        }
        .width('100%')
        .height(ThemeConstants.TITLE_BAR_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .opacity(
          this.refreshState >= 2
            ? 1
            : this.pullOffset >= this.threshold * OPACITY_THRESHOLD_FACTOR
              ? Math.min(
                  (this.pullOffset - this.threshold * OPACITY_THRESHOLD_FACTOR) /
                    (this.threshold * OPACITY_THRESHOLD_FACTOR),
                  1,
                )
              : 0,
        )
      }
      .position({ y: this.indicatorTop + this.pullOffset / 2 })
      .hitTestBehavior(HitTestMode.None)

      Row({ space: ThemeConstants.SPACE_SM }) {
        LoadingProgress()
          .width(ThemeConstants.LOADING_SIZE_SMALL)
          .height(ThemeConstants.LOADING_SIZE_SMALL)
          .color($r('sys.color.font_secondary'))
      }
      .width('100%')
      .height(ThemeConstants.TITLE_BAR_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .opacity(
        this.bottomRefreshState >= 2
          ? 1
          : this.bottomPullOffset > 0
            ? Math.min(
                Math.max(this.bottomPullOffset / this.threshold, 0.2),
                1,
              )
            : 0,
      )
      .position({ y: this.bottomIndicatorY() })
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.containerHeight = this.areaLength(newValue.height)
    })
  }
}
