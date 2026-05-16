import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import {
  ConciseListRow,
  GroupedListSection,
  ReadingSettings,
  SecondaryListScaffold,
  StorageKeys,
  ThemeConstants
} from 'shared'

const PREVIEW_FIXED_HEIGHT: number = 220

@Component
export struct ReadingSettingsPage {
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ReadingSettings.TEXT_SCALE_DEFAULT
  @StorageLink(StorageKeys.READING_BASE64_DECODE_MODE) base64DecodeMode: string = ReadingSettings.BASE64_MODE_BADGE
  @State private base64ModeMenuShown: boolean = false

  private scaledToken(baseValue: number): number {
    return ReadingSettings.scaleTypographyToken(baseValue, this.readingFontSize)
  }

  private bodyFontSize(): number {
    return this.scaledToken(ThemeConstants.FONT_SIZE_BODY)
  }

  private bodyLineHeight(): number {
    return this.scaledToken(ThemeConstants.LINE_HEIGHT_BODY)
  }

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
            .fontSize(this.scaledToken(18))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.scaledToken(24))
            .width('100%')

          Text('这是阅读字体设置的实时预览区域。拖动下面的滑块后，正文、标题、列表、引用和代码会按同一比例缩放，用来接近实际主题详情中的阅读感受。')
            .fontSize(this.bodyFontSize())
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.bodyLineHeight())
            .width('100%')

          Text('V2EX 的讨论通常包含短句、链接、引用和代码片段。预览保持在页面背景上，避免额外卡片影响对文字排版的判断。')
            .fontSize(this.bodyFontSize())
            .fontColor($r('sys.color.font_primary'))
            .lineHeight(this.bodyLineHeight())
            .width('100%')

          Text('> 如果一种设置能让你不用停顿就读完整段内容，它大概就是合适的。')
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
    .height(PREVIEW_FIXED_HEIGHT)
    .clip(true)
  }

  @Builder
  ControlSection() {
    GroupedListSection({ radius: ThemeConstants.RADIUS_CARD }) {
      Column() {
        Column({ space: ThemeConstants.SPACE_SM }) {
          Row() {
            Text('文字缩放')
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
            min: ReadingSettings.TEXT_SCALE_MIN,
            max: ReadingSettings.TEXT_SCALE_MAX,
            step: 0.01,
            style: SliderStyle.InSet
          })
            .width('100%')
            .selectedColor(ThemeConstants.BRAND_PRIMARY)
            .showTips(false)
            .onChange((nextValue: number, _mode: SliderChangeMode) => {
              this.updateReadingTextScale(nextValue)
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
          title: 'Base64 解码',
          subtitle: '默认点击查看，避免直接暴露邮箱/微信等明文',
          trailingText: this.base64DecodeModeLabel(),
          trailingDropdown: true,
          action: () => {
            this.showBase64ModeMenu()
          }
        })
          .bindMenu(this.base64ModeMenuShown, this.Base64ModeMenu, {
            placement: Placement.BottomRight,
            aboutToDisappear: () => {
              this.base64ModeMenuShown = false
            },
          })

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
  Base64ModeMenu() {
    Menu() {
      this.Base64ModeMenuItem('关闭', ReadingSettings.BASE64_MODE_OFF)
      this.Base64ModeMenuItem('点击查看', ReadingSettings.BASE64_MODE_BADGE)
      this.Base64ModeMenuItem('文内显示', ReadingSettings.BASE64_MODE_INLINE)
    }
  }

  @Builder
  Base64ModeMenuItem(label: string, mode: string) {
    MenuItem({
      content: label,
      symbolEndIcon:
        this.base64DecodeMode === mode
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
    }).onClick(() => {
      this.updateBase64DecodeMode(mode)
    })
  }

  private showBase64ModeMenu(): void {
    this.base64ModeMenuShown = false
    setTimeout(() => {
      this.base64ModeMenuShown = true
    }, 20)
  }

  private base64DecodeModeLabel(): string {
    if (this.base64DecodeMode === ReadingSettings.BASE64_MODE_OFF) {
      return '关闭'
    }
    if (this.base64DecodeMode === ReadingSettings.BASE64_MODE_INLINE) {
      return '文内显示'
    }
    return '点击查看'
  }

  private updateBase64DecodeMode(mode: string): void {
    const normalized = ReadingSettings.normalizeBase64DecodeMode(mode)
    this.base64DecodeMode = normalized
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReadingSettings.saveBase64DecodeMode(context, normalized)
      .catch((error: Error) => {
        console.error('save base64 decode settings failed: ' + error.message)
      })
  }

  private updateReadingTextScale(textScale: number): void {
    const nextTextScale = ReadingSettings.normalizeTextScale(textScale)
    this.saveReadingTextScale(nextTextScale)
  }

  private saveReadingTextScale(textScale: number): void {
    this.readingFontSize = ReadingSettings.normalizeTextScale(textScale)
    const lineHeight = ReadingSettings.scaleTypographyToken(ThemeConstants.LINE_HEIGHT_BODY, this.readingFontSize)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReadingSettings.saveTypography(context, this.readingFontSize, lineHeight)
      .catch((error: Error) => {
        console.error('save reading settings failed: ' + error.message)
      })
  }

  private confirmResetReadingSettings(): void {
    AlertDialog.show({
      title: '恢复默认阅读字体设置',
      message: '将文字缩放恢复为默认值。确定继续吗？',
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
    this.saveReadingTextScale(ReadingSettings.TEXT_SCALE_DEFAULT)
    this.updateBase64DecodeMode(ReadingSettings.BASE64_MODE_BADGE)
  }
}
