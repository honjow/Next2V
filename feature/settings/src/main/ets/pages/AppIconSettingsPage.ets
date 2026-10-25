import { AppPrompt } from 'shared'
import {
  AppIconSettings,
  AppIconState,
  AppStrings,
  ConciseListRow,
  connectAppIcon,
  GroupedListSection,
  SecondaryListScaffold,
  ThemeConstants,
  type AppIconOption,
} from 'shared'
import { SettingsDivider } from '../components/SettingsPageComponents'
import { SettingsSaveCoordinator } from '../model/SettingsSaveCoordinator'

/**
 * Full-screen launcher icon picker. A dropdown does not fit the 14 icon variants on device, so the
 * settings row navigates here and the user selects from a scrollable list with previews.
 */
@ComponentV2
export struct AppIconSettingsPage {
  private appIcon: AppIconState = connectAppIcon();
  private options: AppIconOption[] = AppIconSettings.options();

  aboutToAppear(): void {
    AppIconSettings.load().catch((error: Error) => {
      console.error('refresh app icon state failed: ' + error.message)
    })
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          GroupedListSection() {
            ForEach(
              this.options,
              (option: AppIconOption, index: number) => {
                this.IconOptionRow(option)
                if (index < this.options.length - 1) {
                  SettingsDivider()
                }
              },
              (option: AppIconOption) => option.value,
            )
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  IconOptionRow(option: AppIconOption) {
    ConciseListRow({
      title: option.label,
      showChevron: false,
      prefixBuilderParam: (): void => {
        this.IconPreview(option.icon)
      },
      suffixBuilderParam: (): void => {
        this.SelectedCheck(option.value)
      },
      action: () => {
        this.select(option.value)
      },
    })
  }

  @Builder
  IconPreview(icon: ResourceStr) {
    Image(icon)
      .width(36)
      .height(36)
      .objectFit(ImageFit.Contain)
      .borderRadius(9)
      .clip(true)
  }

  @Builder
  SelectedCheck(value: string) {
    if (AppIconSettings.normalizeName(this.appIcon.name) === value) {
      SymbolGlyph($r('sys.symbol.checkmark'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor([ThemeConstants.BRAND_PRIMARY])
    }
  }

  private select(value: string): void {
    const normalized = AppIconSettings.normalizeName(value)
    if (normalized === AppIconSettings.normalizeName(this.appIcon.name)) {
      return
    }
    SettingsSaveCoordinator.saveAppIcon(normalized).catch((error: Error) => {
      console.error('switch app icon failed: ' + error.message)
      AppPrompt.openToast({
          message: AppStrings.text($r('app.string.common_save_failed'), 'Save failed'),
        })
        .catch((_toastError: Error) => {})
    })
  }
}
