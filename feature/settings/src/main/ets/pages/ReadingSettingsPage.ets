import { common } from '@kit.AbilityKit'
import {
  ConciseListRow,
  GroupedListSection,
  ListDivider as SharedListDivider,
  ReadingSettings,
  SecondaryListScaffold,
  StorageKeys,
  ThemeConstants
} from 'shared'

const PREVIEW_FIXED_HEIGHT: number = 220

@Component
export struct ReadingSettingsPage {
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ThemeConstants.FONT_SIZE_BODY
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY

  build() {
    Column() {
      SecondaryListScaffold({ horizontalPadding: 0 }) {
        ListItem() {
          this.PreviewSection()
        }

        ListItem() {
          this.ControlSection()
        }
        .margin({
          left: ThemeConstants.SPACE_MD,
          right: ThemeConstants.SPACE_MD,
          top: ThemeConstants.SPACE_MD
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  PreviewSection() {
    Column() {
      Scroll() {
        Column({ space: ThemeConstants.SPACE_MD }) {
          Text('一条关于 Next2V 的主题')
            .fontSize(this.readingFontSize + 3)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.readingLineHeight + 2)
            .width('100%')

          Text('这是阅读字体设置的实时预览区域。拖动下面的滑块后，正文的字号和行距会立即同步变化，用来接近实际主题详情中的阅读感受。')
            .fontSize(this.readingFontSize)
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.readingLineHeight)
            .width('100%')

          Text('V2EX 的讨论通常包含短句、链接、引用和代码片段。预览保持在页面背景上，避免额外卡片影响对文字排版的判断。')
            .fontSize(this.readingFontSize)
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.readingLineHeight)
            .width('100%')

          Text('> 如果一种设置能让你不用停顿就读完整段内容，它大概就是合适的。')
            .fontSize(this.readingFontSize - 1)
            .fontColor($r('sys.color.font_secondary'))
            .lineHeight(this.readingLineHeight)
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
    .height(PREVIEW_FIXED_HEIGHT)
    .clip(true)
  }

  @Builder
  ControlSection() {
    GroupedListSection({ radius: ThemeConstants.RADIUS_CARD }) {
      Column() {
        Column({ space: ThemeConstants.SPACE_SM }) {
          Row() {
            Text('字号')
              .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Blank()
          }
          .width('100%')
          .height(32)

          Slider({
            value: this.readingFontSize,
            min: ReadingSettings.FONT_SIZE_MIN,
            max: ReadingSettings.FONT_SIZE_MAX,
            step: 1,
            style: SliderStyle.InSet
          })
            .width('100%')
            .selectedColor(ThemeConstants.BRAND_PRIMARY)
            .showTips(false)
            .onChange((nextValue: number, _mode: SliderChangeMode) => {
              this.updateReadingFontSize(nextValue)
            })
        }
        .width('100%')
        .padding({
          left: ThemeConstants.SPACE_LG,
          right: ThemeConstants.SPACE_LG,
          top: ThemeConstants.SPACE_MD,
          bottom: ThemeConstants.SPACE_MD
        })

        this.SettingsDivider()

        Column({ space: ThemeConstants.SPACE_SM }) {
          Row() {
            Text('行距')
              .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Blank()
          }
          .width('100%')
          .height(32)

          Slider({
            value: this.readingLineHeight,
            min: this.readingLineHeightMin(),
            max: ReadingSettings.LINE_HEIGHT_MAX,
            step: 1,
            style: SliderStyle.InSet
          })
            .width('100%')
            .selectedColor(ThemeConstants.BRAND_PRIMARY)
            .showTips(false)
            .onChange((nextValue: number, _mode: SliderChangeMode) => {
              this.updateReadingLineHeight(nextValue)
            })
        }
        .width('100%')
        .padding({
          left: ThemeConstants.SPACE_LG,
          right: ThemeConstants.SPACE_LG,
          top: ThemeConstants.SPACE_MD,
          bottom: ThemeConstants.SPACE_MD
        })

        this.SettingsDivider()

        ConciseListRow({
          title: '恢复默认',
          destructive: true,
          showChevron: false,
          action: () => {
            this.confirmResetReadingSettings()
          }
        })
      }
      .width('100%')
    }
  }

  @Builder
  SettingsDivider() {
    SharedListDivider()
  }

  private updateReadingFontSize(fontSize: number): void {
    const nextFontSize = ReadingSettings.normalizeFontSize(fontSize)
    const nextLineHeight = ReadingSettings.normalizeLineHeight(this.readingLineHeight, nextFontSize)
    this.saveReadingSettings(nextFontSize, nextLineHeight)
  }

  private updateReadingLineHeight(lineHeight: number): void {
    this.saveReadingSettings(this.readingFontSize,
      ReadingSettings.normalizeLineHeight(lineHeight, this.readingFontSize))
  }

  private saveReadingSettings(fontSize: number, lineHeight: number): void {
    this.readingFontSize = ReadingSettings.normalizeFontSize(fontSize)
    this.readingLineHeight = ReadingSettings.normalizeLineHeight(lineHeight, this.readingFontSize)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReadingSettings.saveTypography(context, this.readingFontSize, this.readingLineHeight)
      .catch((error: Error) => {
        console.error('save reading settings failed: ' + error.message)
      })
  }

  private confirmResetReadingSettings(): void {
    AlertDialog.show({
      title: '恢复默认阅读字体设置',
      message: '将字号和行距恢复为默认值。确定继续吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '恢复',
        fontColor: Color.Red,
        action: () => {
          this.resetReadingSettings()
        }
      }
    })
  }

  private resetReadingSettings(): void {
    const defaultFontSize = ReadingSettings.normalizeFontSize(ThemeConstants.FONT_SIZE_BODY)
    const defaultLineHeight = ReadingSettings.normalizeLineHeight(ThemeConstants.LINE_HEIGHT_BODY, defaultFontSize)
    this.saveReadingSettings(defaultFontSize, defaultLineHeight)
  }

  private readingLineHeightMin(): number {
    return Math.max(ReadingSettings.LINE_HEIGHT_MIN, ReadingSettings.normalizeFontSize(this.readingFontSize) + 4)
  }
}
