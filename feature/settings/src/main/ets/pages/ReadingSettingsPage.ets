import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  connectReadingSettings,
  ReadingSettings,
  ReadingSettingsState,
  SecondaryListScaffold,
  ThemeConstants
} from 'shared'
import {
  ReadingPreviewPanel,
  ReadingScaleControlSection
} from '../components/SettingsPageComponents'

@ComponentV2
export struct ReadingSettingsPage {
  // Reading text scale mirrored into AppStorageV2 by ReadingSettings.apply()
  // (was @StorageLink(StorageKeys.READING_TEXT_SCALE)); writes go through saveTypography().
  private reading: ReadingSettingsState = connectReadingSettings()

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
    ReadingPreviewPanel({ textScale: this.reading.textScale })
  }

  @Builder
  ControlSection() {
    ReadingScaleControlSection({
      textScale: this.reading.textScale,
      changeAction: (value: number) => { this.updateReadingTextScale(value) },
      resetAction: () => { this.confirmResetReadingSettings() }
    })
  }

  private updateReadingTextScale(textScale: number): void {
    const nextTextScale = ReadingSettings.normalizeTextScale(textScale)
    this.saveReadingTextScale(nextTextScale)
  }

  private saveReadingTextScale(textScale: number): void {
    // saveTypography() -> ReadingSettings.apply() writes both AppStorage and the V2 mirror
    // synchronously, so reading this.reading.textScale re-renders the preview/control.
    const normalized = ReadingSettings.normalizeTextScale(textScale)
    const lineHeight = ReadingSettings.scaleTypographyToken(ThemeConstants.LINE_HEIGHT_BODY, normalized)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReadingSettings.saveTypography(context, normalized, lineHeight)
      .catch((error: Error) => {
        console.error('save reading settings failed: ' + error.message)
      })
  }

  private confirmResetReadingSettings(): void {
    this.getUIContext().showAlertDialog({
      title: AppStrings.text($r('app.string.restore_reading_scale_title'), 'Restore default reading text scale'),
      message: AppStrings.text($r('app.string.restore_reading_scale_message'), 'Restore text scale to the default value. Continue?'),
      primaryButton: {
        value: AppStrings.text($r('app.string.common_cancel'), 'Cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: AppStrings.text($r('app.string.common_restore'), 'Restore'),
        fontColor: Color.Red,
        action: () => {
          this.resetReadingSettings()
        }
      }
    })
  }

  private resetReadingSettings(): void {
    this.saveReadingTextScale(ReadingSettings.TEXT_SCALE_DEFAULT)
  }
}
