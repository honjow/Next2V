import { deviceInfo } from '@kit.BasicServicesKit'
import { uiMaterial } from '@kit.ArkUI'
import { ImmersiveMaterialSettings } from '../settings/ImmersiveMaterialSettings'
import { ImmersiveMaterialSettingsState, connectImmersiveMaterialSettings } from '../state/ImmersiveMaterialSettingsState'
import { SubTabStyleSettings } from '../settings/SubTabStyleSettings'
import { SubTabStyleState, connectSubTabStyle } from '../state/SubTabStyleState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ThemeDisplayState, connectThemeDisplay } from '../state/ThemeDisplayState'

const INDICATOR_W: number = 18
const TAB_GAP: number = ThemeConstants.SPACE_XS
const BAR_PAD: number = 0
const PILL_HEIGHT: number = 30
// Underline baseline: the tab labels are TOP-aligned with a small top padding, and the 3px indicator
// sits just under them (the FeedPills position at bar height - 14), so the bar fills its height
// tightly instead of floating a centred label with empty space above/below.
const INDICATOR_Y_OFFSET: number = 14

/**
 * Shared selector sub-tab bar with a SLIDING indicator (the V2Next FeedPills /
 * IndexTitleBarComponents pattern). The host's Swiper publishes an interpolated visualIndex (a float)
 * as the user swipes; this bar positions a single underline by interpolating between the measured tab
 * CENTERS, so the bar animation tracks the finger/page transition instead of jumping after the page
 * settles. The discrete highlight (brand colour + Medium weight) follows round(visualIndex).
 *
 * Supports two styles from the shared SubTabStyleState: 'underline' (the sliding indicator bar) and
 * 'capsule' (no indicator; the selected tab sits on a brand-accent pill). Capsule treatment adapted
 * from the NextE shared SubTabBar (erosTeam/NextE#8 capsule sub-tabs, maintainer commit ebd3f4b3):
 * the selected tab fills with the brand accent, unselected tabs use the immersive material (API 26+)
 * or the system button colour (API 23), with the text colour picked from the fill's luminance.
 *
 * Every surface uses the same native horizontal List. When its content fits it remains visually static;
 * when it overflows the List scrolls naturally and recentres the selected tab. Keeping one layout path
 * makes the indicator geometry consistent across bars.
 */
@ComponentV2
export struct SubTabBar {
  @Param tabs: string[] = [];
  @Param barHeight: number = 38;
  // The text shown per tab, parallel to tabs[]. Plain strings because a shared HAR's $r resources
  // cannot merge into the app bundle; call sites pass AppStrings-resolved labels (they register the
  // locale signal for live refresh).
  @Param labels: string[] = [];
  // Interpolated active index (float) from the Swiper - the source of the indicator position + highlight.
  @Param visualIndex: number = 0;
  // Discrete selected index from the selection bus. Scrolling listens to this, not visualIndex.
  @Param selectedIndex: number = -1;
  @Event onSelect: (index: number) => void = (_i: number) => {};
  // Per-tab measured widths (onAreaChange) so the indicator tracks real tab centres, not a uniform guess.
  @Local tabWidths: number[] = [];
  @Local tabLefts: number[] = [];
  // The indicator is overlaid above the horizontal List, so it must compensate for the List's content
  // offset instead of being left behind at a tab's original viewport coordinate.
  @Local scrollOffsetX: number = 0;
  // Reading the theme signal in the color helpers makes this bar (often hosted in a CACHED
  // ComponentContent) repaint on a system dark/light flip - without it the unselected sys.color
  // tokens stay stale.
  @Local themeDisplay: ThemeDisplayState = connectThemeDisplay();
  @Local tabStyle: SubTabStyleState = connectSubTabStyle();
  @Local immersiveMaterial: ImmersiveMaterialSettingsState = connectImmersiveMaterialSettings();
  private scroller: Scroller = new Scroller();
  private containerReady: boolean = false;
  private containerGlobalLeft: number = 0;
  private pendingCenterIndex: number = -1;
  private pendingCenterSmooth: boolean = false;
  private centeredTarget: number = -1;

  aboutToAppear(): void {
    this.centerSelectedTab(false, true)
  }

