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

@Component
export struct SettingsSectionHeader {
  @Prop title: string = ''

  build() {
    SharedSectionHeader({ title: this.title })
      .margin({ top: ThemeConstants.SPACE_MD })
  }
}

@Component
export struct SettingsDivider {
  build() {
    SharedListDivider()
  }
}

@Component
export struct SettingsToggleRow {
  @Prop title: string = ''
  @Prop checked: boolean = false
  @Prop isEnabled: boolean = true
  changeAction?: (value: boolean) => void

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

@Component
export struct SettingsDropdownRow {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop trailingText: string = ''
  openAction?: () => void

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

@Component
export struct SettingsCheckedMenuItem {
  @Prop label: string = ''
  @Prop selected: boolean = false
  selectAction?: () => void

  build() {
    MenuItem({
      content: this.label,
      symbolEndIcon: this.selected ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined
    }).onClick(() => {
      if (this.selectAction) {
        this.selectAction()
      }
    })
  }
}

@Component
export struct ReadingPreviewPanel {
  @Prop textScale: number = ReadingSettings.TEXT_SCALE_DEFAULT

  build() {
    Column() {
      Scroll() {
        Column({ space: ThemeConstants.SPACE_MD }) {
          Text(AppStrings.t(AppStrings.R_READING_PREVIEW_TITLE, 'A topic about Next2V'))
            .fontSize(this.scaledToken(18))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.scaledToken(24))
            .width('100%')

          Text(AppStrings.t(AppStrings.R_READING_PREVIEW_INTRO, 'This is the live preview area for reading text scaling. Drag the slider below to scale body text, headings, lists, quotes, and code together, approximating the reading feel in actual topic details.'))
            .fontSize(this.bodyFontSize())
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.bodyLineHeight())
            .width('100%')

          Text(AppStrings.t(AppStrings.R_READING_PREVIEW_BODY, 'V2EX discussions usually contain short sentences, links, quotes, and code snippets. The preview stays on the page background to avoid extra cards affecting typography judgment.'))
            .fontSize(this.bodyFontSize())
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.bodyLineHeight())
            .width('100%')

          Text(AppStrings.t(AppStrings.R_READING_PREVIEW_QUOTE, '> If a setting lets you finish the paragraph without pausing, it is probably the right one.'))
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

@Component
export struct ReadingScaleControlSection {
  @Prop textScale: number = ReadingSettings.TEXT_SCALE_DEFAULT
  changeAction?: (value: number) => void
  resetAction?: () => void

  build() {
    GroupedListSection({ radius: ThemeConstants.RADIUS_CARD }) {
      Column() {
        Column({ space: ThemeConstants.SPACE_SM }) {
          Row() {
            Text(AppStrings.t(AppStrings.R_TEXT_SCALE, 'Text scale'))
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
          title: AppStrings.t(AppStrings.R_RESTORE_DEFAULT, 'Restore default'),
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

@Component
export struct HomeNodeVisibilityButton {
  @Prop label: string = ''
  @Prop isEnabled: boolean = true
  clickAction?: () => void

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
