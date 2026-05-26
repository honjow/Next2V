import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ApiDomainSettings,
  AppTextField,
  ConciseListRow,
  GroupedListSection,
  SecondaryListScaffold,
  StorageKeys,
  ThemeConstants,
  type ApiDomainOption,
  type DomainValidationResult,
} from 'shared'
import { SettingsSectionHeader } from '../components/SettingsPageComponents'
import { DomainSettingsCoordinator } from '../model/DomainSettingsCoordinator'

@Component
export struct DomainSettingsPage {
  @StorageLink(StorageKeys.SELECTED_BASE_URL) selectedBaseUrl: string = 'https://www.v2ex.com'
  @State private customText: string = ''
  @State private validationMessage: string = ''
  @State private validating: boolean = false
  @State private validatedCustomBaseUrl: string = ''

  aboutToAppear(): void {
    this.selectedBaseUrl = ApiDomainSettings.normalizeBaseUrl(this.selectedBaseUrl)
  }

  build() {
    Column() {
      SecondaryListScaffold({ includeKeyboardPadding: true }) {
        ListItem() {
          SettingsSectionHeader({ title: 'V2EX 站点' })
        }
        ListItem() {
          this.PresetSection()
        }
        ListItem() {
          SettingsSectionHeader({ title: '自定义站点域名' })
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
      .checked(this.selectedBaseUrl === baseUrl)
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
          text: $customText,
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
        Button(this.validating ? '验证中…' : 'Validate')
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
            subtitle: 'V2EX 官方镜像共享登录状态；自定义域名使用独立会话。',
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
    this.validationMessage = '验证中…'
    DomainSettingsCoordinator.validateCustomDomain(this.customText)
      .then((result: DomainValidationResult) => {
        this.validating = false
        this.validationMessage = result.message
        this.validatedCustomBaseUrl = result.ok ? result.baseUrl : ''
      })
      .catch((error: Error) => {
        this.validating = false
        this.validatedCustomBaseUrl = ''
        this.validationMessage = error.message || '验证失败'
      })
  }

  private selectBaseUrl(baseUrl: string): void {
    const normalized = ApiDomainSettings.normalizeBaseUrl(baseUrl)
    this.selectedBaseUrl = normalized
    DomainSettingsCoordinator.applySelectedBaseUrl(normalized)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ApiDomainSettings.save(context, normalized)
      .then(() => {
        promptAction.openToast({ message: 'V2EX 站点已切换' }).catch((_error: Error) => {})
      })
      .catch((error: Error) => {
        console.error('save V2EX site failed: ' + error.message)
        promptAction.openToast({ message: '保存失败' }).catch((_toastError: Error) => {})
      })
  }
}