  // Returns color unchanged; the point is the effectiveDark read, which registers a rebuild dependency
  // so this cached pill subtree recolors the instant the system (or manual) theme flips.
  private themeTracked(color: ResourceColor): ResourceColor {
    return this.themeDisplay.effectiveDark ? color : color
  }

  private isCapsule(): boolean {
    return SubTabStyleSettings.isCapsule(this.tabStyle.style)
  }

  private tabGap(): number {
    return this.isCapsule() ? ThemeConstants.SPACE_SM : TAB_GAP
  }

  private tabLabel(i: number): string {
    return i < this.labels.length ? this.labels[i] : ''
  }

  private tabAccentColor(): ResourceColor {
    return this.themeTracked(ThemeConstants.BRAND_PRIMARY)
  }

  // Capsule contrast adapts to the fill's luminance: light accents (e.g. grass green) wash out white
  // text. Adapted from PR #8 (91772b0e) via the NextE shared SubTabBar.
  private onFillTextColor(): ResourceColor {
    const color: ResourceColor = this.tabAccentColor()
    const hex: string = typeof color === 'string' ? this.normalizedHex(color) : ''
    if (hex.length === 0) {
      return ThemeConstants.TEXT_ON_BRAND
    }
    const r: number = Number.parseInt(hex.substring(1, 3), 16)
    const g: number = Number.parseInt(hex.substring(3, 5), 16)
    const b: number = Number.parseInt(hex.substring(5, 7), 16)
    const luminance: number = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    return luminance > 0.6 ? ThemeConstants.TEXT_ON_LIGHT_ACCENT : ThemeConstants.TEXT_ON_BRAND
  }

