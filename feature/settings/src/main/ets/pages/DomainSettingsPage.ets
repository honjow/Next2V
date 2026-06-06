import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiDomainSettings,
  ApiDomainState,
  AppStrings,
  AppTextField,
  connectApiDomain,
  ConciseListRow,
  GroupedListSection,
  SecondaryListScaffold,
  ThemeConstants,
  type ApiDomainOption,
  type DomainValidationResult,
} from 'shared'
import { SettingsSectionHeader } from '../components/SettingsPageComponents'
import { DomainSettingsCoordinator } from '../model/DomainSettingsCoordinator'

@ComponentV2
export struct DomainSettingsPage {
  // Selected base URL mirrored into AppStorageV2 by ApiDomainSettings.apply()
  // (was @StorageLink(SELECTED_BASE_URL)); hydration already normalizes it, so the former
  // aboutToAppear re-normalization is redundant and dropped.
  private domain: ApiDomainState = connectApiDomain()
  @Local private customText: string = ''
  @Local private validationMessage: string = ''
  @Local private validating: boolean = false
  @Local private validatedCustomBaseUrl: string = ''

  build() {
    Column() {
      SecondaryListScaffold({ includeKeyboardPadding: true }) {
        ListItem() {
          SettingsSectionHeader({ title: AppStrings.R_API_DOMAIN })
        }
        ListItem() {
          this.PresetSection()
        }
        ListItem() {
          SettingsSectionHeader({ title: AppStrings.R_CUSTOM_DOMAIN })
        }
        ListItem() {
          this.CustomDomainSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  PresetSection() {
    GroupedListSection() {
      ForEach(DomainSettingsCoordinator.presetOptions(), (option: ApiDomainOption) => {
        this.PresetRow(option)
      }, (option: ApiDomainOption) => option.baseUrl)
    }
  }

  @Builder
  PresetRow(option: ApiDomainOption) {
    ConciseListRow({
      title: option.label,
      subtitle: option.hint,
      showChevron: false,
      prefixBuilderParam: (): void => this.DomainRadio(option.baseUrl),
      action: () => { this.selectBaseUrl(option.baseUrl) },
    })
  }

  @Builder
  DomainRadio(baseUrl: string) {
    Radio({ value: baseUrl, group: 'v2exDomainSelection' })
      .checked(this.domain.selectedBaseUrl === baseUrl)
      .onChange((checked: boolean) => {
        if (checked) {
          this.selectBaseUrl(baseUrl)
        }
      })
  }

  @Builder
  CustomDomainSection() {
    GroupedListSection({ inset: ThemeConstants.SPACE_XL, radius: ThemeConstants.RADIUS_CARD }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        AppTextField({
          text: this.customText,
          placeholder: 'https://edge.v2ex.com',
          onTextChange: (value: string) => {
            this.customText = value
            this.validatedCustomBaseUrl = ''
            this.validationMessage = ''
          }
        })
          .width('100%')
        if (this.validationMessage) {
          Text(this.validationMessage)
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
        }
        Button(this.validating ? AppStrings.R_DOMAIN_VALIDATING : AppStrings.R_DOMAIN_VALIDATE)
          .type(ButtonType.Normal)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .width('100%')
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .onClick(() => { this.validateCustomDomain() })
        if (this.validatedCustomBaseUrl) {
          ConciseListRow({
            title: this.validatedCustomBaseUrl,
            subtitle: AppStrings.R_DOMAIN_SESSION_HINT,
            showChevron: false,
            prefixBuilderParam: (): void => this.DomainRadio(this.validatedCustomBaseUrl),
            action: () => { this.selectBaseUrl(this.validatedCustomBaseUrl) },
          })
        }
      }
      .width('100%')
    }
  }

  private validateCustomDomain(): void {
    if (this.validating) {
      return
    }
    this.validating = true
    this.validationMessage = AppStrings.text(AppStrings.R_DOMAIN_VALIDATING, 'Validating…')
    DomainSettingsCoordinator.validateCustomDomain(this.customText)
      .then((result: DomainValidationResult) => {
        this.validating = false
        this.validationMessage = result.message
        this.validatedCustomBaseUrl = result.ok ? result.baseUrl : ''
      })
      .catch((error: Error) => {
        this.validating = false
        this.validatedCustomBaseUrl = ''
        this.validationMessage = error.message || AppStrings.text(AppStrings.R_DOMAIN_VALIDATE_FAILED, 'Validation failed')
      })
  }

  private selectBaseUrl(baseUrl: string): void {
    // applySelectedBaseUrl/save -> ApiDomainSettings.apply() synchronously writes both
    // AppStorage and the V2 mirror, so the radios (this.domain.selectedBaseUrl) re-render.
    const normalized = ApiDomainSettings.normalizeBaseUrl(baseUrl)
    DomainSettingsCoordinator.applySelectedBaseUrl(normalized)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ApiDomainSettings.save(context, normalized)
      .then(() => {
        promptAction.openToast({ message: AppStrings.text(AppStrings.R_DOMAIN_SWITCHED, 'V2EX site switched') }).catch((_error: Error) => {})
      })
      .catch((error: Error) => {
        console.error('save V2EX site failed: ' + error.message)
        promptAction.openToast({ message: AppStrings.text(AppStrings.R_COMMON_SAVE_FAILED, 'Save failed') }).catch((_toastError: Error) => {})
      })
  }
}
