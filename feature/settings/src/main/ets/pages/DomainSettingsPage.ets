import { AppPrompt } from 'shared'
import { common } from '@kit.AbilityKit'
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
  @Local private customBaseUrls: string[] = []

  aboutToAppear(): void {
    this.loadCustomDomains()
  }

  build() {
    Column() {
      SecondaryListScaffold({ includeKeyboardPadding: true }) {
        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.api_domain') })
        }
        ListItem() {
          this.PresetSection()
        }
        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.custom_domain') })
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
        Button(this.validating ? $r('app.string.domain_validating') : $r('app.string.domain_validate'))
          .type(ButtonType.Normal)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .width('100%')
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .onClick(() => { this.validateCustomDomain() })
        ForEach(this.customBaseUrls, (baseUrl: string) => {
          this.CustomDomainRow(baseUrl)
        }, (baseUrl: string) => baseUrl)
      }
      .width('100%')
    }
  }

  @Builder
  CustomDomainRow(baseUrl: string) {
    ConciseListRow({
      title: baseUrl,
      subtitle: $r('app.string.domain_session_hint'),
      showChevron: false,
      prefixBuilderParam: (): void => this.DomainRadio(baseUrl),
      action: () => { this.selectBaseUrl(baseUrl) },
    })
  }

  private validateCustomDomain(): void {
    if (this.validating) {
      return
    }
    this.validating = true
    this.validationMessage = AppStrings.text($r('app.string.domain_validating'), 'Validating…')
    DomainSettingsCoordinator.validateCustomDomain(this.customText)
      .then((result: DomainValidationResult) => {
        this.validating = false
        this.validationMessage = result.message
        if (!result.ok) {
          return Promise.resolve<void>(undefined)
        }
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext
        return ApiDomainSettings.saveCustomBaseUrl(context, result.baseUrl)
          .then((urls: string[]) => {
            this.customBaseUrls = urls
          })
      })
      .catch((error: Error) => {
        this.validating = false
        this.validationMessage = error.message || AppStrings.text($r('app.string.domain_validate_failed'), 'Validation failed')
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
        AppPrompt.openToast({ message: AppStrings.text($r('app.string.domain_switched'), 'V2EX site switched') }).catch((_error: Error) => {})
      })
      .catch((error: Error) => {
        console.error('save V2EX site failed: ' + error.message)
        AppPrompt.openToast({ message: AppStrings.text($r('app.string.common_save_failed'), 'Save failed') }).catch((_toastError: Error) => {})
      })
  }

  private loadCustomDomains(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ApiDomainSettings.loadCustomBaseUrls(context)
      .then((urls: string[]) => {
        this.customBaseUrls = urls
      })
      .catch((error: Error) => {
        console.error('load custom V2EX sites failed: ' + error.message)
      })
  }
}
