import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  ReadingSettings,
  SecondaryListScaffold,
  StorageKeys,
  ThemeConstants
} from 'shared'
import {
  ReadingPreviewPanel,
  ReadingScaleControlSection
} from '../components/SettingsPageComponents'

@Component
export struct ReadingSettingsPage {
  @StorageLink(StorageKeys.READING_TEXT_SCALE) readingTextScale: number = ReadingSettings.TEXT_SCALE_DEFAULT

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
    ReadingPreviewPanel({ textScale: this.readingTextScale })
  }

  @Builder
  ControlSection() {
    ReadingScaleControlSection({
      textScale: this.readingTextScale,
      changeAction: (value: number) => { this.updateReadingTextScale(value) },
      resetAction: () => { this.confirmResetReadingSettings() }
    })
  }

  private updateReadingTextScale(textScale: number): void {
    const nextTextScale = ReadingSettings.normalizeTextScale(textScale)
    this.saveReadingTextScale(nextTextScale)
  }

  private saveReadingTextScale(textScale: number): void {
    this.readingTextScale = ReadingSettings.normalizeTextScale(textScale)
    const lineHeight = ReadingSettings.scaleTypographyToken(ThemeConstants.LINE_HEIGHT_BODY, this.readingTextScale)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ReadingSettings.saveTypography(context, this.readingTextScale, lineHeight)
      .catch((error: Error) => {
        console.error('save reading settings failed: ' + error.message)
      })
  }

  private confirmResetReadingSettings(): void {
    this.getUIContext().showAlertDialog({
      title: AppStrings.t(AppStrings.R_RESTORE_READING_SCALE_TITLE, 'Restore default reading text scale'),
      message: AppStrings.t(AppStrings.R_RESTORE_READING_SCALE_MESSAGE, 'Restore text scale to the default value. Continue?'),
      primaryButton: {
        value: AppStrings.t(AppStrings.R_COMMON_CANCEL, 'Cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: AppStrings.t(AppStrings.R_COMMON_RESTORE, 'Restore'),
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
