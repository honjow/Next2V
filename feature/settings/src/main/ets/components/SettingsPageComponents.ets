import {
  AppStrings,
  ConciseListRow,
  GroupedListSection,
  ListDivider as SharedListDivider,
  ReadingSettings,
  SectionHeader as SharedSectionHeader,
  ThemeConstants
} from 'shared'
import { SymbolGlyphModifier } from '@kit.ArkUI'

const READING_PREVIEW_FIXED_HEIGHT: number = 220

@ComponentV2
export struct SettingsSectionHeader {
  @Param title: ResourceStr = ''

  build() {
    SharedSectionHeader({ title: this.title })
      .margin({ top: ThemeConstants.SPACE_MD })
  }
}

@ComponentV2
export struct SettingsDivider {
  build() {
    SharedListDivider()
  }
}

@ComponentV2
export struct SettingsToggleRow {
  @Param title: ResourceStr = ''
  @Param checked: boolean = false
  @Param isEnabled: boolean = true
  @Event changeAction?: (value: boolean) => void

  build() {
    ConciseListRow({
      title: this.title,
      showChevron: false,
      hasSwitch: true,
      checked: this.checked,
      isEnabled: this.isEnabled,
      switchAction: (value: boolean) => {
        if (this.changeAction) {
          this.changeAction(value)
        }
      }
    })
  }
}

@ComponentV2
export struct SettingsDropdownRow {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr = ''
  @Param trailingText: ResourceStr = ''
  @Event openAction?: () => void

  build() {
    ConciseListRow({
      title: this.title,
      subtitle: this.subtitle,
      trailingText: this.trailingText,
      showChevron: false,
      trailingDropdown: true,
      action: () => {
        if (this.openAction) {
          this.openAction()
        }
      }
    })
  }
}

@ComponentV2
export struct SettingsThemeColorDropdownRow {
  @Param title: ResourceStr = ''
  @Param trailingText: ResourceStr = ''
  @Param color: ResourceColor = ThemeConstants.BRAND_PRIMARY
  @Event openAction?: () => void

  build() {
    ConciseListRow({
      title: this.title,
      showChevron: false,
      suffixBuilderParam: () => {
        this.ColorDropdownSuffix()
      },
      action: () => {
        if (this.openAction) {
          this.openAction()
        }
      }
    })
  }

  @Builder
  private ColorDropdownSuffix() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Blank()
        .width(16)
        .height(16)
        .borderRadius(ThemeConstants.RADIUS_ROUND)
        .backgroundColor(this.color)
      Text(this.trailingText)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor([$r('sys.color.font_tertiary')])
        .padding({ left: 4, right: 12 })
    }
    .alignItems(VerticalAlign.Center)
  }
}

@ComponentV2
export struct SettingsCheckedMenuItem {
  @Param label: ResourceStr = ''
  @Param selected: boolean = false
  @Param showColorDot: boolean = false
  @Param color: ResourceColor = Color.Transparent
  @Event selectAction?: () => void

  build() {
    MenuItem({
      content: this.label,
      symbolStartIcon: this.showColorDot
        ? new SymbolGlyphModifier($r('sys.symbol.paintpalette_fill'))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor([this.color])
        : undefined,
      symbolEndIcon: this.selected ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
    }).onClick(() => {
      if (this.selectAction) {
        this.selectAction()
      }
    })
  }
}

@ComponentV2
export struct ReadingPreviewPanel {
  @Param textScale: number = ReadingSettings.TEXT_SCALE_DEFAULT

  build() {
    Column() {
      Scroll() {
        Column({ space: ThemeConstants.SPACE_MD }) {
          Text(AppStrings.R_READING_PREVIEW_TITLE)
            .fontSize(this.scaledToken(18))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.scaledToken(24))
            .width('100%')

          Text(AppStrings.R_READING_PREVIEW_INTRO)
            .fontSize(this.bodyFontSize())
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.bodyLineHeight())
            .width('100%')

          Text(AppStrings.R_READING_PREVIEW_BODY)
            .fontSize(this.bodyFontSize())
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.bodyLineHeight())
            .width('100%')

          Text(AppStrings.R_READING_PREVIEW_QUOTE)
            .fontSize(this.scaledToken(13))
            .fontColor($r('sys.color.font_secondary'))
            .lineHeight(this.bodyLineHeight())
            .width('100%')
            .padding({
              left: ThemeConstants.SPACE_MD,
              right: ThemeConstants.SPACE_MD,
              top: ThemeConstants.SPACE_SM,
              bottom: ThemeConstants.SPACE_SM
            })
            .borderRadius(ThemeConstants.RADIUS_MD)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: ThemeConstants.SPACE_LG,
          right: ThemeConstants.SPACE_LG,
          top: ThemeConstants.SPACE_MD,
          bottom: ThemeConstants.SPACE_MD
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height(READING_PREVIEW_FIXED_HEIGHT)
    .clip(true)
  }

  private scaledToken(baseValue: number): number {
    return ReadingSettings.scaleTypographyToken(baseValue, this.textScale)
  }

  private bodyFontSize(): number {
    return this.scaledToken(ThemeConstants.FONT_SIZE_BODY)
  }

  private bodyLineHeight(): number {
    return this.scaledToken(ThemeConstants.LINE_HEIGHT_BODY)
  }
}

@ComponentV2
export struct ReadingScaleControlSection {
  @Param textScale: number = ReadingSettings.TEXT_SCALE_DEFAULT
  @Event changeAction?: (value: number) => void
  @Event resetAction?: () => void

  build() {
    GroupedListSection({ radius: ThemeConstants.RADIUS_CARD }) {
      Column() {
        Column({ space: ThemeConstants.SPACE_SM }) {
          Row() {
            Text(AppStrings.R_TEXT_SCALE)
              .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Blank()
          }
          .width('100%')
          .height(32)

          Slider({
            value: this.textScale,
            min: ReadingSettings.TEXT_SCALE_MIN,
            max: ReadingSettings.TEXT_SCALE_MAX,
            step: 0.01,
            style: SliderStyle.InSet
          })
            .width('100%')
            .selectedColor(ThemeConstants.BRAND_PRIMARY)
            .showTips(false)
            .onChange((nextValue: number, _mode: SliderChangeMode) => {
              if (this.changeAction) {
                this.changeAction(nextValue)
              }
            })
        }
        .width('100%')
        .padding({
          left: ThemeConstants.SPACE_LG,
          right: ThemeConstants.SPACE_LG,
          top: ThemeConstants.SPACE_MD,
          bottom: ThemeConstants.SPACE_MD
        })

        ConciseListRow({
          title: AppStrings.R_RESTORE_DEFAULT,
          destructive: true,
          showChevron: false,
          action: () => {
            if (this.resetAction) {
              this.resetAction()
            }
          }
        })
      }
      .width('100%')
    }
  }
}

@ComponentV2
export struct HomeNodeVisibilityButton {
  @Param label: ResourceStr = ''
  @Param isEnabled: boolean = true
  @Event clickAction?: () => void

  build() {
    Button(this.label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .height(ThemeConstants.TOUCH_TARGET_SM)
      .enabled(this.isEnabled)
      .type(ButtonType.Capsule)
      .borderRadius(ThemeConstants.RADIUS_MD)
      .fontColor(this.isEnabled ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_tertiary'))
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      .onClick(() => {
        if (this.clickAction) {
          this.clickAction()
        }
      })
  }
}