  private normalizedHex(color: string): string {
    let c: string = color.trim()
    if (c.length === 0) {
      return ''
    }
    if (c.startsWith('#')) {
      c = c.substring(1)
    }
    if (/^[0-9a-fA-F]{3}$/.test(c)) {
      c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2]
    }
    return /^[0-9a-fA-F]{6}$/.test(c) ? '#' + c.toUpperCase() : ''
  }

  private selectedTextColor(i: number): ResourceColor {
    return this.isCapsule() ? this.onFillTextColor() : this.tabAccentColor()
  }

  private inactiveMaterial(): uiMaterial.Material | undefined {
    // applyShadow=false mirrors NextE SubTabBar.inactiveMaterial: the sub-tab pills carry no material
    // shadow (it reads as a hard border line under the title-bar strip).
    if (deviceInfo.apiAvailable('26.0.0')) {
      return ImmersiveMaterialSettings.systemMaterial(
        this.immersiveMaterial.level, uiMaterial.ImmersiveStyle.ULTRA_THIN, false, false,
      )
    }
    return undefined
  }

  private tabFill(i: number): ResourceColor {
    if (!this.isCapsule()) {
      return Color.Transparent
    }
    if (this.visualSelectedIndex() === i) {
      return this.tabAccentColor()
    }
    return deviceInfo.apiAvailable('26.0.0')
      ? Color.Transparent : this.themeTracked($r('sys.color.ohos_id_color_button_normal'))
  }

  private visualSelectedIndex(): number {
    const n: number = this.tabs.length
    if (n <= 0) {
      return 0
    }
    return Math.max(0, Math.min(n - 1, Math.round(this.visualIndex)))
  }

  // Left edge of tab i in the List content coordinate space: bar padding + cumulative prior tab widths
  // + inter-tab gaps. The overlaid indicator converts this to viewport space with scrollOffsetX.
  private tabLeft(i: number): number {
    if (i < this.tabLefts.length && this.tabLefts[i] >= 0) {
      return this.tabLefts[i]
    }
    let left: number = this.isCapsule() ? ThemeConstants.SPACE_MD : BAR_PAD
    for (let k = 0; k < i; k++) {
      const w: number = k < this.tabWidths.length ? this.tabWidths[k] : 0
      left += w + this.tabGap()
    }
    return left
  }

  private tabCenter(i: number): number {
    const wi: number = i < this.tabWidths.length ? this.tabWidths[i] : 0
    return this.tabLeft(i) + wi / 2
  }

  // Interpolated indicator left edge: lerp between the from/to tab centres by the fractional visual index.
  private indicatorLeft(): number {
    const n: number = this.tabs.length
    if (n <= 0) {
      return 0
    }
    const vi: number = Math.max(0, Math.min(n - 1, this.visualIndex))
    const from: number = Math.floor(vi)
    const to: number = Math.min(from + 1, n - 1)
    const frac: number = vi - from
    const center: number = this.tabCenter(from) + (this.tabCenter(to) - this.tabCenter(from)) * frac
    const left: number = center - INDICATOR_W / 2
    return left - this.scrollOffsetX
  }

  private setTabWidth(i: number, w: number): void {
    const next: number[] = this.tabWidths.slice()
    while (next.length <= i) {
      next.push(0)
    }
    next[i] = w
    this.tabWidths = next
  }

  private updateTabLayout(i: number, area: Area): void {
    const width: number = area.width as number
    if (width <= 0) {
      return
    }
    this.setTabWidth(i, width)
    const scrollOffsetX: number = this.currentScrollOffsetX()
    this.setScrollOffsetX(scrollOffsetX)
    const nextLefts: number[] = this.tabLefts.slice()
    while (nextLefts.length <= i) {
      nextLefts.push(-1)
    }
    // globalPosition is viewport-relative while the List scrolls. Persist an invariant content-space
    // left edge so an item can leave the List's viewport without pulling its indicator back to where it
    // was first measured.
    nextLefts[i] = this.areaX(area.globalPosition?.x) - this.containerGlobalLeft + scrollOffsetX
    this.tabLefts = nextLefts
    if (this.pendingCenterIndex === i) {
      this.centerTab(i, this.pendingCenterSmooth)
    }
  }

  private areaX(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed: number = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }

  private currentScrollOffsetX(): number {
    const offset: number = this.scroller.currentOffset().xOffset
    return offset > 0 && !Number.isNaN(offset) ? offset : 0
  }

  private setScrollOffsetX(offset: number): void {
    const next: number = offset > 0 && !Number.isNaN(offset) ? offset : 0
    if (this.scrollOffsetX !== next) {
      this.scrollOffsetX = next
    }
  }

  // Keep the active tab visible whenever natural content overflow makes that necessary. This follows
  // the discrete selection bus, matching V2Next FeedPills; visualIndex is high-frequency indicator
  // state only.
  @Monitor('selectedIndex')
  onSelectedIndexChange(): void {
    this.centerSelectedTab(true, false)
  }

  @Monitor('tabStyle.style')
  onTabStyleChange(): void {
    // A style change alters measured geometry; reuse the native List and recenter after its new layout.
    this.tabWidths = []
    this.tabLefts = []
    this.centeredTarget = -1
    this.pendingCenterIndex = this.centerIndex()
    this.pendingCenterSmooth = false
  }

  private centerSelectedTab(smooth: boolean, force: boolean): void {
    const i: number = this.centerIndex()
    if (!force && i === this.centeredTarget && this.pendingCenterIndex !== i) {
      return
    }
    this.centeredTarget = i
    this.centerTab(i, smooth)
  }

  private centerTab(i: number, smooth: boolean): void {
    if (i < 0 || i >= this.tabs.length) {
      return
    }
    if (!this.containerReady) {
      this.pendingCenterIndex = i
      this.pendingCenterSmooth = smooth
      return
    }
    this.pendingCenterIndex = -1
    this.scroller.scrollToIndex(i, smooth, ScrollAlign.CENTER)
  }

  private centerIndex(): number {
    const n: number = this.tabs.length
    if (n <= 0) {
      return 0
    }
    const raw: number = this.selectedIndex >= 0 ? this.selectedIndex : this.visualSelectedIndex()
    return Math.max(0, Math.min(n - 1, raw))
  }

  // The single sliding indicator is overlaid above the List and tracks its horizontal content offset.
  @Builder
  indicatorBar() {
    Row()
      .width(INDICATOR_W)
      .height(3)
      .borderRadius(1.5)
      .backgroundColor(this.tabAccentColor())
      .position({ x: this.indicatorLeft(), y: this.barHeight - INDICATOR_Y_OFFSET })
      .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      List({ space: this.tabGap(), scroller: this.scroller }) {
        ForEach(
          this.tabs,
          (key: string, index: number) => {
            ListItem() {
              // systemMaterial requires API 26; preserve the existing pill on older systems.
              if (deviceInfo.apiAvailable('26.0.0')) {
                Text(this.tabLabel(index))
                  .fontSize(ThemeConstants.FONT_SIZE_BODY)
                  .fontColor(
                    this.visualSelectedIndex() === index
                      ? this.selectedTextColor(index)
                      : this.themeTracked($r('sys.color.font_secondary')),
                  )
                  .fontWeight(this.visualSelectedIndex() === index ? FontWeight.Medium : FontWeight.Regular)
                  .maxLines(1)
                  .padding({
                    left: ThemeConstants.SPACE_MD,
                    right: ThemeConstants.SPACE_MD,
                    top: this.isCapsule() ? 0 : ThemeConstants.SPACE_XS,
                  })
                  .height(this.isCapsule() ? PILL_HEIGHT : undefined)
                  .borderRadius(this.isCapsule() ? ThemeConstants.RADIUS_ROUND : 0)
                  .clip(this.isCapsule())
                  .textAlign(TextAlign.Center)
                  .systemMaterial(
                    this.isCapsule() && this.visualSelectedIndex() !== index
                      ? this.inactiveMaterial() : undefined,
                  )
                  .backgroundColor(this.tabFill(index))
                  .onClick(() => {
                    this.onSelect(index)
                  })
                  .onAreaChange((_oldValue: Area, newValue: Area) => {
                    this.updateTabLayout(index, newValue)
                  })
              } else {
                Text(this.tabLabel(index))
                  .fontSize(ThemeConstants.FONT_SIZE_BODY)
                  .fontColor(
                    this.visualSelectedIndex() === index
                      ? this.selectedTextColor(index)
                      : this.themeTracked($r('sys.color.font_secondary')),
                  )
                  .fontWeight(this.visualSelectedIndex() === index ? FontWeight.Medium : FontWeight.Regular)
                  .maxLines(1)
                  .padding({
                    left: ThemeConstants.SPACE_MD,
                    right: ThemeConstants.SPACE_MD,
                    top: this.isCapsule() ? 0 : ThemeConstants.SPACE_XS,
                  })
                  .height(this.isCapsule() ? PILL_HEIGHT : undefined)
                  .borderRadius(this.isCapsule() ? ThemeConstants.RADIUS_ROUND : 0)
                  .clip(this.isCapsule())
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.tabFill(index))
                  .onClick(() => {
                    this.onSelect(index)
                  })
                  .onAreaChange((_oldValue: Area, newValue: Area) => {
                    this.updateTabLayout(index, newValue)
                  })
              }
            }
          },
          (key: string, index: number) => 'tab_' + index + '_' + key,
        )
      }
      .listDirection(Axis.Horizontal)
      .alignListItem(this.isCapsule() ? ListItemAlign.Center : ListItemAlign.Start)
      .contentStartOffset(this.isCapsule() ? ThemeConstants.SPACE_MD : 0)
      .contentEndOffset(this.isCapsule() ? ThemeConstants.SPACE_MD : 0)
      .onDidScroll((_scrollOffset: number, _scrollState: ScrollState) => {
        this.setScrollOffsetX(this.currentScrollOffsetX())
      })
      .onScrollIndex((_start: number, _end: number) => {
        this.setScrollOffsetX(this.currentScrollOffsetX())
      })
      .scrollBar(BarState.Off)
      .padding({ left: BAR_PAD, right: BAR_PAD })
      .width('100%')
      .height(this.barHeight)
      if (!this.isCapsule()) {
        this.indicatorBar()
      }
    }
    .width('100%')
    .height(this.barHeight)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.containerGlobalLeft = this.areaX(newValue.globalPosition?.x)
      this.containerReady = true
      if (this.pendingCenterIndex >= 0) {
        this.centerTab(this.pendingCenterIndex, this.pendingCenterSmooth)
      } else {
        this.centerSelectedTab(false, true)
      }
    })
  }
}
